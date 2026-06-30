import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/app_config.dart';

class StripeService {
  static Future<bool> makePayment(double total, String currency) async {
    try {
      final amountInCents = (total * 100).round();
      final normalizedCurrency = currency.toLowerCase();
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createStripePaymentSheet');
      final response = await callable.call({
        'amount': amountInCents,
        'currency': normalizedCurrency,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final clientSecret = data['clientSecret']?.toString();
      final customerId = data['customer']?.toString();
      final ephemeralKey = data['ephemeralKey']?.toString();

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Falha ao gerar pagamento.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          merchantDisplayName: 'Mega Delivery',
          returnURL: AppConfig.stripeReturnUrl,
          allowsDelayedPaymentMethods: true,
          paymentMethodOrder: const ['card', 'multibanco'],
          billingDetails: const BillingDetails(
            address: Address(
              country: 'PT',
              city: null,
              line1: null,
              line2: null,
              postalCode: null,
              state: null,
            ),
          ),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'PT',
            currencyCode: normalizedCurrency.toUpperCase(),
            testEnv: true,
            label: 'Mega Delivery',
            amount: total.toStringAsFixed(2),
          ),
          applePay: const PaymentSheetApplePay(
            merchantCountryCode: 'PT',
          ),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFFF8A00),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 18,
              borderWidth: 1,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      debugPrint('Stripe payment failed: $e');
      return false;
    }
  }
}
