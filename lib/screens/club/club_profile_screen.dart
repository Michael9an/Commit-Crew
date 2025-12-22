import 'package:flutter/material.dart';
import 'dart:io'; // Needed for File
import 'package:image_picker/image_picker.dart'; // Add this to pubspec.yaml if missing
import '../../models/club.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart'; // Import StorageService

class ClubProfileScreen extends StatefulWidget {
  final Club club;

  const ClubProfileScreen({super.key, required this.club});

  @override
  _ClubProfileScreenState createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _websiteController;
  late TextEditingController _locationController;
  
  bool _isEditing = false;
  bool _isLoading = false;
  
  // Services
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  // Image State
  File? _selectedImage;
  String _currentImageUrl = "";

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _resolveInitialImage();
  }

  Future<void> _resolveInitialImage() async {
    if (widget.club.imageUrl.isNotEmpty) {
      // Use your service to convert the Drive link to a Direct link
      String? resolved = await _storageService.resolveImageUrl(widget.club.imageUrl);
      
      if (mounted && resolved != null) {
        setState(() {
          _currentImageUrl = resolved;
        });
      }
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.club.name);
    _descriptionController = TextEditingController(text: widget.club.description);
    _websiteController = TextEditingController(text: widget.club.website ?? '');
    _locationController = TextEditingController(text: widget.club.location ?? '');
    
    // Reset image selection when cancelling edit
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- IMAGE PICKER LOGIC ---
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, // Gallery only (Club Icon)
        maxWidth: 800, // Optimize size for faster upload
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? newImageUrl;

      if (_selectedImage != null) {
        newImageUrl = await _storageService.uploadClubLogo(_selectedImage!, widget.club.id);
      }

      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'website': _websiteController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': DateTime.now(),
      };

      if (newImageUrl != null) {
        updates['imageUrl'] = newImageUrl;
      }

      await _firestoreService.updateClub(widget.club.id, updates);

      // --- UPDATED LOGIC HERE ---
      // We need to resolve the NEW url immediately too
      String? resolvedNewImage;
      if (newImageUrl != null) {
        resolvedNewImage = await _storageService.resolveImageUrl(newImageUrl);
      }

      setState(() {
        _isEditing = false;
        _isLoading = false;
        _selectedImage = null; 
        
        // Update local state with the RESOLVED url, not the raw one
        if (resolvedNewImage != null) {
          _currentImageUrl = resolvedNewImage;
        }
      });
      // --------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Club profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Club Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _initializeControllers(); // Cancel edits
                }
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              
              // --- BULLETPROOF IMAGE SECTION ---
              Center(
                child: Stack(
                  children: [
                    // 1. The Container + ClipOval replaces CircleAvatar
                    Container(
                      width: 120, // Equivalent to radius 60 * 2
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                      child: ClipOval(
                        child: _buildSafeImage(),
                      ),
                    ),
                    
                    // 2. Edit Button (Only visible in edit mode)
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage, 
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(Icons.photo_library, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ---------------------------------

              SizedBox(height: 30),

              // ... (The rest of your code remains exactly the same: Badge, Fields, Buttons) ...
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.club.isApproved ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.club.isApproved ? 'Verified Club' : 'Pending Approval',
                  style: TextStyle(
                    color: widget.club.isApproved ? Colors.green[800] : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'Club Name',
                icon: Icons.badge,
                enabled: _isEditing,
                validator: (v) => v!.isEmpty ? 'Name cannot be empty' : null,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description,
                enabled: _isEditing,
                maxLines: 3,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Location / Headquarters',
                icon: Icons.location_on,
                enabled: _isEditing,
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _websiteController,
                label: 'Website / Social Link',
                icon: Icons.link,
                enabled: _isEditing,
              ),
              SizedBox(height: 32),
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('Uploading & Saving...'),
                            ],
                          )
                        : Text('Save Changes'),
                  ),
                ),
              if (!_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    "To manage events, go to the Dashboard tab.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NEW SAFE IMAGE BUILDER ---
  Widget _buildSafeImage() {
    // Priority 1: User picked a local file (Preview)
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    }
    
    // Priority 2: Use the Resolved URL
    if (_currentImageUrl.isNotEmpty) {
      return Image.network(
        _currentImageUrl,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        // Shows a loader while fetching
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        // Shows an icon if URL is bad/HTML (PREVENTS CRASH)
        errorBuilder: (context, error, stackTrace) {
          return Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
        },
      );
    }

    // Priority 3: Default Icon
    return Center(child: Icon(Icons.group, size: 60, color: Colors.grey));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
      validator: validator,
    );
  }
}