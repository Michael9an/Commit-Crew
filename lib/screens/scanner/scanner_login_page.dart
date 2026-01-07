import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';
import 'ticket_scanner_page.dart';

class ScannerLoginPage extends StatefulWidget {
  const ScannerLoginPage({super.key});

  @override
  State<ScannerLoginPage> createState() => _ScannerLoginPageState();
}

class _ScannerLoginPageState extends State<ScannerLoginPage> {
  final _pinController = TextEditingController();
  String? _selectedEventId;
  EventModel? _selectedEvent;
  bool _isLoading = false;

  // Fetch events that require organizer scanning
  Stream<List<EventModel>> _getScannableEvents() {
    final now = DateTime.now().subtract(const Duration(days: 1)); // Include active events
    return FirebaseFirestore.instance
        .collection('events')
        .where('checkInMethod', isEqualTo: 'organizer_scan')
        // .where('date', isGreaterThan: now.millisecondsSinceEpoch.toString()) // Optional: Filter past
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  void _verifyAndLogin() {
    if (_selectedEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an event")));
      return;
    }

    final inputPin = _pinController.text.trim();
    if (inputPin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter the PIN")));
      return;
    }

    setState(() => _isLoading = true);

    // Verify PIN
    // Note: In a real app, verify this on the backend or use a hash. 
    // For MVP, comparing locally is acceptable if Firestore rules allow reading the event.
    if (_selectedEvent!.scannerPin == inputPin) {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TicketScannerPage(event: _selectedEvent!),
        ),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect PIN. Access Denied."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Staff Scanner Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Event",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<EventModel>>(
              stream: _getScannableEvents(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text("Error loading events");
                if (!snapshot.hasData) return const LinearProgressIndicator();

                final events = snapshot.data!;
                if (events.isEmpty) return const Text("No events require scanning right now.");

                return DropdownButtonFormField<String>(
                  value: _selectedEventId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text("Choose an event..."),
                  items: events.map((event) {
                    return DropdownMenuItem(
                      value: event.id,
                      child: Text(
                        event.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedEventId = val;
                      _selectedEvent = events.firstWhere((e) => e.id == val);
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Enter Access PIN",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter the 4-digit PIN",
                prefixIcon: Icon(Icons.lock),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue[800],
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Access Scanner", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}