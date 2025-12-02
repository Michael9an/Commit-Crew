import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TestFirebaseScreen extends StatefulWidget {
  const TestFirebaseScreen({super.key});

  @override
  _TestFirebaseScreenState createState() => _TestFirebaseScreenState();
}

class _TestFirebaseScreenState extends State<TestFirebaseScreen> {
  String _status = 'Testing Firebase...';

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    try {
      final storage = FirebaseStorage.instance;
      // Just try to access storage - if this works, Firebase is set up
      setState(() {
        _status = '✅ Firebase is working!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Firebase error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Firebase Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testFirebase,
              child: Text('Test Again'),
            ),
          ],
        ),
      ),
    );
  }
}