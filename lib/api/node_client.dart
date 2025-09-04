class NodeClient {
  final String url;

  NodeClient({required this.url});

  Future<void> createDocument({required String id}) async {}

  Future<void> deleteDocument({required String id}) async {}

  Future<void> getBlocks({
    required String id,
    required int page,
    required int limit,
  }) async {}

  Future<void> sendBlock({required String id, required String block}) async {}
}
