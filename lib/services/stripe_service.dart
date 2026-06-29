import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  static Future<bool> makePayment(double total, String currency) async {
    try {
      final amountInCents = (total * 100).round();
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createStripePaymentSheet');
      final response = await callable.call({
        'amount': amountInCents,
        'currency': currency.toLowerCase(),
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final clientSecret = data['clientSecret']?.toString();

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Falha ao gerar pagamento.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Mega Delivery',
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (_) {
      return false;
    }
  }
}
