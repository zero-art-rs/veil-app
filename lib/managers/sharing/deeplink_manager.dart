import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:veil/storage/models.dart';

class DocumentDeepLink {
  String inviteData;

  DocumentDeepLink({required this.inviteData});
}

class ContactDeepLink {
  String encryptionKey;
  String blobId;

  ContactDeepLink({required this.encryptionKey, required this.blobId});
}

class DeeplinkManager {
  final baseUrl = 'https://veil.distributedlab.com';
  final blobIdKey = 'aid';
  final _encryptionKey = 'pk';
  final _unidentifiedInviteKey = 'unidentified-invite';

  static final instance = DeeplinkManager();

  ContactDeepLink? retrieveContactDeepLink(Uri? deepLink) {
    if (deepLink == null) return null;

    final deepLinkString = deepLink.toString();

    final isContactDeepLink =
        deepLinkString.contains(blobIdKey) &&
        deepLinkString.contains(_encryptionKey);

    if (!isContactDeepLink) return null;

    return ContactDeepLink(
      encryptionKey: deepLinkString[3],
      blobId: deepLinkString[1],
    );
  }

  DocumentDeepLink? retrieveDocumentDeepLink(Uri? deepLink) {
    if (deepLink == null) return null;

    final deepLinkString = deepLink.toString();

    final isDocumentDeepLink = deepLinkString.contains(_unidentifiedInviteKey);
    if (!isDocumentDeepLink) return null;

    final base64InviteData = deepLink.pathSegments[1];

    return DocumentDeepLink(inviteData: base64InviteData);
  }

  (DocumentDeepLink?, ContactDeepLink?) retrieveDeepLink(Uri? deepLink) {
    return (
      retrieveDocumentDeepLink(deepLink),
      retrieveContactDeepLink(deepLink),
    );
  }

  String buildContactDeepLink(String blobId, String encryptionKey) {
    return '$baseUrl/blob/$blobId/ekey/$encryptionKey';
  }

  String buildUnidentifiedGroupInvite(Uint8List invite) {
    final base64Inivte = base64UrlEncode(invite);
    return '$baseUrl/unidentified-invite/$base64Inivte';
  }
}
