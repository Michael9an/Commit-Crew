import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../models/user.dart';
import '../../services/registration_service.dart';
import '../../services/auth_service.dart';
import 'payment_gateway_screen.dart';

class EventRegistrationScreen extends StatefulWidget {
  final EventModel event;
  final int ticketQuantity;

  const EventRegistrationScreen({
    Key? key,
    required this.event,
    this.ticketQuantity = 1,
  }) : super(key: key);

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();
  
  // Form controllers
  TextEditingController _fullNameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  
  bool _acceptTerms = false;
  bool _isSubmitting = false;
  bool _isUserLoggedIn = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      setState(() {
        _isUserLoggedIn = true;
        _currentUser = user;
        _fullNameController.text = user.name;
        _emailController.text = user.email;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showSuccessDialog(BuildContext context, bool isPaidEvent, String registerId) {
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
                    color: Color(0xFF4CAF50).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Color(0xFF4CAF50),
                    size: 36,
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Title - Dynamic based on event type
              Center(
                child: Text(
                  isPaidEvent ? 'Payment Successful!' : 'Registration Successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 8),
              
              // Success Message - Dynamic based on event type
              Center(
                child: Text(
                  isPaidEvent 
                    ? 'Your payment has been processed successfully.'
                    : 'You have successfully registered for the event.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              
              // Registration ID
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_number, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registration ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            registerId,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
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
                  // View Ticket Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Navigate to ticket screen
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'View Ticket',
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
                        backgroundColor: Colors.red,
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

              // Booking/Registration Details Card
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
                      isPaidEvent ? 'Booking Details' : 'Registration Details',
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
                          color: Colors.red,
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
                    
                    // Registration Details (for both)
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.red,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Name: ${_fullNameController.text}',
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
                          color: Colors.red,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email: ${_emailController.text}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Ticket Quantity (only for paid events)
                    if (isPaidEvent) SizedBox(height: 8),
                    if (isPaidEvent)
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            size: 16,
                            color: Colors.red,
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
                    
                    // Total Amount (only for paid events)
                    if (isPaidEvent) SizedBox(height: 8),
                    if (isPaidEvent)
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Colors.red,
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
                            'RM${(widget.event.price * widget.ticketQuantity + (widget.event.price * widget.ticketQuantity * 0.03)).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    
                    // For free events, show "FREE" badge
                    if (!isPaidEvent) SizedBox(height: 8),
                    if (!isPaidEvent)
                      Row(
                        children: [
                          Icon(
                            Icons.money_off,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              'FREE EVENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // Email Confirmation - Dynamic message
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
                            isPaidEvent
                              ? 'A confirmation email with payment receipt has been sent.'
                              : 'A confirmation email has been sent to your registered email address.',
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
                      onPressed: () {
                        // TODO: Implement save to calendar functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Event saved to calendar'),
                            backgroundColor: Color(0xFF4CAF50),
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
                        backgroundColor: Colors.red,
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

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Register for the event
      final result = await _registrationService.registerToEvent(
        eventId: widget.event.id,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        ticketQuantity: widget.ticketQuantity,
        userId: _currentUser?.id,
        isFree: widget.event.isFree,
        amountPaid: widget.event.isFree ? 0.0 : widget.event.price * widget.ticketQuantity,
      );

      if (result['success'] == true) {
        final registerId = result['registerId'];
      
      // Navigate to payment screen for paid events
      if (!widget.event.isFree) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentGatewayScreen(
              event: widget.event,
              ticketQuantity: widget.ticketQuantity,
              totalAmount: widget.event.price * widget.ticketQuantity + 
                          (widget.event.price * widget.ticketQuantity * 0.03), // Price + 3% service fee
              registrationData: {
                'fullName': _fullNameController.text,
                'email': _emailController.text,
                'phone': _phoneController.text,
                'registerId': registerId,
              },
            ),
          ),
        ).then((success) async {
          if (success == true) {
            // Payment was successful - update registration
            await _registrationService.completePayment(
              registerId: registerId,
              amount: widget.event.price * widget.ticketQuantity,
              paymentId: 'payment_${DateTime.now().millisecondsSinceEpoch}',
            );

            //show success dialog
            _showSuccessDialog(context, true, registerId); // true = paid event
          }
        });
      } else {
        // For free events, show success directly
        _showSuccessDialog(context, false, registerId); // false = free event
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Registration'),
        centerTitle: true,
        backgroundColor: Colors.red,
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
                    SizedBox(height: 12),
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
                          'RM${(widget.event.price * widget.ticketQuantity * 0.03).toStringAsFixed(2)}',
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
                          widget.event.isFree ? 'FREE' : 'RM${(widget.event.price * widget.ticketQuantity + (widget.event.price * widget.ticketQuantity * 0.03)).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: widget.event.isFree ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Registration Form
              Text(
                'Registration Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please fill in your details to register for this event.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!RegExp(r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$').hasMatch(value)) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // Terms and Conditions
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptTerms = value ?? false;
                                });
                              },
                              activeColor: Colors.red,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'I agree to the Terms and Conditions *',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Terms and Conditions'),
                                          content: SingleChildScrollView(
                                            child: Text(
                                              'By registering for this event, you agree to:\n\n'
                                              '1. Follow all event rules and regulations\n'
                                              '2. Behave appropriately at the venue\n'
                                              '3. Accept that tickets are non-refundable\n'
                                              '4. Allow the organizer to use photos/videos taken at the event\n'
                                              '5. Follow COVID-19 safety protocols if applicable\n\n'
                                              'The organizer reserves the right to refuse entry or remove attendees who violate these terms.',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'View Terms and Conditions',
                                      style: TextStyle(
                                        color: Colors.red,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 32),

                  //CONTINUE HERE DEEPSEEK FROM NEW CHAT
                  //FOCUS ON CREDIT/DEBIT CARD PAYMENT BC THEY CAN USE SANDBOX TO SIMULATE A REAL TRANSACTION
                  //MAKE TWO SEPARATE REGISTRATION (AUTO FILL DETAILS IF REGISTERING FOR YOURSELF OR GIVE OPTION (BUTTON OR SOMETHING) IF YOU WANT TO REGISTER OTHERS)

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.event.isFree ? 'COMPLETE REGISTRATION' : 'PROCEED TO PAYMENT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Required Fields Note
                    Text(
                      '* Required fields',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}