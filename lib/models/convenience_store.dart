import 'package:my_app/utils/business_hours.dart';

enum ConvenienceBrand { sevenEleven, familyMart }

class ConvenienceStore {
  const ConvenienceStore({
    required this.id,
    required this.brand,
    required this.name,
    required this.address,
    required this.distanceMeters,
    required this.walkingMinutes,
    required this.businessHours,
    required this.businessWeekdays,
    required this.contactPhone,
  });

  final String id;
  final ConvenienceBrand brand;
  final String name;
  final String address;
  final int distanceMeters;
  final int walkingMinutes;
  final String businessHours;
  final List<int> businessWeekdays;
  final String contactPhone;

  String get brandLabel {
    switch (brand) {
      case ConvenienceBrand.sevenEleven:
        return '7-11';
      case ConvenienceBrand.familyMart:
        return '全家';
    }
  }

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '距離 ${(distanceMeters / 1000).toStringAsFixed(1)} 公里';
    }

    return '距離 $distanceMeters 公尺';
  }

  bool isOpenOn(DateTime date) {
    return businessWeekdays.contains(date.weekday);
  }

  bool isOpenAt(DateTime date) {
    return isBusinessOpenAt(businessWeekdays, businessHours, date);
  }
}
