import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/validation/phone.dart';

void main() {
  test(
    'optional phones share normalized valid and invalid cases with the API',
    () {
      final cases =
          jsonDecode(File('test/fixtures/phone_cases.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final sample in cases['valid'] as List) {
        expect(
          normalizeOptionalPhone(sample['input'] as String),
          sample['normalized'],
        );
        expect(validateOptionalPhone(sample['input'] as String), isNull);
      }
      for (final input in cases['invalid'] as List) {
        expect(normalizeOptionalPhone(input as String), isNull);
        expect(validateOptionalPhone(input), phoneFormatMessage);
      }
      expect(validateOptionalPhone(null), isNull);
    },
  );
}
