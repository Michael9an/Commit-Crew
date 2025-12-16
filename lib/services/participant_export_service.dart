import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/event.dart';

class ParticipantExportService {
  
  /// Shows the bottom sheet to choose between CSV and PDF
  static void showExportOptions(BuildContext context, EventModel event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export Participant Report', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export as CSV (Excel)'),
                  subtitle: const Text('Best for spreadsheet analysis'),
                  onTap: () {
                    Navigator.pop(context);
                    _generateAndExport(context, event, isPdf: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export as PDF'),
                  subtitle: const Text('Best for printing and sharing'),
                  onTap: () {
                    Navigator.pop(context);
                    _generateAndExport(context, event, isPdf: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Core logic to fetch data, generate file, and share
  static Future<void> _generateAndExport(BuildContext context, EventModel event, {required bool isPdf}) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<Map<String, String>> participants = [];

      // 1. Fetch data from 'registers' collection matching the event ID
      final registrationSnapshot = await FirebaseFirestore.instance
          .collection('registers') 
          .where('eventId', isEqualTo: event.id)
          .get();

      for (var doc in registrationSnapshot.docs) {
        final data = doc.data();
        participants.add({
          'name': data['fullName'] ?? 'Unknown',
          'email': data['email'] ?? 'No Email',
          'phone': data['phoneNumber'] ?? '-', 
          'status': data['status'] ?? 'Registered',
        });
      }

      if (participants.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No registration records found to export."))
          );
        }
        return;
      }

      // 2. Generate File
      final directory = await getTemporaryDirectory();
      final dateStr = DateTime.now().toString().split(' ')[0];
      final safeEventName = event.name.replaceAll(RegExp(r'[^\w\s]+'), '');
      File file;

      if (isPdf) {
        // --- PDF GENERATION ---
        final pdf = pw.Document();
        
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(event.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text(dateStr),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Divider(),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  context: context,
                  headers: ['Name', 'Email', 'Phone No', 'Status'],
                  data: participants.map((p) => [p['name'], p['email'], p['phone'], p['status']]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                  },
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 20),
                  child: pw.Text("Generated by Club Event App", style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
                ),
              ];
            },
          ),
        );

        final path = "${directory.path}/${safeEventName}_Report.pdf";
        file = File(path);
        await file.writeAsBytes(await pdf.save());

      } else {
        // --- CSV GENERATION ---
        List<List<String>> csvData = [
          ["Participant Name", "Email", "Phone No", "Status"],
          ...participants.map((p) => [p['name']!, p['email']!, p['phone']!, p['status']!]),
        ];

        String csvString = const ListToCsvConverter().convert(csvData);
        final path = "${directory.path}/${safeEventName}_Report.csv";
        file = File(path);
        await file.writeAsString(csvString);
      }

      // 3. Share
      if (context.mounted) Navigator.pop(context); // Close loading
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Participant Report for ${event.name}'
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to export: $e")));
      }
    }
  }
}