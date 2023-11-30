abstract class OpenAIIndexingServices {
  Future<List<List<dynamic>>> loadCSV();
  Future<List<List<String>>> splitToChunks(List<List<dynamic>> csvDoc);
  Future<List<List<double>>> getEmbeddings(List<List<String>> chunks);
  Future<bool> checkExtExist();
  Future<bool> checkTableExist(String tableName);
  Future<String> createNeonVecorExt();
  Future<String> createNeonTable(String tableName);
  Future<String> deleteNeonTableRows(String tableName);
  Future<void> storeDoument(List<List<String>> chunks,
      List<List<double>> embeddedVectors, String tableName);
  Future<String> queryNeonTable(String tableName, String query);
}
