import 'package:synchronized/synchronized.dart';

class LockedBuffer<T> {
  final _lock = Lock();
  final _list = <T>[];

  Future<void> push(T item) async {
    await _lock.synchronized(() {
      _list.add(item);
    });
  }

  Future<void> clear() async {
    await _lock.synchronized(() {
      _list.clear();
    });
  }

  Future<void> removeWhere(bool Function(T element) test) async {
    await _lock.synchronized(() {
      _list.removeWhere(test);
    });
  }

  Future<int> length() async {
    return await _lock.synchronized(() => _list.length);
  }

  Future<List<T>> snapshot() async {
    return await _lock.synchronized(() => List.of(_list));
  }
}
