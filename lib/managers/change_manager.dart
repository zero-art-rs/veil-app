import 'package:fixnum/fixnum.dart';
import 'package:rxdart/subjects.dart';
import 'package:veil/protos/zero_art.pb.dart';

class SyncChange {
  Map<int, SPFrame> frames;
  final subject = BehaviorSubject<SPFrame>();

  SyncChange({required this.frames});
}

class ChangeManager {
  static final ChangeManager instance = ChangeManager();

  final Map<String, SyncChange?> _state = {};

  void setup(String id) {
    _state[id] = SyncChange(frames: {});
  }

  void addFrame({
    required String groupId,
    required SPFrame frame,
    required int sequenceNumber,
  }) {
    final syncChange = _state[groupId];

    if (syncChange == null) {
      _state[groupId] = SyncChange(frames: {sequenceNumber: frame});
      return;
    }

    syncChange.frames[sequenceNumber] = frame;
    syncChange.subject.add(
      SPFrame(seqNum: Int64(sequenceNumber), frame: frame.frame),
    );
  }

  void clearRange(String chatId, int startIndex, int endIndex) {
    for (var i = startIndex; i <= endIndex; i++) {
      _state.remove(i.toString());
    }
  }

  Map<int, SPFrame> getFrames(String chatId) {
    return _state[chatId]!.frames;
  }

  BehaviorSubject<SPFrame> stream(String chatId) {
    return _state[chatId]!.subject;
  }
}
