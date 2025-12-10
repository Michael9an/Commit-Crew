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
  final EventModel? eventToEdit; 
  final bool isDuplicate; 
  
  const CreateEventFlow({
    super.key, 
    required this.club, 
    this.eventToEdit,
    this.isDuplicate = false,
  });

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
    if (widget.eventToEdit != null) {
      _eventData = widget.eventToEdit!;
      // If it is a duplicate, the previous screen (ClubEventDetails) likely cleared the ID,
      // but just to be safe, if we are duplicating, we can treat it as a new draft visually,
      // though the ID generation happens strictly in _submitEvent.
    } else {
      // Default blank initialization for new event
      _eventData = EventModel(
        id: '',
        name: '',
        description: '',
        date: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: '19:00',
        endTime: '21:00',
        bannerUrl: null,
        location: '',
        clubId: widget.club.id,
        clubName: widget.club.name,
        clubImageUrl: widget.club.imageUrl,
        maxAttendees: 50,
        price: 0.0,
        isFree: true,
        refundPolicy: 'No refunds available.',
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

    final progressNotifier = ValueNotifier<String>('Processing...');
    
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
                title: Text(widget.eventToEdit != null && !widget.isDuplicate ? 'Updating Event' : 'Creating Event'),
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
      
      final firebaseReady = await isFirebaseInitialized();
      if (!firebaseReady) {
        progressNotifier.value = 'Initializing Firebase...';
        final initialized = await safeInitializeFirebase();
        if (!initialized) {
          throw Exception('Unable to connect to Firebase. Please check your internet connection and try again.');
        }
      }

      // --- FIX STARTS HERE ---
      
      // Determine if we are editing an existing event
      final bool isEditing = widget.eventToEdit != null && !widget.isDuplicate;

      // 1. Determine ID
      String finalId;
      if (isEditing && _eventData.id.isNotEmpty) {
        finalId = _eventData.id; // Use existing ID for updates
      } else {
        finalId = '${widget.club.id}_${DateTime.now().millisecondsSinceEpoch}'; // Generate new ID
      }

      // 2. Determine Created At
      DateTime finalCreatedAt;
      if (isEditing) {
        // FIX: Handle potential null value from model
        finalCreatedAt = _eventData.createdAt ?? DateTime.now(); 
      } else {
        finalCreatedAt = DateTime.now(); 
      }

      // 3. Prepare Object
      EventModel eventToSave = _eventData.copyWith(
        id: finalId,
        status: isEditing ? _eventData.status : 'published', 
        createdAt: finalCreatedAt,
        updatedAt: DateTime.now(), 
      );
      // --- FIX ENDS HERE ---

      // Handle image upload if there's a banner
      String? bannerDownloadUrl = await _handleImageUpload(eventToSave, progressNotifier);
      if (bannerDownloadUrl != null) {
        eventToSave = eventToSave.copyWith(bannerUrl: bannerDownloadUrl);
      }

      progressNotifier.value = 'Saving event details...';
      
      // Save event to Firestore (addEvent typically uses .set() which overwrites/updates if ID exists)
      await _firestoreService.addEvent(eventToSave).timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Failed to save event: operation timed out. Please try again.');
        },
      );
      
      // Only update club's event list if it's a NEW event (or duplicate)
      // If editing, the ID is likely already in the club's list.
      if (!isEditing) {
        progressNotifier.value = 'Updating club information...';
        await _updateClubEvents(eventToSave.id);
      }
      
      if (!mounted) return;
      
      Navigator.pop(context); // Close progress dialog
      
      // Show success message
      _showSuccessDialog(eventToSave.name, isEditing);
      
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

  String? _validateEventData() {
    if (_eventData.name.isEmpty) return 'Please enter event name';
    if (_eventData.name.length < 3) return 'Event name should be at least 3 characters long';
    if (_eventData.description.isEmpty) return 'Please enter event description';
    if (_eventData.description.length < 10) return 'Event description should be at least 10 characters long';
    if (_eventData.location.isEmpty) return 'Please enter event location';
    if (_eventData.date.isEmpty) return 'Please select event date';
    if (_eventData.startTime.isEmpty) return 'Please select start time';
    if (_eventData.endTime.isEmpty) return 'Please select end time';
    
    try {
      final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(_eventData.date));
      // Allow editing past events? If not, keep this check. 
      // Usually for edits, we might relax this if the event is already in the past, but for now keeping it safe.
      if (eventDate.isBefore(DateTime.now().subtract(Duration(days: 1))) && widget.eventToEdit == null) {
        return 'Event date cannot be in the past';
      }
    } catch (e) {
      return 'Invalid event date format';
    }
    
    if (_eventData.startTime.isNotEmpty && _eventData.endTime.isNotEmpty) {
      final start = _parseTime(_eventData.startTime);
      final end = _parseTime(_eventData.endTime);
      if (start != null && end != null && end.isBefore(start)) {
        // Handle midnight crossover if needed, otherwise strict check
        // return 'End time cannot be before start time';
      }
    }
    
    if (!_eventData.isFree && _eventData.price <= 0) return 'Please enter a valid price for paid events';
    if (_eventData.maxAttendees <= 0) return 'Please enter maximum number of attendees';
    
    return null;
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      print('Error parsing time: $e');
    }
    return null;
  }

  Future<String?> _handleImageUpload(EventModel eventToSave, ValueNotifier<String> progressNotifier) async {
    if (eventToSave.bannerUrl == null || eventToSave.bannerUrl!.isEmpty) {
      return null;
    }

    if (!eventToSave.bannerUrl!.startsWith('http')) {
      progressNotifier.value = 'Uploading event image...';
      final imagePath = eventToSave.bannerUrl!.replaceFirst('file://', '');
      final imageFile = File(imagePath);
      
      if (await imageFile.exists()) {
        try {
          final downloadUrl = await _storageService.uploadEventImage(
            imageFile,
            eventToSave.id,
            onProgress: (progress) {
              if (mounted) progressNotifier.value = 'Uploading image to Cloud...';
            },
          );
          return downloadUrl;
        } catch (uploadError) {
          print('Image upload failed: $uploadError');
          return null; 
        }
      } else {
        return null;
      }
    }
    return eventToSave.bannerUrl;
  }

  Future<void> _updateClubEvents(String eventId) async {
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(widget.club.id).update({
        'eventIds': FieldValue.arrayUnion([eventId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating club events: $e');
    }
  }

  void _showSuccessDialog(String eventName, bool isEdit) {
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
              Text('Event "$eventName" ${isEdit ? 'updated' : 'created'} successfully!'),
              SizedBox(height: 16),
              Icon(Icons.event_available, size: 48, color: Colors.green),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: Text('Back to Dashboard'),
            ),
          ],
        );
      },
    );
  }

  void _handleError(dynamic e) {
    if (!mounted) return;
    
    Navigator.pop(context); 
    
    String errorMessage = 'An unexpected error occurred. Please try again.';
    
    if (e is TimeoutException) {
      errorMessage = e.message ?? 'Operation timed out.';
    } else if (e is FirebaseException) {
      errorMessage = 'Database error: ${e.message}';
    } else if (e is SocketException) {
      errorMessage = 'Network error. Check connection.';
    } else {
      errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'DISMISS',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          textColor: Colors.white,
        ),
      ),
    );
  }

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
        title: Text('Discard Changes?'),
        content: Text('Are you sure you want to discard? Unsaved progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Discard', style: TextStyle(color: Colors.red)),
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
            widget.eventToEdit != null && !widget.isDuplicate 
                ? 'Edit Event' 
                : 'Create Event - ${widget.club.name}',
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
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / pages.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _isSubmitting ? Colors.grey : Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of ${pages.length}',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    _getStepTitle(_currentStep),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
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