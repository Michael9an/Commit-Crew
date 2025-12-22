import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    
    // --- FIX: Loop through the barcodes list ---
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        
        final String rawValue = barcode.rawValue!;
        final String userId = FirebaseAuth.instance.currentUser!.uid;

        // --- FIXED LOGIC START ---
        String eventId = rawValue;

        // Check if it looks like a dynamic QR (contains at least one underscore)
        if (rawValue.contains('_')) {
          // Find the LAST underscore (which separates the ID from the dynamic timestamp)
          int lastUnderscoreIndex = rawValue.lastIndexOf('_');
          
          if (lastUnderscoreIndex > 0) {
            // Take everything BEFORE the last underscore
            eventId = rawValue.substring(0, lastUnderscoreIndex);
          }
        }
        // --- FIXED LOGIC END ---

        // Debug Print: Check what ID we are actually sending
        print("Scanned Raw: $rawValue"); 
        print("Extracted ID: $eventId");

        try {
          // 1. Capture the Map result
          final Map<String, dynamic> result = await FirestoreService().markAttendance(eventId, userId);
          
          final bool success = result['success'];
          final String message = result['message'];

          if (!mounted) return;

          if (success) {
            // Success Dialog
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
                title: const Text("Checked In!"),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); 
                      Navigator.pop(context); 
                    },
                    child: const Text("OK"),
                  )
                ],
              ),
            );
          } else {
            // Error handling
            _showError(message);
            
            // Resume scanning after delay
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _isProcessing = false);
          }
        } catch (e) {
          _showError("Scan failed: $e");
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _isProcessing = false);
        }
        
        // Break after processing the first valid barcode
        break; 
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Event QR")),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}