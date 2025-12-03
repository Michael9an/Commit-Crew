import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../services/firestore_service.dart';

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
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.club.name);
    _descriptionController = TextEditingController(text: widget.club.description);
    _websiteController = TextEditingController(text: widget.club.website ?? '');
    _locationController = TextEditingController(text: widget.club.location ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create a map of updated data
      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'website': _websiteController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': DateTime.now(),
      };

      await _firestoreService.updateClub(widget.club.id, updates);

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Club details updated successfully')),
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
                  // Cancel editing: revert changes
                  _initializeControllers();
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
              // Club Image
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: widget.club.imageUrl.isNotEmpty
                          ? NetworkImage(widget.club.imageUrl)
                          : null,
                      child: widget.club.imageUrl.isEmpty
                          ? Icon(Icons.group, size: 60)
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          radius: 18,
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Image upload feature coming soon')),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 30),

              // Club Status Badge
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

              // Form Fields
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

              // Save Button
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
      validator: validator,
    );
  }
}