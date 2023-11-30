import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:neon_rag_with_openai/home/controller/index_notifier.dart';
import 'package:neon_rag_with_openai/home/controller/query_notifier.dart';
import 'package:neon_rag_with_openai/home/view_models/openai_indexing_services.dart';
import 'package:neon_rag_with_openai/home/view_models/openai_indexing_services_impl.dart';
import 'package:postgres/postgres.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class ProviderLocator {
  // provider tree
  static Future<MultiProvider> getProvider(Widget child) async {
    final openAIIndexingService = await _createOpenAIIndexingServices();

    return MultiProvider(
      providers: [
        Provider<OpenAIIndexingServices>.value(value: openAIIndexingService),
        Provider(
          create: (_) => IndexNotifier(
            openAIIndexingServices: openAIIndexingService,
          ),
        ),
        Provider(
            create: (_) =>
                QueryNotifier(openAIIndexingServices: openAIIndexingService))
      ],
      child: child,
    );
  }

  static Future<OpenAIIndexingServices> _createOpenAIIndexingServices() async {
    final connection = await createPostgresConnection();
    final client = await _createHtttpClient();
    return OpenAIIndexingServicesImpl(connection: connection, client: client);
  }

  // postgres connection
  static Future<Connection> createPostgresConnection() async {
    const maxRetries = 3;
    for (var retry = 0; retry < maxRetries; retry++) {
      try {
        final endpoint = Endpoint(
          host: dotenv.env['PGHOST']!,
          database: dotenv.env['PGDATABASE']!,
          port: 5432,
          username: dotenv.env['PGUSER']!,
          password: dotenv.env['PGPASSWORD']!,
        );

        final connection = await Connection.open(
          endpoint,
          settings: ConnectionSettings(
            sslMode: SslMode.verifyFull,
            connectTimeout: const Duration(milliseconds: 20000),
          ),
        );

        if (connection.isOpen) {
          if (kDebugMode) {
            print("Connection Established!");
          }
          return connection;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error creating PostgreSQL connection: $e');
        }
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    // If maxRetries is reached and the connection is still not open, throw an exception
    throw Exception(
        'Failed to establish a PostgreSQL connection after $maxRetries retries');
  }

  static Future<http.Client> _createHtttpClient() async {
    try {
      return http.Client();
    } catch (e) {
      rethrow;
    }
  }
}
