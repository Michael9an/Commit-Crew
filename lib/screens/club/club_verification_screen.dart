import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/club.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class ClubVerificationScreen extends StatefulWidget {
  final Club club;

  const ClubVerificationScreen({super.key, required this.club});

  @override
  _ClubVerificationScreenState createState() => _ClubVerificationScreenState();
}

class _ClubVerificationScreenState extends State<ClubVerificationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;

  Future<void> _pickDocument() async {
    try {
      // Pick PDF or DOC files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  Future<void> _submitVerification() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a supporting document')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final extension = _fileName?.split('.').last ?? 'pdf';
      
      // 1. Upload to YOUR Google Drive via the Script
      final driveLink = await _storageService.uploadVerificationDocument(
        widget.club.id, 
        _selectedFile!, 
        extension
      );

      // 2. Save the Google Drive Link to Firestore
      await _firestoreService.submitClubVerification(widget.club.id, driveLink);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Club Verification')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Club Information',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Divider(),
                    _buildInfoRow('Club Name', widget.club.name),
                    _buildInfoRow('Description', widget.club.description),
                    _buildInfoRow('Email', widget.club.contactEmail ?? 'N/A'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Upload Section
            Text(
              'Verification Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please upload the official UTM approval letter or supporting documentation to verify your club status. (PDF, DOC, DOCX)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file, size: 48, color: Colors.blue),
                  SizedBox(height: 8),
                  if (_fileName != null) ...[
                    Text(
                      _fileName!,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    TextButton.icon(
                      icon: Icon(Icons.change_circle, size: 16),
                      label: Text('Change File'),
                      onPressed: _isUploading ? null : _pickDocument,
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: _isUploading ? null : _pickDocument,
                      child: Text('Select Document'),
                    ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_selectedFile == null || _isUploading) ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: _isUploading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit for Verification',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}