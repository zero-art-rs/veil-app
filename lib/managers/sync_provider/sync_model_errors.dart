class SyncModelSendError implements Exception {
  final String message;
  SyncModelSendError(this.message);

  @override
  String toString() => 'Send error: $message';
}

class SyncModelInitError implements Exception {
  final String message;
  SyncModelInitError(this.message);

  @override
  String toString() => 'Init error: $message';
}

bool isUserRemovedError(Object e) {
  return e.toString().contains('User removed from group');
}

bool isChangesAlreadyAppliedOrMerged(Object e) {
  return e.toString().contains('Changes already applied or merged');
}
