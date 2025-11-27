import 'package:flutter/widgets.dart';
import 'package:veil/src/rust/api/automerge.dart';
import 'package:veil/utils/group_context_factory.dart';

class DocumentState {
  String id;
  BAutoCommit crdt;
  DateTime createdAt;
  GroupContextParts groupContextParts;
  int sequenceNumber;
  bool isLocal;

  Key get key => ValueKey(id);

  DocumentState({
    required this.id,
    required this.crdt,
    required this.createdAt,
    required this.groupContextParts,
    this.sequenceNumber = 0,
    this.isLocal = false,
  });

  void setCrdt(BAutoCommit crdt) {
    this.crdt = crdt;
  }

  void incrementSequenceNumber() {
    sequenceNumber++;
  }
}
