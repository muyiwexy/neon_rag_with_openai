import 'package:flutter/material.dart';
import 'package:neon_rag_with_openai/core/config/service_config.dart';
import 'package:neon_rag_with_openai/home/view_models/openai_indexing_services.dart';

class Message {
  String? query;
  String? response;
  Message({required this.query, this.response = ""});
}

enum QueryState {
  initial,
  loading,
  loaded,
  error,
}

class QueryNotifier {
  late final OpenAIIndexingServices openAIIndexingServices;
  QueryNotifier({required this.openAIIndexingServices});

  final List<Message> _messages = [];
  final _messagesState = ValueNotifier<List<Message>>([]);
  ValueNotifier<List<Message>> get messageState => _messagesState;

  final _queryState = ValueNotifier<QueryState>(QueryState.initial);
  ValueNotifier<QueryState> get queryState => _queryState;

  queryIngeonTable(String query) async {
    try {
      _messages.add(Message(query: query, response: ""));
      _messagesState.value = List.from(_messages);
      _queryState.value = QueryState.loading;
      String response = await openAIIndexingServices.queryNeonTable(
          ServiceConfigurations.openAITable, query);

      final List<Message> updatedMessages = List.from(_messages);
      updatedMessages.last.response = response;
      _messagesState.value = updatedMessages;
    } catch (e) {
      // Handle errors if necessary
      print(e);
      _queryState.value = QueryState.error;
      await Future.delayed(const Duration(milliseconds: 2000));
      _queryState.value = QueryState.initial;
    }
  }
}
