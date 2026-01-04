import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';

class TicketScannerPage extends StatefulWidget {
  final EventModel event;

  const TicketScannerPage({super.key, required this.event});

  @override
  State<TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<TicketScannerPage> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();
  int _scannedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        _processTicket(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _processTicket(String qrData) async {
    // Expected Format: "EVENTID_USERID"
    // Example: "evt123_user456"
    
    // 1. Basic Validation
    if (!qrData.contains('_')) {
      _showResultDialog(false, "Invalid Format", "This is not a valid ticket.");
      return;
    }

    final parts = qrData.split('_');
    final ticketEventId = parts[0];
    final ticketUserId = parts.sublist(1).join('_'); // Join back in case userId has underscores

    if (ticketEventId != widget.event.id) {
      _showResultDialog(false, "Wrong Event", "This ticket is for a different event.");
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      // Note: Adjust 'registrations' to match your actual collection name (e.g., 'event_registrations' or subcollection)
      // Assuming structure: registrations/{eventId_userId}
      final docRef = firestore.collection('registrations').doc('${widget.event.id}_$ticketUserId');
      final doc = await docRef.get();

      if (!doc.exists) {
        _showResultDialog(false, "Not Found", "No registration found for this user.");
        return;
      }

      final data = doc.data()!;
      final status = data['status'] ?? 'registered';

      if (status == 'attended') {
        // Already checked in
        _showResultDialog(false, "Already Used", "This ticket has already been scanned.", isWarning: true);
      } else if (status == 'cancelled') {
        _showResultDialog(false, "Cancelled", "This ticket is no longer valid.");
      } else {
        // Success: Mark as attended
        await docRef.update({
          'status': 'attended',
          'checkInTime': FieldValue.serverTimestamp(),
          'scannedBy': 'volunteer', // Optional auditing
        });
        
        setState(() => _scannedCount++);
        _showResultDialog(true, "Verified!", "Welcome ${data['userName'] ?? 'Participant'}");
      }

    } catch (e) {
      _showResultDialog(false, "Error", "Database error: $e");
    }
  }

  void _showResultDialog(bool success, String title, String message, {bool isWarning = false}) {
    Color color = success ? Colors.green : (isWarning ? Colors.orange : Colors.red);
    IconData icon = success ? Icons.check_circle : (isWarning ? Icons.warning_amber : Icons.cancel);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Delay slightly to prevent double-scanning the same code instantly
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _isProcessing = false);
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text("Scan Next", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scanning: ${widget.event.name}"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text("Total Checked In: $_scannedCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay Box
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                "Point camera at participant's QR Code",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}