const phoneFormatMessage = '請輸入有效的台灣手機或含區碼市話，例如 0912345678、02-23456789；亦可留空';

String? normalizeOptionalPhone(String? value) {
  final input = (value ?? '').trim();
  if (input.isEmpty) return '';
  if (input.length > 40 ||
      !RegExp(
        r'^(?:\+?[0-9]+(?:[ -][0-9]+)*|(?:\+886[ -]?)?\([0-9]{1,4}\)[ -]?[0-9]+(?:[ -][0-9]+)*)$',
      ).hasMatch(input)) {
    return null;
  }
  var number = input.replaceAll(RegExp(r'[ ()-]'), '');
  if (number.startsWith('+886')) number = '0${number.substring(4)}';
  return RegExp(r'^(?:09[0-9]{8}|0[2-8][0-9]{7,8})$').hasMatch(number)
      ? number
      : null;
}

String? validateOptionalPhone(String? value) =>
    normalizeOptionalPhone(value) == null ? phoneFormatMessage : null;
