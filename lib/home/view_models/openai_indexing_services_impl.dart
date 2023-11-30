import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:neon_rag_with_openai/home/model/metadata_model.dart';
import 'package:postgres/postgres.dart';
import 'package:tiktoken/tiktoken.dart';

import 'openai_indexing_services.dart';

class OpenAIIndexingServicesImpl extends OpenAIIndexingServices {
  late final http.Client client;
  late final Connection connection;

  OpenAIIndexingServicesImpl({
    required this.client,
    required this.connection,
  });

  Future<int> getTokenLength(String content,
      {String encodingName = "cl100k_base"}) async {
    if (content.isEmpty) {
      return 0;
    }

    final encoding = getEncoding(encodingName);
    final numTokens = encoding.encode(content).length;
    return numTokens;
  }

  Future<String> getCompletionFromMessages(messages,
      {model = "gpt-3.5-turbo-1106", temperature = 0, maxtokens = 1000}) async {
    final response = await client.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']!}',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxtokens,
      }),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      String content = responseData['choices'][0]['message']['content'];
      return content;
    } else {
      throw response.body;
    }
  }

  @override
  Future<List<List<dynamic>>> loadCSV() async {
    final rawcsvFile = await rootBundle.loadString("assets/mydata.csv");
    final csvData =
        const CsvToListConverter().convert(rawcsvFile.splitMapJoin("/n"));
    return csvData;
  }

  @override
  Future<List<List<String>>> splitToChunks(List<List<dynamic>> csvDoc) async {
    List<List<String>> chunkList = [];
    for (var i = 1; i < csvDoc.length; i++) {
      String content = csvDoc[i][1];
      int start = 0;
      int idealTokenSize = 512;
      int idealSize = (idealTokenSize ~/ (4 / 3)).toInt();
      int end = idealSize;
      List<String> words = content.split(" ");
      words = words.where((word) => word != " ").toList();
      int totalWords = words.length;
      int chunks = totalWords ~/ idealSize;

      if (totalWords % idealSize != 0) {
        chunks += 1;
      }
      List<String> newContent = [];
      for (int j = 0; j < chunks; j++) {
        if (end > totalWords) {
          end = totalWords;
        }

        newContent = words.sublist(start, end);

        String newContentString = newContent.join(" ");
        String id = csvDoc[i][0];
        chunkList.add(["${id}_$j", newContentString]);
        start += idealSize;
        end += idealSize;
      }
    }
    return chunkList;
  }

  @override
  Future<List<List<double>>> getEmbeddings(List<List<String>> chunks) async {
    debugPrint("Embedding ....");
    List<List<double>> embeddedDoc = [];
    for (var chunk in chunks) {
      final response = await client.post(
        Uri.parse("https://api.openai.com/v1/embeddings"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']!}',
        },
        body: jsonEncode({
          'model': 'text-embedding-ada-002',
          'input': chunk[0],
        }),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        List<dynamic> embedding = responseData['data'][0]['embedding'];
        List<double> embeddingdouble = embedding.map((item) {
          if (item is double) {
            return item;
          } else {
            throw const FormatException('Invalid format');
          }
        }).toList();

        embeddedDoc.add(embeddingdouble);
      } else {
        throw response.body;
      }
    }
    debugPrint("Embedding complete....");
    return embeddedDoc;
  }

  @override
  Future<bool> checkExtExist() async {
    final checkExtExist = await connection.execute(
      "SELECT EXISTS (SELECT FROM pg_extension WHERE extname = 'vector');",
    );
    return checkExtExist.first[0] as bool;
  }

  @override
  Future<bool> checkTableExist(String tableName) async {
    final checkTableExist = await connection.execute(
      "SELECT EXISTS (SELECT FROM information_schema.tables WHERE  table_schema = 'public' AND table_name = '$tableName');",
    );
    return checkTableExist.first[0] as bool;
  }

  @override
  Future<String> createNeonVecorExt() async {
    debugPrint("Creating pgVector extension ...");
    await connection.execute("CREATE EXTENSION vector;");

    return "Vector extension created Successfully";
  }

  @override
  Future<String> createNeonTable(String tableName) async {
    debugPrint("Creating the $tableName table ... ");
    await connection.execute(
      "CREATE TABLE $tableName (id text, metadata text, embedding vector(1536));",
    );

    debugPrint("Indexing the $tableName using the ivfflat vector cosine");
    await connection.execute(
        'CREATE INDEX ON $tableName USING ivfflat (embedding vector_cosine_ops) WITH (lists = 24);');

    return "Table created successfully";
  }

  @override
  Future<String> deleteNeonTableRows(String tableName) async {
    debugPrint("Deleting tableRows");
    await connection.execute("TRUNCATE $tableName;");
    return "Table rows deleted successfuly";
  }

  @override
  Future<void> storeDoument(
    List<List<String>> chunks,
    List<List<double>> embeddedVectors,
    String tableName,
  ) async {
    debugPrint("Storing data");
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final embeddingArray = embeddedVectors[i];
      await connection.runTx((s) async {
        await s.execute(
            Sql.named(
              'INSERT INTO $tableName (id, metadata, embedding) VALUES (@id, @metadata, @embedding)',
            ),
            parameters: {
              'id': chunk[0],
              'metadata': {
                'pageContent': chunk[1],
                'txtPath': chunk[0],
              },
              'embedding': '$embeddingArray',
            });
      });
    }
    debugPrint("Data stored!!!");
  }

  Future<List<double>> getQueryEmbeddings(String query) async {
    debugPrint("Embedding ....");
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/embeddings"),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']!}',
      },
      body: jsonEncode({
        'model': 'babbage-002',
        'input': query,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      List<dynamic> embedding = responseData['data'][0]['embedding'];
      List<double> embeddingdouble = embedding.map((item) {
        if (item is double) {
          return item;
        } else {
          throw const FormatException('Invalid format');
        }
      }).toList();
      debugPrint("Embedding complete....");
      return embeddingdouble;
    } else {
      throw response.body;
    }
  }

  @override
  Future<String> queryNeonTable(String tableName, String query) async {
    print("Query started ...");
    String delimiter = "```";

    final embedQuery = await getQueryEmbeddings(query);
    List<List<dynamic>> getSimilar = await connection.execute(
        "SELECT *, 1 - (embedding <=> '$embedQuery') AS cosine_similarity FROM $tableName WHERE (1 - (embedding <=> '$embedQuery')) BETWEEN 0.3 AND 1.00 ORDER BY cosine_similarity DESC LIMIT 3;");

    List<Metadata> csvMetadata = getSimilar
        .map((item) => Metadata.fromJson(
              json.decode(item[1]),
            ))
        .toList();

    if (csvMetadata.isNotEmpty) {
      final concatPageContent = csvMetadata.map((e) {
        return e.pageContent;
      }).join(' ');

      print(concatPageContent);
      String systemMessage = """
      You are a friendly chatbot. \n
      You can answer questions about 	Implementing OAuth2 Clients with Flutter and Appwrite. \n
      You respond in a concise, technically credible tone. \n
      """;

      List<Map<String, String>> messages = [
        {"role": "system", "content": systemMessage},
        {"role": "user", "content": "$delimiter$query$delimiter"},
        {
          "role": "assistant",
          "content":
              "Relevant Appwrite OAuth2 case studies \n $concatPageContent"
        }
      ];

      final finalResponse = await getCompletionFromMessages(messages);
      print("Query Recieved: $finalResponse");
      return finalResponse;
    } else {
      return "Couldn't find anything on that topic";
    }
  }
}

void debugPrint(String message) {
  if (kDebugMode) {
    print(message);
  }
}
