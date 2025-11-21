class SyncModelSendError implements Exception {
  final String message;
  SyncModelSendError(this.message);

  @override
  String toString() => 'Send error: $message';
}

bool isUserRemovedError(Object e) {
  return e.toString().contains('User removed from group');
}

bool isChangesAlreadyAppliedOrMerged(Object e) {
  return e.toString().contains('Changes already applied or merged');
}