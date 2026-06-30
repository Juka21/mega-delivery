import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_delivery_app/services/opening_hours_service.dart';

void main() {
  group('OpeningHoursService', () {
    test('allows orders inside lunch window', () {
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 11, 30)),
          isTrue);
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 14, 30)),
          isTrue);
    });

    test('allows orders inside dinner window', () {
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 18, 30)),
          isTrue);
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 21, 30)),
          isTrue);
    });

    test('blocks orders outside windows', () {
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 11, 29)),
          isFalse);
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 14, 31)),
          isFalse);
      expect(OpeningHoursService.canPlaceOrder(DateTime(2026, 6, 30, 21, 31)),
          isFalse);
    });
  });
}
