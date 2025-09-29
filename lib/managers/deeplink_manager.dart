import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:veil/storage/models.dart';

class DocumentDeepLink {
  String inviteData;

  DocumentDeepLink({required this.inviteData});
}

class DeeplinkManager {
  final baseUrl = 'https://veil.distributedlab.com';
  final _actorIDKey = 'aid';
  final _nameKey = 'name';
  final _publicKeyKey = 'pk';
  final _unidentifiedInviteKey = 'unidentified-invite';

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

    final isDocumentDeepLink = deepLinkString.contains(_unidentifiedInviteKey);
    if (!isDocumentDeepLink) return null;

    final base64InviteData = deepLink.pathSegments[1];

    return DocumentDeepLink(inviteData: base64InviteData);
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
    final base64Inivte = base64UrlEncode(invite);
    return '$baseUrl/unidentified-invite/$base64Inivte';
  }
}
