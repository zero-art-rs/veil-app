import 'dart:convert';
import 'dart:typed_data';

import 'package:veil/managers/sharing/spk_manager.dart';

class DocumentDeepLink {
  String inviteData;

  DocumentDeepLink({required this.inviteData});
}

class DeeplinkManager {
  final baseUrl = 'https://veil.distributedlab.com';
  final blobIdKey = 'bid';
  final _encryptionKeyKey = 'ekey';
  final _inviteKey = 'invite';

  static final instance = DeeplinkManager._();

  DeeplinkManager._();

  SharedSpkRevealData? retrieveContactDeepLink(Uri? deepLink) {
    if (deepLink == null) return null;

    final deepLinkString = deepLink.toString();

    final isContactDeepLink =
        deepLinkString.contains(blobIdKey) &&
        deepLinkString.contains(_encryptionKeyKey);

    if (!isContactDeepLink) return null;

    return SharedSpkRevealData(
      encryptionKey: base64Decode(deepLink.pathSegments[3]),
      blobId: deepLink.pathSegments[1],
    );
  }

  DocumentDeepLink? retrieveDocumentDeepLink(Uri? deepLink) {
    if (deepLink == null) return null;

    final deepLinkString = deepLink.toString();

    final isDocumentDeepLink = deepLinkString.contains(_inviteKey);
    if (!isDocumentDeepLink) return null;

    final base64InviteData = deepLink.pathSegments[1];

    return DocumentDeepLink(inviteData: base64InviteData);
  }

  (DocumentDeepLink?, SharedSpkRevealData?) retrieveDeepLink(Uri? deepLink) {
    return (
      retrieveDocumentDeepLink(deepLink),
      retrieveContactDeepLink(deepLink),
    );
  }

  String buildContactDeepLink(SharedSpkRevealData payload) {
    return '$baseUrl/$blobIdKey/${payload.blobId}/$_encryptionKeyKey/${base64UrlEncode(payload.encryptionKey)}';
  }

  String buildInvite(Uint8List invite) {
    final base64Inivte = base64UrlEncode(invite);
    return '$baseUrl/invite/$base64Inivte';
  }
}
