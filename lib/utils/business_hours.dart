bool isBusinessOpenAt(
  List<int> businessWeekdays,
  String businessHours,
  DateTime date,
) {
  final match = RegExp(
    r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$',
  ).firstMatch(businessHours);
  if (match == null) return false;
  final open = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  final close = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
  final minutes = date.hour * 60 + date.minute;
  if (open == 0 && close >= 1439) {
    return businessWeekdays.contains(date.weekday);
  }
  if (open < close) {
    return businessWeekdays.contains(date.weekday) &&
        minutes >= open &&
        minutes < close;
  }
  final previousWeekday = date.weekday == DateTime.monday
      ? DateTime.sunday
      : date.weekday - 1;
  return (businessWeekdays.contains(date.weekday) && minutes >= open) ||
      (businessWeekdays.contains(previousWeekday) && minutes < close);
}
