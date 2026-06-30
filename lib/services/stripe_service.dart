import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/app_config.dart';

class StripeService {
  static Future<bool> makePayment(double total, String currency) async {
    try {
      if (AppConfig.stripePublishableKey.isEmpty) {
        throw Exception(
            'Chave publica da Stripe nao configurada. Define STRIPE_PUBLISHABLE_KEY ao compilar a app.');
      }

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
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return false;
      }

      final message = e.error.localizedMessage ??
          e.error.message ??
          'Nao foi possivel abrir o pagamento Stripe.';
      debugPrint('Stripe payment failed: $message');
      throw Exception(message);
    } on FirebaseFunctionsException catch (e) {
      final message = _formatFirebaseStripeError(
          e.message ?? 'Erro na funcao de pagamento Stripe.');
      debugPrint('Stripe function failed: ${e.code} - $message');
      throw Exception(message);
    } catch (e) {
      debugPrint('Stripe payment failed: $e');
      rethrow;
    }
  }

  static String _formatFirebaseStripeError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid api key') ||
        normalized.contains('pk_test') ||
        normalized.contains('pk_live')) {
      return 'A chave secreta da Stripe no Firebase esta errada. Em STRIPE_SECRET_KEY tens de usar uma chave sk_test_..., nao a pk_test_... publica.';
    }
    return message;
  }
}
