// create_event_flow.dart - Enhanced and fixed version
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_details_page.dart';
import 'event_pricing_page.dart';
import 'event_overview_page.dart';
import '../../../models/event.dart';
import '../../../models/club.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/firebase_init.dart';

class CreateEventFlow extends StatefulWidget {
  final Club club;
  
  const CreateEventFlow({super.key, required this.club});

  @override
  _CreateEventFlowState createState() => _CreateEventFlowState();
}

class _CreateEventFlowState extends State<CreateEventFlow> {
  int _currentStep = 0;
  late EventModel _eventData;

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeEventData();
  }

  void _initializeEventData() {
  _eventData = EventModel(
      id: '',
      name: '',
      description: '',
      date: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: '19:00', // Default start time
      endTime: '21:00',   // Default end time
      bannerUrl: null,
      location: '',
      clubId: widget.club.id,
      clubName: widget.club.name,
      clubImageUrl: widget.club.imageUrl,
      maxAttendees: 50, // Default capacity
      price: 0.0,
      isFree: true,
      refundPolicy: 'No refunds available for this event.',
      publishTime: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      status: 'draft',
      attendees: [],
      waitlist: [],
      views: 0,
      shares: 0,
      isCancelled: false,
      updatedAt: DateTime.now(),
      category: 'General',
      tags: [],
      contactEmail: widget.club.contactEmail ?? '',
      contactPhone: widget.club.contactPhone ?? '',
    );
  }
  void _goToPage(int page) {
    if (_isSubmitting) return;
    setState(() {
      _currentStep = page;
    });
  }

  void _submitEvent() async {
    if (_isSubmitting || !mounted) return;

    // Enhanced validation with specific error messages
    final validationError = _validateEventData();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Navigate to the appropriate step based on the error
      if (validationError.contains('name') || 
          validationError.contains('description') || 
          validationError.contains('location') ||
          validationError.contains('date')) {
        _goToPage(0);
      } else if (validationError.contains('price') || 
                 validationError.contains('attendees')) {
        _goToPage(1);
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final progressNotifier = ValueNotifier<String>('Creating event...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: ValueListenableBuilder<String>(
            valueListenable: progressNotifier,
            builder: (context, statusMessage, _) {
              return AlertDialog(
                title: Text('Creating Event'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(statusMessage),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    try {
      progressNotifier.value = 'Checking connection...';
      
      // Initialize Firebase if needed
      final firebaseReady = await isFirebaseInitialized();
      if (!firebaseReady) {
        progressNotifier.value = 'Initializing Firebase...';
        final initialized = await safeInitializeFirebase();
        if (!initialized) {
          throw Exception('Unable to connect to Firebase. Please check your internet connection and try again.');
        }
      }

      // Generate a unique ID for the event
      final generatedId = '${widget.club.id}_${DateTime.now().millisecondsSinceEpoch}';
      EventModel eventToSave = _eventData.copyWith(
        id: generatedId,
        status: 'published', // Set to published immediately
        createdAt: DateTime.now(),
      );

      // Handle image upload if there's a banner
      String? bannerDownloadUrl = await _handleImageUpload(eventToSave, progressNotifier);
      if (bannerDownloadUrl != null) {
        eventToSave = eventToSave.copyWith(bannerUrl: bannerDownloadUrl);
      }

      progressNotifier.value = 'Saving event details...';
      
      // Save event to Firestore
      await _firestoreService.addEvent(eventToSave).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Failed to save event: operation timed out. Please try again.');
        },
      );
      
      // Update club's events list
      progressNotifier.value = 'Updating club information...';
      await _updateClubEvents(eventToSave.id);
      
      if (!mounted) return;
      
      // Close progress dialog
      Navigator.pop(context);
      
      // Show success message
      _showSuccessDialog(eventToSave.name);
      
    } catch (e) {
      print('Event creation error: $e');
      _handleError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Validate event data before submission
  String? _validateEventData() {
  if (_eventData.name.isEmpty) {
    return 'Please enter event name';
  }
  if (_eventData.name.length < 3) {
    return 'Event name should be at least 3 characters long';
  }
  if (_eventData.description.isEmpty) {
    return 'Please enter event description';
  }
  if (_eventData.description.length < 10) {
    return 'Event description should be at least 10 characters long';
  }
  if (_eventData.location.isEmpty) {
    return 'Please enter event location';
  }
  if (_eventData.date.isEmpty) {
    return 'Please select event date';
  }
  if (_eventData.startTime.isEmpty) {
    return 'Please select start time';
  }
  if (_eventData.endTime.isEmpty) {
    return 'Please select end time';
  }
  
  // Validate date is not in the past
  try {
    final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(_eventData.date));
    if (eventDate.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
      return 'Event date cannot be in the past';
    }
  } catch (e) {
    return 'Invalid event date format';
  }
  
  // Validate time order
  if (_eventData.startTime.isNotEmpty && _eventData.endTime.isNotEmpty) {
    final start = _parseTime(_eventData.startTime);
    final end = _parseTime(_eventData.endTime);
    if (start != null && end != null && end.isBefore(start)) {
      return 'End time cannot be before start time';
    }
  }
  
  if (!_eventData.isFree && _eventData.price <= 0) {
    return 'Please enter a valid price for paid events';
  }
  if (_eventData.maxAttendees <= 0) {
    return 'Please enter maximum number of attendees';
  }
  
  return null;
}

// Helper method to parse time strings
TimeOfDay? _parseTime(String timeString) {
  try {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    }
  } catch (e) {
    print('Error parsing time: $e');
  }
  return null;
}

  // Handle image upload separately
  Future<String?> _handleImageUpload(EventModel eventToSave, ValueNotifier<String> progressNotifier) async {
    if (eventToSave.bannerUrl == null || eventToSave.bannerUrl!.isEmpty) {
      return null;
    }

    // Check if it's a local file that needs uploading
    if (eventToSave.bannerUrl!.startsWith('/') || 
        eventToSave.bannerUrl!.startsWith('file://') ||
        !eventToSave.bannerUrl!.startsWith('http')) {
      
      progressNotifier.value = 'Uploading event image...';
      final imageFile = File(eventToSave.bannerUrl!.replaceFirst('file://', ''));
      
      if (await imageFile.exists()) {
        try {
          final downloadUrl = await _storageService.uploadEventImage(
            imageFile,
            eventToSave.id,
            onProgress: (progress) {
              if (mounted) {
                progressNotifier.value = 
                  'Uploading image: ${(progress * 100).toStringAsFixed(1)}%';
              }
            },
          ).timeout(
            Duration(seconds: 45),
            onTimeout: () {
              throw TimeoutException('Image upload took too long. Please try again.');
            },
          );

          return downloadUrl;
        } catch (uploadError) {
          print('Image upload failed: $uploadError');
          progressNotifier.value = 'Image upload failed, continuing without image...';
          await Future.delayed(Duration(seconds: 1));
          return null;
        }
      } else {
        progressNotifier.value = 'Image file not found, continuing without image...';
        return null;
      }
    }
    
    // If it's already an HTTP URL, return it as is
    return eventToSave.bannerUrl;
  }

  // Update club's events list
  Future<void> _updateClubEvents(String eventId) async {
    try {
      // Add event ID to club's events list using Firestore directly
      await FirebaseFirestore.instance.collection('clubs').doc(widget.club.id).update({
        'eventIds': FieldValue.arrayUnion([eventId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating club events: $e');
      // Don't throw here - the event was created successfully
    }
  }

  // Show success dialog
  void _showSuccessDialog(String eventName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Event "$eventName" created successfully!'),
              SizedBox(height: 16),
              Icon(Icons.event_available, size: 48, color: Colors.green),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                Navigator.pop(context); // Close create event flow
              },
              child: Text('Back to Dashboard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close success dialog
                Navigator.pop(context); // Close create event flow
                // Optionally navigate to manage events screen
              },
              child: Text('View Event'),
            ),
          ],
        );
      },
    );
  }

  // Handle errors
  void _handleError(dynamic e) {
    if (!mounted) return;
    
    Navigator.pop(context); // Close progress dialog
    
    String errorMessage = 'An unexpected error occurred. Please try again.';
    
    if (e is TimeoutException) {
      errorMessage = e.message ?? 'Operation timed out. Please check your connection and try again.';
    } else if (e is FirebaseException) {
      errorMessage = 'Database error: ${e.message}';
    } else if (e is SocketException) {
      errorMessage = 'Network error. Please check your internet connection.';
    } else {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          textColor: Colors.white,
        ),
      ),
    );
  }

  // Confirm exit when back button is pressed
  Future<bool> _onWillPop() async {
    if (_isSubmitting) return false;
    
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      return false;
    }
    
    final shouldExit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard Event?'),
        content: Text('Are you sure you want to discard this event? All progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Discard',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      EventDetailsPage(
        eventData: _eventData,
        onNext: (updated) {
          setState(() {
            _eventData = updated;
            _goToPage(1);
          });
        },
      ),
      EventPricingPage(
        eventData: _eventData,
        onNext: (updated) {
          setState(() {
            _eventData = updated;
            _goToPage(2);
          });
        },
        onBack: () => _goToPage(0),
      ),
      EventOverviewPage(
        eventData: _eventData,
        onSubmit: _isSubmitting ? null : _submitEvent,
        onBack: () => _goToPage(1),
        isSubmitting: _isSubmitting,
      ),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Create Event - ${widget.club.name}',
            style: TextStyle(fontSize: 16),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _isSubmitting ? null : () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_isSubmitting)
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / pages.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _isSubmitting ? Colors.grey : Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            // Step indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of ${pages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isSubmitting ? Colors.grey : Colors.black54,
                    ),
                  ),
                  Text(
                    _getStepTitle(_currentStep),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _isSubmitting ? Colors.grey : Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 4),
            // Step dots
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentStep
                          ? Theme.of(context).primaryColor
                          : index < _currentStep
                              ? Colors.green
                              : Colors.grey[300],
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isSubmitting,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: pages[_currentStep],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Event Details';
      case 1: return 'Pricing & Capacity';
      case 2: return 'Review & Publish';
      default: return '';
    }
  }
}