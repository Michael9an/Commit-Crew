import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/event.dart';
import '../../services/report_service.dart';
import '../../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';

class ParticipantReportEventScreen extends StatefulWidget {
  final EventModel event;

  const ParticipantReportEventScreen({
    super.key,
    required this.event,
  });

  @override
  State<ParticipantReportEventScreen> createState() => _ParticipantReportEventScreenState();
}

class _ParticipantReportEventScreenState extends State<ParticipantReportEventScreen> {
  final ReportService _reportService = ReportService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  String? selectedReason;
  String? screenshotPath;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> reportReasons = [
    'Inappropriate Content',
    'Spam',
    'Fraud',
    'Misleading Information',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          screenshotPath = image.path;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitReport() async {
    if (selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a reason for the report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      if (screenshotPath != null) {
        // Generate a temporary ID for the report image or use a timestamp
        // Ideally, we should get the report ID first, but submitReport generates it.
        // Let's use a timestamp-based ID for the image for now.
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await _storageService.uploadReportImage(File(screenshotPath!), tempId);
      }

      await _reportService.submitReport(
        eventId: widget.event.id,
        eventName: widget.event.name,
        reason: selectedReason!,
        details: _detailsController.text.isNotEmpty
            ? _detailsController.text
            : null,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back after 1 second
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Event'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporting Event',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.event.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Reason Dropdown
              Text(
                'Reason for Report',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: selectedReason,
                  hint: Text('Select a reason'),
                  isExpanded: true,
                  underline: SizedBox(),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  items: reportReasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
              ),

              SizedBox(height: 24),

              // Additional Details
              Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 12),

              TextField(
                controller: _detailsController,
                decoration: InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 5,
              ),

              SizedBox(height: 24),

              // Upload Screenshot
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (screenshotPath == null) ...[
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Upload Screenshot',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        Image.file(
                          File(screenshotPath!),
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.edit),
                          label: Text('Change Screenshot'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 16),

              // Info Text
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your report will be reviewed by our team. Thank you for helping us maintain a safe community.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}