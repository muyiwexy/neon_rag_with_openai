import 'package:flutter/material.dart';
import 'package:neon_rag_with_openai/core/config/service_config.dart';
import 'package:neon_rag_with_openai/home/view_models/openai_indexing_services.dart';

enum IndexState { initial, loading, loaded, error }

class IndexNotifier {
  late final OpenAIIndexingServices openAIIndexingServices;
  IndexNotifier({required this.openAIIndexingServices});

  final _indexState = ValueNotifier<IndexState>(IndexState.initial);
  ValueNotifier<IndexState> get indexState => _indexState;

  indexingNeonTable() async {
    try {
      _indexState.value = IndexState.loading;
      final csvDoc = await openAIIndexingServices.loadCSV();
      final chunks = await openAIIndexingServices.splitToChunks(csvDoc);
      final embeddedDocs = await openAIIndexingServices.getEmbeddings(chunks);
      if (!(await openAIIndexingServices.checkExtExist())) {
        await openAIIndexingServices.createNeonVecorExt();
      }

      if (!(await openAIIndexingServices
          .checkTableExist(ServiceConfigurations.openAITable))) {
        await openAIIndexingServices
            .createNeonTable(ServiceConfigurations.openAITable);
      } else {
        await openAIIndexingServices
            .deleteNeonTableRows(ServiceConfigurations.openAITable);
      }

      await openAIIndexingServices.storeDoument(
        chunks,
        embeddedDocs,
        ServiceConfigurations.openAITable,
      );
      _indexState.value = IndexState.loaded;
    } catch (e) {
      _indexState.value = IndexState.error;
      rethrow;
    } finally {
      await Future.delayed(const Duration(milliseconds: 2000));
      _indexState.value = IndexState.initial;
    }
  }
}
