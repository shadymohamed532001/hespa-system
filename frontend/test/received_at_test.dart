import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/features/collections/receive_collection_dialog.dart';

void main() {
  test('uses today for a time earlier in the day', () {
    final now = DateTime(2026, 11, 21, 23, 40);
    expect(
      receivedAtFor(const TimeOfDay(hour: 23, minute: 30), now),
      DateTime(2026, 11, 21, 23, 30),
    );
  });

  test('right after midnight, a late-night time means last night', () {
    final now = DateTime(2026, 11, 22, 0, 10);
    expect(
      receivedAtFor(const TimeOfDay(hour: 23, minute: 50), now),
      DateTime(2026, 11, 21, 23, 50),
    );
  });

  test('a few minutes ahead of the clock still counts as today', () {
    final now = DateTime(2026, 11, 21, 14, 0);
    expect(
      receivedAtFor(const TimeOfDay(hour: 14, minute: 5), now),
      DateTime(2026, 11, 21, 14, 5),
    );
  });

  test('crosses month boundaries', () {
    final now = DateTime(2026, 12, 1, 0, 5);
    expect(
      receivedAtFor(const TimeOfDay(hour: 23, minute: 55), now),
      DateTime(2026, 11, 30, 23, 55),
    );
  });
}
