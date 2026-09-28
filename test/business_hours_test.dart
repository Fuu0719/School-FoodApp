import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/business_hours.dart';

void main() {
  test('daytime and overnight business hours use the starting weekday', () {
    expect(
      isBusinessOpenAt([1], '09:00-18:00', DateTime(2026, 9, 28, 12)),
      isTrue,
    );
    expect(
      isBusinessOpenAt([1], '09:00-18:00', DateTime(2026, 9, 28, 18)),
      isFalse,
    );
    expect(
      isBusinessOpenAt([1], '22:00-02:00', DateTime(2026, 9, 28, 23)),
      isTrue,
    );
    expect(
      isBusinessOpenAt([1], '22:00-02:00', DateTime(2026, 9, 29, 1, 59)),
      isTrue,
    );
    expect(
      isBusinessOpenAt([1], '22:00-02:00', DateTime(2026, 9, 29, 2)),
      isFalse,
    );
    expect(
      isBusinessOpenAt([2], '22:00-02:00', DateTime(2026, 9, 29, 1)),
      isFalse,
    );
    expect(
      isBusinessOpenAt([1], '00:00-23:59', DateTime(2026, 9, 28, 23, 59)),
      isTrue,
    );
  });
}
