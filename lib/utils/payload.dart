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

  ExposedCRDTPayload? exposeCrdtPayload(Payload payload) {
    switch (payload.whichContent()) {
      case Payload_Content.crdt:
        return _handleCRDT(payload.crdt);
      default:
        return null;
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
