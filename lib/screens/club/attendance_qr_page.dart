import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/event.dart';

class AttendanceQRPage extends StatefulWidget {
  final EventModel event;
  const AttendanceQRPage({super.key, required this.event});

  @override
  State<AttendanceQRPage> createState() => _AttendanceQRPageState();
}

class _AttendanceQRPageState extends State<AttendanceQRPage> {
  late Timer _timer;
  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _generateDynamicCode();
    // Refresh code every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _generateDynamicCode();
    });
  }

  void _generateDynamicCode() {
    if (!mounted) return;
    setState(() {
      // Format: "eventID_timestamp"
      // e.g., "evt123_1715000000000"
      final now = DateTime.now().millisecondsSinceEpoch;
      _qrData = '${widget.event.id}_$now';
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Attendance QR")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.event.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            
            // Security Warning Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.security, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Code changes every 5s", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // QR Code
            QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 300.0,
              backgroundColor: Colors.white,
            ),
            
            const SizedBox(height: 30),
            const Text(
              "Do not screenshot. Use live scanner.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}