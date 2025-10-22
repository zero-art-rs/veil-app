import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:veil/protos/zero_art.pbserver.dart';

enum ExposedCRDTPayloadKind { incrementalChange, fullDocument }

class ExposedCRDTPayload {
  CRDTPayload crdt;
  ExposedCRDTPayloadKind kind;

  ExposedCRDTPayload({required this.crdt, required this.kind});
}

class FrameUtils {
  static final instance = FrameUtils._();

  FrameUtils._();

  (ExposedCRDTPayload?, TextMessage?) exposePayload(Payload payload) {
    switch (payload.whichContent()) {
      case Payload_Content.crdt:
        return (_handleCRDT(payload.crdt), null);
      case Payload_Content.chat:
        return (null, _handleChatPayload(payload.chat));
      default:
        return (null, null);
    }
  }

  TextMessage _handleChatPayload(ChatPayload payload) {
    switch (payload.whichPayload()) {
      case ChatPayload_Payload.text:
        return TextMessage.fromJson(jsonDecode(utf8.decode(payload.text)));
      case ChatPayload_Payload.img:
        throw UnimplementedError('Image attachments not supported');
      case ChatPayload_Payload.file:
        throw UnimplementedError('File attachments not supported');
      case ChatPayload_Payload.notSet:
        throw UnimplementedError('Chat payload not set');
    }
  }

  ExposedCRDTPayload _handleCRDT(CRDTPayload crdt) {
    switch (crdt.whichPayload()) {
      case CRDTPayload_Payload.incrementalChange:
        return ExposedCRDTPayload(
          crdt: crdt,
          kind: ExposedCRDTPayloadKind.incrementalChange,
        );
      case CRDTPayload_Payload.fullDocument:
        return ExposedCRDTPayload(
          crdt: crdt,
          kind: ExposedCRDTPayloadKind.fullDocument,
        );
      case CRDTPayload_Payload.mediaAttachment:
        throw UnimplementedError('Media attachments not supported');
      case CRDTPayload_Payload.notSet:
        throw UnimplementedError('CRDT payload not set');
    }
  }
}
