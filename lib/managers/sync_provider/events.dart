import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/src/rust/api/automerge.dart';

abstract class SyncModelEvent {}

class SyncModelCrdtEvent extends SyncModelEvent {
  final BAutoCommit crdt;

  SyncModelCrdtEvent(this.crdt);
}

class SyncModelSyncingEvent extends SyncModelEvent {
  final bool processing;

  SyncModelSyncingEvent(this.processing);
}

class SyncModelGroupInfoEvent extends SyncModelEvent {
  final GroupInfo groupInfo;

  SyncModelGroupInfoEvent(this.groupInfo);
}

class SyncModelRemovedFromGroupEvent extends SyncModelEvent {}

class SyncModelCorruptedEvent extends SyncModelEvent {}
