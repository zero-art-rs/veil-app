import 'package:veil/protos/zero_art.pbserver.dart';

enum ExposedCRDTPayloadKind { incrementalChange, fullDocument }

class ExposedCRDTPayload {
  CRDTPayload crdt;
  ExposedCRDTPayloadKind kind;

  ExposedCRDTPayload({required this.crdt, required this.kind});
}

class PayloadUtils {
  static final instance = PayloadUtils();

  (ExposedCRDTPayload?, GroupActionPayload?) exposePayload(Payload payload) {
    switch (payload.whichContent()) {
      case Payload_Content.crdt:
        return (_handleCRDT(payload.crdt), null);
      case Payload_Content.action:
        return (null, _handleGroupOperations(payload.action));
      default:
        throw UnimplementedError('Received unknown payload type');
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

  GroupActionPayload _handleGroupOperations(GroupActionPayload gop) {
    switch (gop.whichAction()) {
      case GroupActionPayload_Action.init:
        return gop;
      case GroupActionPayload_Action.inviteMember:
        return gop;
      case GroupActionPayload_Action.removeMember:
        throw UnimplementedError('Remove member not supported');
      case GroupActionPayload_Action.joinGroup:
        return gop;
      case GroupActionPayload_Action.changeUser:
        throw UnimplementedError('Change user not supported');
      case GroupActionPayload_Action.changeGroup:
        throw UnimplementedError('Change group not supported');
      case GroupActionPayload_Action.leaveGroup:
        throw UnimplementedError('Leave group not supported');
      case GroupActionPayload_Action.finalizeRemoval:
        throw UnimplementedError('Finalize removal not supported');
      case GroupActionPayload_Action.notSet:
        throw UnimplementedError('group operation not set');
    }
  }
}
