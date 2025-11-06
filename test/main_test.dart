import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test diff behaviour', () {
    // Move is update block
    // delete is delete
    // insert is insert

    final text1 = ['I am fine', '#Title'];
    final text2 = ['1212', 'I am fine privet kak ti', '#Title'];

    // # content | id1
    // #         | ddd
    // #         | id2

    final updates = calculateListDiff(
      text1,
      text2,
      detectMoves: false,
    ).getUpdatesWithData().toList();

    print(updates);
  });
}
