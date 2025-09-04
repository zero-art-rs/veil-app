import 'dart:io';
import 'package:http/http.dart' as http;

class CreateDocumentRequest {
  String id;
  String art;
  bool isPrivate;

  CreateDocumentRequest({
    required this.id,
    required this.art,
    required this.isPrivate,
  });

  factory CreateDocumentRequest.withId(String id) {
    return CreateDocumentRequest(id: id, art: '0', isPrivate: false);
  }

  String url(String baseUrl) {
    return '$baseUrl/v1/group/$id';
  }

  Map<String, dynamic> body() {
    return {'id': id, 'art': art, 'isPrivate': isPrivate};
  }
}

class DeleteGroupRequest {
  String id;
  String nonce;
  String signature;

  DeleteGroupRequest({
    required this.id,
    required this.nonce,
    required this.signature,
  });

  factory DeleteGroupRequest.withId(String id) {
    return DeleteGroupRequest(id: id, nonce: '0', signature: '0');
  }

  http.Request request(String baseUrl) {
    final req = http.Request('GET', Uri.parse(url(baseUrl)));
    return req;
  }

  String url(String baseUrl) {
    return '$baseUrl/v1/group/$id';
  }
}
