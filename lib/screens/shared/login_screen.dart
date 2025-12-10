// login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'participant'; // Default role
  final _clubNameController = TextEditingController();
  final _clubDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill for testing (remove in production)
    _emailController.text = 'test@test.com';
    _passwordController.text = 'password';
  }

  @override
  Widget build(BuildContext context) {
    print('LoginScreen: build - isLogin: $_isLogin');
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  Text(
                    'Event Mate',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Welcome back!' : 'Create your account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 40),
                  
                  // Full Name - Registration
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (!_isLogin && (value == null || value.isEmpty)) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                  ],

                  // Role selection (only for registration)
                  if (!_isLogin) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRole,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'participant',
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 20),
                                  SizedBox(width: 8),
                                  Text('Participant Account'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'club',
                              child: Row(
                                children: [
                                  Icon(Icons.group, size: 20),
                                  SizedBox(width: 8),
                                  Text('Club Account'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_selectedRole == 'club')
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Club accounts require admin approval before creating events',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    SizedBox(height: 16),
                  ],

                  // Club Information (only for club registration)
                  if (!_isLogin && _selectedRole == 'club') ...[
                    Text(
                      'Club Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _clubNameController,
                      decoration: InputDecoration(
                        labelText: 'Club Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (value) {
                        if (_selectedRole == 'club' && (value == null || value.isEmpty)) {
                          return 'Please enter club name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _clubDescriptionController,
                      decoration: InputDecoration(
                        labelText: 'Club Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (!_isLogin && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // Confirm password field (only for registration)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: !_isLogin ? (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      } : null,
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  SizedBox(height: 24),
                  
                  // Loading indicator or button
                  appProvider.isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _isLogin ? _login : _register,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          child: Text(
                            _isLogin ? 'Login' : 'Register',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                  
                  SizedBox(height: 16),
                  
                  // Toggle between login and register
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isLogin 
                          ? "Don't have an account? Register here"
                          : "Already have an account? Login here",
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  
                  // Forgot password
                  if (_isLogin) ...[
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _forgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      // Clear form when switching modes
      if (_isLogin) {
        _nameController.clear();
        _confirmPasswordController.clear();
        _clubNameController.clear();
        _clubDescriptionController.clear();
        _selectedRole = 'participant'; // Reset to default
      }
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      print('Attempting login with: ${_emailController.text}');
      
      final success = await context.read<AppProvider>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (!success) {
        final error = context.read<AppProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      print('Attempting registration with: ${_emailController.text}');
      
      final success = await context.read<AppProvider>().register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _selectedRole,
        clubName: _clubNameController.text.trim(),
        clubDescription: _clubDescriptionController.text.trim(),
      );
      
      if (!success) {
        final error = context.read<AppProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        String message = 'Registration successful!';
        if (_selectedRole == 'club') {
          message += ' Your club account is pending admin approval.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password'),
        content: Text('Send password reset email to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AppProvider>().resetPassword(email);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset email sent!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send reset email: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print('LoginScreen: dispose');
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _clubNameController.dispose();
    _clubDescriptionController.dispose();
    super.dispose();
  }
}