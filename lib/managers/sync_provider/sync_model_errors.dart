bool isUserRemovedError(Object e) {
  return e.toString().contains('User removed from group');
}

bool isChangesAlreadyAppliedOrMerged(Object e) {
  return e.toString().contains('Changes already applied or merged');
}
