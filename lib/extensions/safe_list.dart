extension SafeList<T> on List<T> {
  T? safeGet(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}
