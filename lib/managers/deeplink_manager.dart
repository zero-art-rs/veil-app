import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:zk_notion_app/storage/models.dart';

class DocumentDeepLink {
  String documentID;

  DocumentDeepLink({required this.documentID});
}

class DeeplinkManager {
  final baseUrl = 'https://veil.distributedlab.com';
  final _actorIDKey = 'aid';
  final _nameKey = 'name';
  final _publicKeyKey = 'pk';
  final _documentIDKey = 'doc';

  static final instance = DeeplinkManager();

  ExternalAccount? retrieveContactDeepLink(Uri? deepLink) {
    if (deepLink == null) return null;

    final deepLinkString = deepLink.toString();

    final isContactDeepLink =
        deepLinkString.contains(_actorIDKey) &&
        deepLinkString.contains(_publicKeyKey) &&
        deepLinkString.contains(_nameKey);

    if (!isContactDeepLink) return null;

    final contact = ExternalAccount(
      name: deepLink.pathSegments[5],
      rawPublicKey: HEX.decode(deepLink.pathSegments[3]),
      actorId: deepLink.pathSegments[1],
    );

    return contact;
  }

  DocumentDeepLink? retrieveDocumentDeepLink(Uri? deepLink) {
    if (deepLink == null) return null;

    final deepLinkString = deepLink.toString();

    final isDocumentDeepLink = deepLinkString.contains(_documentIDKey);
    if (!isDocumentDeepLink) return null;

    return DocumentDeepLink(documentID: deepLink.pathSegments[1]);
  }

  (DocumentDeepLink?, ExternalAccount?) retrieveDeepLink(Uri? deepLink) {
    return (
      retrieveDocumentDeepLink(deepLink),
      retrieveContactDeepLink(deepLink),
    );
  }

  String buildContactDeepLink(ExternalAccount contact) {
    return '$baseUrl/aid/${contact.actorId}/pk/${contact.rawPublicKey}/name/${contact.name}';
  }

  String buildUnidentifiedGroupInvite(Uint8List invite) {
    final base64Inivte = base64Encode(invite);
    return '$baseUrl/unidentified-invite/$base64Inivte';
  }
}
