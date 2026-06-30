class OpeningHoursService {
  static const String scheduleLabel = '11:30-14:30 e 18:30-21:30';

  const OpeningHoursService._();

  static bool canPlaceOrder(DateTime dateTime) {
    final minutes = dateTime.hour * 60 + dateTime.minute;
    return _isWithin(minutes, 11 * 60 + 30, 14 * 60 + 30) ||
        _isWithin(minutes, 18 * 60 + 30, 21 * 60 + 30);
  }

  static bool _isWithin(int minutes, int start, int end) {
    return minutes >= start && minutes <= end;
  }
}
