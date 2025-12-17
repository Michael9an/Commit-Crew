// storage_service.dart
import 'dart:io';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';
import 'package:firebase_core/firebase_core.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isInitialized = false;

  Future<bool> _ensureInitialized() async {
    if (_isInitialized) return true;
    
    try {
      await Firebase.app();
      _isInitialized = true;
      return true;
    } catch (e) {
      print('StorageService: Firebase not initialized, trying to initialize...');
      try {
        await Firebase.initializeApp();
        _isInitialized = true;
        return true;
      } catch (initError) {
        print('StorageService: Failed to initialize Firebase: $initError');
        return false;
      }
    }
  }

Future<String?> uploadEventImage(
  File imageFile,
  String eventId, {
  void Function(double progress)? onProgress,
}) async {
  print('StorageService: Starting image upload for event $eventId');
  
  // Ensure Firebase is initialized
  final initialized = await _ensureInitialized();
  if (!initialized) {
    print('StorageService: Firebase not initialized');
    throw Exception('Firebase not available. Please check your connection.');
  }

  try {
    // Check if file exists and is readable
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist or is not accessible.');
    }

    // Check file size first (5MB limit)
    final fileSize = await imageFile.length();
    print('StorageService: File size: ${fileSize / 1024 / 1024} MB');
    
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('Image file is too large. Please choose an image under 5MB.');
    }

    // Validate file is an image
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final fileExtension = extension(imageFile.path).toLowerCase();
    if (!allowedExtensions.contains(fileExtension)) {
      throw Exception('Please select a valid image file (JPG, PNG, GIF, WebP).');
    }

    // Prepare upload metadata
    final metadata = SettableMetadata(
      contentType: _getMimeType(fileExtension),
      customMetadata: {
        'eventId': eventId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    // Create unique filename to avoid conflicts
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalName = basename(imageFile.path);
    final fileName = 'events/$eventId/${timestamp}_$originalName';
    
    print('StorageService: Uploading to path: $fileName');
    final storageRef = _storage.ref().child(fileName);
    
    // Create upload task
    final uploadTask = storageRef.putFile(imageFile, metadata);
    
    // Set up completion handler with timeout
    final completer = Completer<String>();
    StreamSubscription? progressSubscription;
    Timer? timeoutTimer;

    // Set timeout (45 seconds for larger files)
    timeoutTimer = Timer(Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        progressSubscription?.cancel();
        uploadTask.cancel();
        completer.completeError(
          TimeoutException('Image upload timed out. Please check your connection and try again.')
        );
      }
    });

    // Listen to upload progress
    progressSubscription = uploadTask.snapshotEvents.listen(
      (TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('StorageService: Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);

        // Handle completion
        if (snapshot.state == TaskState.success) {
          timeoutTimer?.cancel();
          progressSubscription?.cancel();
          
          // Get download URL
          storageRef.getDownloadURL().then((url) {
            print('StorageService: Upload successful. URL: $url');
            if (!completer.isCompleted) {
              completer.complete(url);
            }
          }).catchError((e) {
            print('StorageService: Failed to get download URL: $e');
            if (!completer.isCompleted) {
              completer.completeError(Exception('Failed to get image URL: $e'));
            }
          });
        }
        
        // CORRECTED: Handle errors during upload
        if (snapshot.state == TaskState.error) {
          timeoutTimer?.cancel();
          progressSubscription?.cancel();
          // TaskSnapshot doesn't have .error property, so we provide a generic error
          print('StorageService: Upload failed with state: TaskState.error');
          if (!completer.isCompleted) {
            completer.completeError(Exception('Upload failed - please check your connection and try again.'));
          }
        }
      },
      onError: (error) {
        print('StorageService: Upload stream error: $error');
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception('Upload failed: $error'));
        }
      },
      cancelOnError: true,
    );

    // Wait for upload to complete
    final downloadUrl = await completer.future;
    return downloadUrl;
    
  } catch (e) {
    print('StorageService: Error uploading image: $e');
    rethrow; // Re-throw to let caller handle the error
  }
}

  /// Delete an image from storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized) return false;

      // Extract path from URL or use as-is
      String filePath;
      if (imageUrl.startsWith('http')) {
        // Extract path from download URL
        final ref = _storage.refFromURL(imageUrl);
        filePath = ref.fullPath;
      } else if (imageUrl.startsWith('gs://')) {
        final ref = _storage.refFromURL(imageUrl);
        filePath = ref.fullPath;
      } else {
        filePath = imageUrl;
      }

      print('StorageService: Deleting image at path: $filePath');
      await _storage.ref().child(filePath).delete();
      print('StorageService: Image deleted successfully');
      return true;
    } catch (e) {
      print('StorageService: Error deleting image: $e');
      return false;
    }
  }

  /// Upload user profile picture
  Future<String?> uploadProfilePicture(
    File imageFile,
    String userId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized) return null;

      // Check file size (2MB limit for profile pictures)
      final fileSize = await imageFile.length();
      if (fileSize > 2 * 1024 * 1024) {
        throw Exception('Profile picture is too large. Please choose an image under 2MB.');
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = extension(imageFile.path);
      final fileName = 'profiles/$userId/${timestamp}_profile$fileExtension';

      final metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'userId': userId,
          'type': 'profile_picture',
        },
      );

      final storageRef = _storage.ref().child(fileName);
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Use the same upload logic as uploadEventImage but simplified
      final completer = Completer<String>();
      StreamSubscription? progressSubscription;

      progressSubscription = uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);

          if (snapshot.state == TaskState.success) {
            progressSubscription?.cancel();
            storageRef.getDownloadURL().then((url) {
              if (!completer.isCompleted) completer.complete(url);
            }).catchError((e) {
              if (!completer.isCompleted) completer.completeError(e);
            });
          }
        },
        onError: (error) {
          progressSubscription?.cancel();
          if (!completer.isCompleted) completer.completeError(error);
        },
      );

      return await completer.future;
    } catch (e) {
      print('StorageService: Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Resolve image URL with improved error handling
  Future<String?> resolveImageUrl(
    String? storedUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (storedUrl == null || storedUrl.isEmpty) return null;

    // Local file path -> return as-is for Image.file
    if (storedUrl.startsWith('/')) return storedUrl;

    // HTTPS already usable
    if (storedUrl.startsWith('http')) return storedUrl;

    // Ensure Firebase initialized
    final initialized = await _ensureInitialized();
    if (!initialized) {
      print('StorageService: Cannot resolve URL - Firebase not initialized');
      return null;
    }

    try {
      String downloadUrl;
      
      // gs:// style URL
      if (storedUrl.startsWith('gs://')) {
        final ref = _storage.refFromURL(storedUrl);
        downloadUrl = await ref.getDownloadURL().timeout(timeout);
      } 
      // Firebase Storage path
      else {
        final ref = _storage.ref(storedUrl);
        downloadUrl = await ref.getDownloadURL().timeout(timeout);
      }
      
      print('StorageService: Resolved URL: $storedUrl -> $downloadUrl');
      return downloadUrl;
    } on TimeoutException {
      print('StorageService: Timeout resolving URL: $storedUrl');
      return null;
    } catch (e) {
      print('StorageService: Failed to resolve URL $storedUrl -> $e');
      return null;
    }
  }

  /// Get file size of a stored image
  Future<int?> getFileSize(String fileUrl) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized) return null;

      final ref = _storage.refFromURL(fileUrl);
      final metadata = await ref.getMetadata();
      return metadata.size;
    } catch (e) {
      print('StorageService: Error getting file size: $e');
      return null;
    }
  }

  /// Check if file exists in storage
  Future<bool> fileExists(String fileUrl) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized) return false;

      final ref = _storage.refFromURL(fileUrl);
      // Try to get metadata - if it succeeds, file exists
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to get MIME type from file extension
  String _getMimeType(String fileExtension) {
    switch (fileExtension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default to JPEG
    }
  }

  /// Clean up storage by deleting old files (optional maintenance method)
  Future<void> cleanupOldFiles(String folderPath, Duration olderThan) async {
    try {
      final initialized = await _ensureInitialized();
      if (!initialized) return;

      final ref = _storage.ref().child(folderPath);
      final result = await ref.listAll();

      final cutoffTime = DateTime.now().subtract(olderThan);

      for (final item in result.items) {
        final metadata = await item.getMetadata();
        // CORRECTED: Use 'updated' instead of 'updatedAt'
        final updated = metadata.updated ?? metadata.timeCreated;

        if (updated != null && updated.isBefore(cutoffTime)) {
          await item.delete();
          print('StorageService: Deleted old file: ${item.name}');
        }
      }
    } catch (e) {
      print('StorageService: Error during cleanup: $e');
    }
  }
}