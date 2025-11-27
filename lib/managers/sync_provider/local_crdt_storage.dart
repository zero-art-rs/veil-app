import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:queue/queue.dart';
import 'package:uuid/v4.dart';
import 'package:veil/storage/sqlite/models/crdt_change.dart';

abstract class LocalCrdtStorage {
  Future<void> insertLocalCrdtChange({
    required String documentId,
    required Uint8List data,
  });

  Future<void> deleteLocalCrdtChanges({
    required String documentId,
    required List<String> ids,
  });

  Future<List<CrdtChange>> getLocalCrdtChanges({required String documentId});
}

class InMemoryLocalCrdtStorage implements LocalCrdtStorage {
  final Map<String, List<CrdtChange>> _crdtChanges = {};
  final _queue = Queue();

  @override
  Future<void> insertLocalCrdtChange({
    required String documentId,
    required Uint8List data,
  }) async {
    await _queue.add(() async {
      _crdtChanges
          .putIfAbsent(documentId, () => [])
          .add(
            CrdtChange(
              id: UuidV4().generate(),
              documentId: documentId,
              content: data,
              createdAt: DateTime.now(),
            ),
          );
    });
  }

  @override
  Future<void> deleteLocalCrdtChanges({
    required String documentId,
    required List<String> ids,
  }) async {
    await _queue.add(() async {
      _crdtChanges[documentId] = _crdtChanges[documentId]!
          .where((e) => !ids.contains(e.id))
          .toList();
    });
  }

  @override
  Future<List<CrdtChange>> getLocalCrdtChanges({
    required String documentId,
  }) async {
    return await _queue.add(() async {
      return _crdtChanges[documentId]?.sorted(
            (a, b) => a.createdAt.compareTo(b.createdAt),
          ) ??
          [];
    });
  }
}
