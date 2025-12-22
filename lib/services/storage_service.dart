import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class StorageService {
  // Your Google Apps Script URL
  final String _scriptUrl = "https://script.google.com/macros/s/AKfycbzS64lYI-JNg8qc_eLK-qJdvjXueeKd12gs2XoeDYgGwqTNIc9HIDsiZLt3aeQ9Zjeo/exec";

  // ================== PUBLIC METHODS ==================

  Future<String> uploadVerificationDocument(String clubId, File file, String extension) async {
    return _uploadToGoogleDrive(clubId, file, extension, "verification");
  }

  Future<String?> uploadEventImage(File imageFile, String eventId, {Function(double)? onProgress}) async {
    onProgress?.call(0.2); 
    String extension = imageFile.path.split('.').last;
    String url = await _uploadToGoogleDrive(eventId, imageFile, extension, "event_image");
    onProgress?.call(1.0);
    return url;
  }

  Future<String?> uploadProfilePicture(File imageFile, String userId) async {
    String extension = imageFile.path.split('.').last;
    return _uploadToGoogleDrive(userId, imageFile, extension, "profile_picture");
  }

  Future<String?> resolveImageUrl(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http')) return url;

    // Convert Drive View Links to Direct Image Links for display
    if (url.contains('drive.google.com') && url.contains('/file/d/')) {
      try {
        final RegExp regExp = RegExp(r'/file/d/([^/]+)');
        final match = regExp.firstMatch(url);
        if (match != null && match.groupCount >= 1) {
          return "https://drive.google.com/uc?export=view&id=${match.group(1)}";
        }
      } catch (e) {
        print("Error parsing Drive URL: $e");
      }
    }
    return url;
  }

  // ================== UPLOAD LOGIC (FIXED) ==================

  Future<String> _uploadToGoogleDrive(String id, File file, String extension, String type) async {
    try {
      List<int> fileBytes = await file.readAsBytes();
      String base64String = base64Encode(fileBytes);
      String fileName = "${type}_${id}.$extension";
      String mimeType = _getMimeType(extension);

      var payload = jsonEncode({
        "filename": fileName,
        "mimeType": mimeType,
        "file": base64String,
      });

      // 1. Send Request
      var response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"}, 
        body: payload,
      );

      // 2. Handle Google Redirects (THIS FIXES THE <HTML> ERROR)
      String responseBody = response.body;
      if (response.statusCode == 302 || response.headers.containsKey('location')) {
        String? newUrl = response.headers['location'];
        if (newUrl != null) {
          var secondResponse = await http.get(Uri.parse(newUrl));
          responseBody = secondResponse.body;
        }
      }

      // 3. Validate Response
      if (responseBody.trim().startsWith("<")) {
         throw FormatException("Upload failed. Google returned HTML. Script might need redeployment.");
      }

      var jsonResponse = jsonDecode(responseBody);
      if (jsonResponse['status'] == 'success') {
        return jsonResponse['url'];
      } else {
        throw Exception('Script error: ${jsonResponse['message']}');
      }

    } catch (e) {
      print('StorageService Error: $e');
      throw e;
    }
  }

  Future<String?> uploadClubLogo(File imageFile, String clubId) async {
    String extension = imageFile.path.split('.').last;
    // We use "club_logo" as the type so files are named nicely in Drive (e.g., club_logo_123.jpg)
    return _uploadToGoogleDrive(clubId, imageFile, extension, "club_logo");
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg': 
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }
}