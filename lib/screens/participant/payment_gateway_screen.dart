//git test

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart'hide Card;
import '../../models/event.dart';
import '../../services/registration_service.dart';
import '../../services/stripe_service.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final EventModel event;
  final int ticketQuantity;
  final double totalAmount;
  final Map<String, dynamic> registrationData;

  const PaymentGatewayScreen({
    Key? key,
    required this.event,
    required this.ticketQuantity,
    required this.totalAmount,
    required this.registrationData,
  }) : super(key: key);

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  final _formKey = GlobalKey<FormState>();
  final RegistrationService _registrationService = RegistrationService();
  final StripeService _stripeService = StripeService();

  String _selectedPaymentMethod = 'credit_card';
  TextEditingController _cardNumberController = TextEditingController();
  TextEditingController _expiryController = TextEditingController();
  TextEditingController _cvvController = TextEditingController();
  TextEditingController _cardHolderController = TextEditingController();
  bool _isProcessing = false;
  bool _saveCardInfo = false;

  // Define colors
  static const Color primaryColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);

  // Updated payment methods with Stripe for Malaysia/Singapore
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'credit_card',
      'name': 'Credit/Debit Card',
      'icon': Icons.credit_card,
      'color': primaryColor,
      'description': 'Pay securely with your Visa, Mastercard, or AMEX via Stripe',
    },
  ];

  // Test card numbers for Stripe sandbox
  final List<Map<String, String>> _testCards = [
    {'name': 'Visa Success', 'number': '4242424242424242'},
    {'name': 'Visa Fail', 'number': '4000000000000002'},
    {'name': 'Mastercard', 'number': '5555555555554444'},
    {'name': 'Amex', 'number': '378282246310005'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  Future<void> _initializeStripe() async {
    await _stripeService.initialize();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _createPaymentIntent() async {
    try {
      // Convert amount to cent (Stripe uses samllest currency unit)
      final amount = (widget.totalAmount * 100).toInt();

      // Create Payment intent
      final paymentIntent = await _stripeService.createPaymentIntent(
        amount: amount,
        currency: 'myr',
        description: 'Event: ${widget.event.name}',
        metadata: {
          'eventId': widget.event.id,
          'ticketQuantity': widget.ticketQuantity.toString(),
          'registrationId': widget.registrationData['registerId'] ?? '',
        },
      );

      return {
        'success': true,
        'clientSecret': paymentIntent['clientSecret'],
        'paymentIntentId': paymentIntent['id'],
      };
    } catch (error) {
      print('Error creating payment intent: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  Future<void> _processStripePaymentWithSheet() async {
    // Validate card details
    if(!_validateCardDetails()) return; 
      
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create payment with amount in cents
      final amountInCents = (widget.totalAmount * 100).toInt();

      final paymentIntent = await _stripeService.createPaymentIntent(
        amount: amountInCents,
        currency: 'myr',
        description: 'Event: ${widget.event.name}',
        metadata: {
          'event_id': widget.event.id,
          'ticket_quantity': widget.ticketQuantity.toString(),
          'user_email': widget.registrationData['email'],
          'register_id': widget.registrationData['registerId'],
        },
      );

      print('Payment Intent Created: ${paymentIntent['id']}');
      print('Client Secret: ${paymentIntent['client_secret']}');

      // Initialize PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Event Registration',
          customerId: widget.registrationData['email'],
          customerEphemeralKeySecret: null,
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: primaryColor,
              background: Colors.white,
              componentBorder: Colors.grey[300]!,
              componentDivider: Colors.grey[300]!,
            ),
          ),
          billingDetails: BillingDetails(
            name: _cardHolderController.text,
            email: widget.registrationData['email'],
            phone: widget.registrationData['phone'],
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Update registration with payment info
      await _completeRegistration(paymentIntent['id']);

      // Show success dialog
      _showPaymentSuccessDialog(context);

    } on StripeException catch (e) {
      String errorMessage = 'Payment failed';

      if (e.error.code == FailureCode.Canceled) {
        errorMessage = 'Payment was cancelled';
      } else if (e.error.code == FailureCode.Failed) {
        errorMessage = e.error.message ?? 'Payment failed';
      } else if (e.error.code == FailureCode.Timeout) {
        errorMessage = 'Payment timeout. Please try again';
      }  

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: errorColor,
        ),
      );
    } catch (error) {
      print('Payment error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${error.toString()}'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeRegistration(String paymentId) async {
    try {
      final registerId = widget.registrationData['registerId'] as String?;

      if (registerId == null || registerId.isEmpty) {
        throw Exception('Register ID is missing');
      }

      final result = await _registrationService.completePayment(
        registerId: registerId,
        amount: widget.totalAmount,
        paymentId: paymentId,
      );

      if (!result['success']) {
        throw Exception(result['error']?.toString() ?? 'Failed to update registration');
      } 
    } catch (error) {
      print('Registration update error: $error');
      rethrow;
    }
  }

  bool _validateCardDetails() {
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    final expiry = _expiryController.text;
    final cvv = _cvvController.text;
    final cardHolder = _cardHolderController.text;

    // Card number validation
    if (cardNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter card number'),
          backgroundColor: errorColor,
        ),
      );
      return false;
    }

    if (cardNumber.length < 13 || cardNumber.length > 19) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid card number (13-19 digits)'),
        backgroundColor: errorColor,
        ),
      );
      return false;
    }

    // Expiry date validation
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter expiry date in MM/YY format'),
        ),
      );
      return false;
    }

    // Check if expiry date is in the future
    final parts = expiry.split('/');
    final month = int.tryParse(parts[0]);
    final year = 2000 + int.tryParse(parts[1])!;
    
    if (month == null || month < 1 || month > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid month (01-12)'),
          backgroundColor: errorColor,
        ),
      );
      return false;
    }
    
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card has expired'),
          backgroundColor: errorColor,
        ),
      );
      return false;
    }

     // CVV validation
    if (cvv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter CVV'),
          backgroundColor: errorColor,
        ),
      );
      return false;
    }
    
    if (cvv.length < 3 || cvv.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid CVV (3-4 digits)'),
          backgroundColor: errorColor,
        ),
      );
      return false;
    }

    // Card holder name validation
    if (cardHolder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter card holder name'),
          backgroundColor: errorColor,
        ),
      );
      return false;
    }
  
  return true;
  }

  void _showPaymentSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success Icon Header
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: successColor,
                    size: 36,
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Title
              Center(
                child: Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 8),
              
              // Success Message
              Center(
                child: Text(
                  'Your payment has been processed successfully.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              
              // Booking Details Card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    // Event Name
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 16,
                          color: primaryColor,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.event.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Registration Details
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: primaryColor,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Name: ${widget.registrationData['fullName']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 16,
                          color: primaryColor,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email: ${widget.registrationData['email']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Ticket Quantity
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 16,
                          color: primaryColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tickets:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${widget.ticketQuantity}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Total Amount
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 16,
                          color: primaryColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'RM${widget.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // Email Confirmation
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirmation Sent',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'A confirmation email with payment receipt has been sent to ${widget.registrationData['email']}.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  // Save to Calendar Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { // TODO: Implement save to calendar functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Event saved to calendar'),
                            backgroundColor: successColor,
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Save to Calendar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // Continue Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(true); // Return success
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Text(
            'Card Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pay securely with your Visa, Mastercard, or AMEX',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),

          // Test Cards Section (for sandbox)
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[800], size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Stripe Sandbox - Test Cards',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _testCards.map((card) {
                    return GestureDetector(
                      onTap: () {
                        _cardNumberController.text = card['number']!;
                        // Auto-fill other fields with test data
                        if (card['number'] == '4242424242424242') {
                          _expiryController.text = '12/34';
                          _cvvController.text = '123';
                          _cardHolderController.text = 'John Doe';
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber[300]!),
                        ),
                        child: Text(
                          card['name']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber[800],
                          )
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to auto-fill test card details',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Card Number
          TextFormField(
            controller: _cardNumberController,
            decoration: InputDecoration(
              labelText: 'Card Number',
              prefixIcon: Icon(Icons.credit_card, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter card number';
              }
              final cleaned = value.replaceAll(' ', '');
              if (cleaned.length < 13 || cleaned.length > 19) {
                return 'Please enter a valid card number';
              }
              return null;
            },
            onChanged: (value) {
              // Format as 1234 5678 9012 3456
              if (value.length > 0 && value.length % 5 == 0) {
                if (value[value.length - 1] == ' ') {
                  _cardNumberController.text = value.substring(0, value.length - 1);
                } else {
                  _cardNumberController.text = '$value ';
                  _cardNumberController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _cardNumberController.text.length),
                  );
                }
              }
            },
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              // Expiry Date
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  decoration: InputDecoration(
                    labelText: 'MM/YY',
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.datetime,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter expiry date';
                    }
                    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                      return 'Format: MM/YY';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Auto-insert slash
                    if (value.length == 2 && !value.contains('/')) {
                      _expiryController.text = '$value/';
                      _expiryController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _expiryController.text.length),
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 16),
              
              // CVV
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    prefixIcon: Icon(Icons.lock, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter CVV';
                    }
                    if (value.length < 3) {
                      return 'Enter valid CVV';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Card Holder Name
          TextFormField(
            controller: _cardHolderController,
            decoration: InputDecoration(
              labelText: 'Card Holder Name',
              prefixIcon: Icon(Icons.person, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter card holder name';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          
          // Save Card Info
          Row(
            children: [
              Checkbox(
                value: _saveCardInfo,
                onChanged: (value) {
                  setState(() {
                    _saveCardInfo = value ?? false;
                  });
                },
                activeColor: primaryColor,
              ),
              Text(
                'Save card information for future payments',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          
          // Accepted Cards
          SizedBox(height: 16),
          Text(
            'Accepted Cards:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildCardLogo('Visa', 'Visa'),
              SizedBox(width: 12),
              _buildCardLogo('Mastercard', 'Mastercard'),
              SizedBox(width: 12),
              _buildCardLogo('AMEX', 'Amex'),
            ], 
          ),

          // Stripe Powered By
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified, color: Colors.purple, size: 18),
                SizedBox(width: 8),
                Text(
                  'Powered by Stripe',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardLogo(String name, String type) {
    Color color;
    switch (type) {
      case 'Visa':
        color = Colors.blue[900]!;
        break;
      case 'Mastercard':
        color = Colors.red[700]!;
        break;
      case 'Amex':
        color = Colors.blue[400]!;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Registration Summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Registration Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(color: Colors.blue[100]),
                    SizedBox(height: 8),
                    Text(
                      'Name: ${widget.registrationData['fullName']}',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Email: ${widget.registrationData['email']}',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Phone: ${widget.registrationData['phone']}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Event Summary
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: widget.event.bannerUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(widget.event.bannerUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey[200],
                          ),
                          child: widget.event.bannerUrl == null
                              ? Icon(Icons.event, color: Colors.grey[400])
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.event.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.event.clubName,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tickets',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          '${widget.ticketQuantity} × RM${widget.event.price.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Service Fee',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'RM${(widget.totalAmount * 0.03).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'RM${widget.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Payment Methods
              Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              
              // Payment Method Options
              Column(
                children: _paymentMethods.map((method) {
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _selectedPaymentMethod == method['id']
                            ? primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: method['color']?.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          method['icon'],
                          color: method['color'],
                        ),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method['name'],
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            method['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: Radio(
                        value: method['id'],
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value.toString();
                          });
                        },
                        activeColor: primaryColor,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPaymentMethod = method['id'];
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              
              // Credit Card Form 
              SizedBox(height: 24),
              _buildCreditCardForm(),
          
              SizedBox(height: 32),
              
              // Terms and Conditions
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure Payment',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your payment is encrypted and secure. We never store your card details.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'By proceeding, you agree to our Terms of Service and Privacy Policy.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              
              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processStripePaymentWithSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'PAY RM${widget.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}