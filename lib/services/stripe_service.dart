// Updated

import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  static const String _publishableKey = 'pk_test_51SS91SDMUcLZtTx5XUkt0yFQezNOzJILcQH80lHiQoOSENKB9APCIikNpWmryU8VG34NErJi3UaC93U5Nz03cgpc005sJLRQs3';
  static const String _secretKey = 'sk_test_51SS91SDMUcLZtTx5eVovcKVNdADL36bmQl7YNN4nLl7fqO5daKzFl7hieFLyb0EyXbMhyHIooIDgk5E3YNXpdK7S00x83c2u8R';
  
  Future<void> initialize() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  Future<Map<String, dynamic>> createPaymentIntent({
    required int amount,
    required String currency,
    String description = '',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = {
        'amount': amount.toString(),
        'currency': currency.toLowerCase(),
        'description': description,
      };

      if (metadata != null && metadata.isNotEmpty) {
        metadata.forEach((key, value) {
          body['metadata[$key]'] = value.toString();
        });
      }

      // Direct Stripe API call (for testing only - in production, use a backend)
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        print('Stripe API Error: ${error.toString()}');
        throw Exception('Failed to create payment intent: ${error['error']['message']}');
      }
    } catch (error) {
      print('Error creating payment intent: $error');
      rethrow;
    }
  }

  Future<PaymentMethod> createPaymentMethod({
    required String cardNumber,
    required int expiryMonth,
    required int expiryYear,
    required String cvc,
    String? cardHolderName,
  }) async {
    try {
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: cardHolderName,
            ),
          ),
        ),
      );
      return paymentMethod;
    } catch (e) {
      print('Error creating payment method: $e');
      rethrow;
    }
  }
}