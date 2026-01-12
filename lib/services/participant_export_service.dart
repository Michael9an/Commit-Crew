import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/event.dart';
import 'package:intl/intl.dart';

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
      // 1. Fetch Data
      List<Map<String, String>> participants = [];

      // Fetch from 'registers' collection to get attendance status and check-in time
      final registrationSnapshot = await FirebaseFirestore.instance
          .collection('registers') 
          .where('eventId', isEqualTo: event.id)
          .get();

      for (var doc in registrationSnapshot.docs) {
        final data = doc.data();
        
        // --- FIX START ---
        String status = 'Absent'; 
        // Check for lowercase 'attended' (which matches your scanner)
        final String docStatus = (data['status'] ?? '').toString().toLowerCase();
        
        if (docStatus == 'attended') {
          status = 'Present';
        }

        // --- 2. FORMAT CHECK-IN TIME ---
        String checkInTimeStr = "-"; 
        if (data['checkInTime'] != null) {
          try {
            final Timestamp ts = data['checkInTime'];
            checkInTimeStr = DateFormat('hh:mm a').format(ts.toDate()); 
          } catch (e) {
            checkInTimeStr = "Error";
          }
        }
        
        participants.add({
          'name': data['fullName'] ?? 'Unknown',
          'email': data['email'] ?? 'No Email',
          'phone': data['phoneNumber'] ?? '-', 
          'status': status,
          'checkIn': checkInTimeStr, 
        });
      }

      // Handle Empty List
      if (participants.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No registration records found to export."))
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final safeEventName = event.name.replaceAll(RegExp(r'[^\w\s]+'), ''); 
      File file;

      String eventDateStr = "Date not set";
      if (event.date != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date!));
        eventDateStr = DateFormat('dd MMM yyyy').format(date);
      }
      String eventTimeStr = "${event.startTime} - ${event.endTime}";

      if (isPdf) {
        // --- PDF GENERATION ---
        final pdf = pw.Document();
        
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return [
                // --- UPDATED HEADER ---
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Event Name
                    pw.Text(
                      event.name, 
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold) // Smaller font
                    ),
                    pw.SizedBox(height: 4),
                    
                    // Club Name
                    pw.Text(
                      "Organized by: ${event.clubName}",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)
                    ),
                    pw.SizedBox(height: 8),

                    // Date & Time Row
                    pw.Row(children: [
                      pw.Text("Date: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text("$eventDateStr  |  ", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("Time: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(eventTimeStr, style: const pw.TextStyle(fontSize: 10)),
                    ]),
                    
                    // Location Row
                    pw.Row(children: [
                      pw.Text("Location: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(event.location, style: const pw.TextStyle(fontSize: 10)),
                    ]),

                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    
                    // Stats Summary
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Total Registered: ${participants.length}", style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          "Generated: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}", 
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)
                        ),
                      ]
                    ),
                    pw.SizedBox(height: 10),
                  ],
                ),
                
                // --- TABLE ---
                pw.Table.fromTextArray(
                  context: context,
                  headers: ['Name', 'Email', 'Phone', 'Attendance', 'Check-in Time'],
                  data: participants.map((p) => [
                    p['name'], 
                    p['email'], 
                    p['phone'], 
                    p['status'], 
                    p['checkIn']
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  cellHeight: 25,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                  },
                ),
                
                // Footer
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 20),
                  child: pw.Text(
                    "Generated by Club Event App", 
                    style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8)
                  ),
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
          // Header Info embedded in CSV
          ["Event Report: ${event.name}"],
          ["Club: ${event.clubName}"],
          ["Date: $eventDateStr", "Time: $eventTimeStr"],
          ["Location: ${event.location}"],
          [], // Empty row for spacing
          // Table Headers
          ["Participant Name", "Email", "Phone No", "Attendance Status", "Check-in Time"],
          // Data Rows
          ...participants.map((p) => [
            p['name']!, 
            p['email']!, 
            p['phone']!, 
            p['status']!, 
            p['checkIn']!
          ]),
        ];

        String csvString = const ListToCsvConverter().convert(csvData);
        final path = "${directory.path}/${safeEventName}_Report.csv";
        file = File(path);
        await file.writeAsString(csvString);
      }

      // 3. Share the File
      if (context.mounted) {
        Navigator.pop(context); // Close loading
      }
      
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Attendance Report for ${event.name}'
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to export: $e"), 
            backgroundColor: Colors.red
          )
        );
      }
    }
  }
}