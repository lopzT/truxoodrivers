// lib/my_accounts_driver.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/services.dart';
import 'onboarding_page.dart';
import 'license_image_screen.dart';

class MyAccountDriver extends StatefulWidget {
  final String? currentProfileImagePath;
  final bool isLocalImage;
  final bool isNetworkImage;
  final String driverName;
  final String driverPhone;
  final String driverRating;
  final String driverEmail;
  final String truckNumber;
  final String truckType;
  final String truckCapacity;
  final String licenseNumber;
  final String licenseExpiry;

  const MyAccountDriver({
    super.key,
    this.currentProfileImagePath,
    this.isLocalImage = false,
    this.isNetworkImage = false,
    this.driverName = "",
    this.driverPhone = "",
    this.driverRating = "0.0",
    this.driverEmail = "",
    this.truckNumber = "",
    this.truckType = "",
    this.truckCapacity = "",
    this.licenseNumber = "",
    this.licenseExpiry = "",
  });

  @override
  State<MyAccountDriver> createState() => _MyAccountDriverState();
}

class _MyAccountDriverState extends State<MyAccountDriver> {
  // Firebase instances
  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'truxoodriver',
      );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // State variables
  late String _driverName;
  late String _driverPhone;
  late String _driverEmail;
  late String _driverRating;
  late String _truckNumber;
  late String _truckType;
  late String _truckCapacity;
  late String _licenseNumber;
  late String _licenseExpiry;
  String? _profilePhotoUrl;
  String? _licensePhotoUrl;

  File? _newProfileImage;
  bool _isUsingLocalImage = false;
  bool _isNetworkImage = false;
  bool _isEditingProfile = false;
  bool _isEditingTruck = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _truckNumberController;
  late TextEditingController _truckTypeController;
  late TextEditingController _truckCapacityController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _licenseExpiryController;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);

    // Initialize from widget parameters
    _driverName = widget.driverName;
    _driverPhone = widget.driverPhone;
    _driverEmail = widget.driverEmail;
    _driverRating = widget.driverRating;
    _truckNumber = widget.truckNumber;
    _truckType = widget.truckType;
    _truckCapacity = widget.truckCapacity;
    _licenseNumber = widget.licenseNumber;
    _licenseExpiry = widget.licenseExpiry;
    _profilePhotoUrl = widget.currentProfileImagePath;
    _isUsingLocalImage = widget.isLocalImage;
    _isNetworkImage = widget.isNetworkImage;

    if (widget.currentProfileImagePath != null && widget.isLocalImage) {
      _newProfileImage = File(widget.currentProfileImagePath!);
    }

    // Initialize controllers
    _nameController = TextEditingController(text: _driverName);
    _emailController = TextEditingController(text: _driverEmail);
    _phoneController = TextEditingController(text: _driverPhone);
    _truckNumberController = TextEditingController(text: _truckNumber);
    _truckTypeController = TextEditingController(text: _truckType);
    _truckCapacityController = TextEditingController(text: _truckCapacity);
    _licenseNumberController = TextEditingController(text: _licenseNumber);
    _licenseExpiryController = TextEditingController(text: _licenseExpiry);

    // Load fresh data from Firebase
    _loadDriverData();
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _truckNumberController.dispose();
    _truckTypeController.dispose();
    _truckCapacityController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

  // ========== LOAD DRIVER DATA FROM FIREBASE ==========
  Future<void> _loadDriverData() async {
    try {
      String? uid = _auth.currentUser?.uid;

      if (uid == null) {
        // Try phone-based UID for test mode
        final phone = _driverPhone.replaceAll(RegExp(r'[^\d]'), '');
        uid = 'driver_$phone';
      }

      debugPrint('📱 Loading driver data for UID: $uid');

      final doc = await _firestore.collection('drivers').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _driverName = data['name'] ?? '';
          _driverPhone = _formatPhoneNumber(data['phoneNumber'] ?? '');
          _driverEmail = data['email'] ?? '';
          _driverRating = (data['rating'] ?? 0.0).toString();
          _truckNumber = data['truckNumber'] ?? '';
          _truckType = data['truckType'] ?? '';
          _truckCapacity = data['truckModel'] ?? '';
          _licenseNumber = data['licenseNumber'] ?? '';
          _licenseExpiry = data['licenseExpiry'] ?? '';
          _profilePhotoUrl = data['profilePhotoUrl'];
          _licensePhotoUrl = data['licensePhotoUrl'];

          _isNetworkImage = _profilePhotoUrl != null &&
              (_profilePhotoUrl!.startsWith('http://') ||
                  _profilePhotoUrl!.startsWith('https://'));

          // Update controllers
          _nameController.text = _driverName;
          _emailController.text = _driverEmail;
          _phoneController.text = _driverPhone;
          _truckNumberController.text = _truckNumber;
          _truckTypeController.text = _truckType;
          _truckCapacityController.text = _truckCapacity;
          _licenseNumberController.text = _licenseNumber;
          _licenseExpiryController.text = _licenseExpiry;
        });

        debugPrint('✅ Driver data loaded successfully');
      }
    } catch (e) {
      debugPrint('❌ Error loading driver data: $e');
    }
  }

  String _formatPhoneNumber(String phone) {
    if (phone.startsWith('+91')) {
      return phone.substring(3);
    }
    return phone;
  }

  // ========== UPLOAD IMAGE TO FIREBASE STORAGE ==========
  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      String? uid = _auth.currentUser?.uid;

      if (uid == null) {
        final phone = _driverPhone.replaceAll(RegExp(r'[^\d]'), '');
        uid = 'driver_$phone';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'drivers/$uid/profile_photo/profile_$timestamp.jpg';

      debugPrint('⬆️ Uploading profile image to: $storagePath');

      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Profile image uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile image: $e');
      return null;
    }
  }

  // ========== SAVE PROFILE CHANGES TO FIREBASE ==========
  Future<void> _saveProfileChanges() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      String? uid = _auth.currentUser?.uid;

      if (uid == null) {
        final phone = _driverPhone.replaceAll(RegExp(r'[^\d]'), '');
        uid = 'driver_$phone';
      }

      Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': '+91${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Upload new profile image if selected
      if (_newProfileImage != null) {
        final imageUrl = await _uploadProfileImage(_newProfileImage!);
        if (imageUrl != null) {
          updates['profilePhotoUrl'] = imageUrl;
          _profilePhotoUrl = imageUrl;
        }
      }

      // Update Firestore
      await _firestore.collection('drivers').doc(uid).update(updates);

      debugPrint('✅ Profile updated successfully');

      setState(() {
        _isEditingProfile = false;
        _isSaving = false;
        _driverName = _nameController.text.trim();
        _driverEmail = _emailController.text.trim();
        _driverPhone = _phoneController.text.trim();
      });

      _showSuccessSnackBar('Profile updated successfully');

      // Return updated data to home page
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.of(context).pop({
            'selectedIndex': 0,
            'updatedProfile': true,
            'driverName': _driverName,
            'driverPhone': _driverPhone,
            'driverEmail': _driverEmail,
            'profileImagePath': _newProfileImage?.path ?? _profilePhotoUrl,
            'isNetworkImage': _newProfileImage == null && _isNetworkImage,
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to update profile: $e');
    }
  }

  // ========== SAVE TRUCK CHANGES TO FIREBASE ==========
  Future<void> _saveTruckChanges() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      String? uid = _auth.currentUser?.uid;

      if (uid == null) {
        final phone = _driverPhone.replaceAll(RegExp(r'[^\d]'), '');
        uid = 'driver_$phone';
      }

      Map<String, dynamic> updates = {
        'truckNumber': _truckNumberController.text.trim().toUpperCase(),
        'truckType': _truckTypeController.text.trim(),
        'truckModel': _truckCapacityController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('drivers').doc(uid).update(updates);

      debugPrint('✅ Truck details updated successfully');

      setState(() {
        _isEditingTruck = false;
        _isSaving = false;
        _truckNumber = _truckNumberController.text.trim().toUpperCase();
        _truckType = _truckTypeController.text.trim();
        _truckCapacity = _truckCapacityController.text.trim();
      });

      _showSuccessSnackBar('Truck details updated successfully');

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.of(context).pop({
            'selectedIndex': 0,
            'updatedProfile': true,
            'truckNumber': _truckNumber,
            'truckType': _truckType,
            'truckCapacity': _truckCapacity,
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Error saving truck details: $e');
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to update truck details: $e');
    }
  }

  // ========== DELETE ACCOUNT FROM FIREBASE ==========
  Future<void> _deleteAccount() async {
    if (_isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      String? uid = _auth.currentUser?.uid;

      if (uid == null) {
        final phone = _driverPhone.replaceAll(RegExp(r'[^\d]'), '');
        uid = 'driver_$phone';
      }

      debugPrint('🗑️ Deleting account for UID: $uid');

      // Delete profile images from Storage
      try {
        final storageRef = _storage.ref().child('drivers/$uid');
        final listResult = await storageRef.listAll();

        for (var prefix in listResult.prefixes) {
          final subListResult = await prefix.listAll();
          for (var item in subListResult.items) {
            await item.delete();
            debugPrint('🗑️ Deleted: ${item.fullPath}');
          }
        }

        for (var item in listResult.items) {
          await item.delete();
          debugPrint('🗑️ Deleted: ${item.fullPath}');
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting storage files: $e');
      }

      // Delete driver document from Firestore
      await _firestore.collection('drivers').doc(uid).delete();
      debugPrint('✅ Driver document deleted');

      // Sign out from Firebase Auth
      try {
        await _auth.signOut();
        debugPrint('✅ Signed out');
      } catch (e) {
        debugPrint('⚠️ Error signing out: $e');
      }

      _showSuccessSnackBar('Account deleted successfully');

      // Navigate to onboarding
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const OnboardingPage()),
            (Route<dynamic> route) => false,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      setState(() => _isDeleting = false);
      _showErrorSnackBar('Failed to delete account: $e');
    }
  }

  // ========== PICK IMAGE ==========
  Future<void> _pickImage() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _newProfileImage = File(image.path);
          _isUsingLocalImage = true;
          _isNetworkImage = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }

  // ========== NAVIGATION ==========
  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_isEditingProfile || _isEditingTruck) {
      _showUnsavedChangesDialog();
      return true;
    }
    _navigateToHome();
    return true;
  }

  void _navigateToHome() {
    if (_isEditingProfile || _isEditingTruck) {
      _showUnsavedChangesDialog();
    } else {
      Navigator.of(context).pop({
        'selectedIndex': 0,
        'updatedProfile': false,
      });
    }
  }

  Future<void> _showUnsavedChangesDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content:
              const Text('You have unsaved changes. What would you like to do?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop({
                  'selectedIndex': 0,
                  'updatedProfile': false,
                });
              },
            ),
            TextButton(
              child: const Text('Save', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (_isEditingProfile) _saveProfileChanges();
                if (_isEditingTruck) _saveTruckChanges();
              },
            ),
          ],
        );
      },
    );
  }

  // ========== SNACKBARS ==========
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ========== BUILD PROFILE IMAGE ==========
  Widget _buildProfileImageWidget(double size) {
    if (_newProfileImage != null) {
      return Image.file(
        _newProfileImage!,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      if (_profilePhotoUrl!.startsWith('http')) {
        return Image.network(
          _profilePhotoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              color: Colors.grey[300],
              child: Icon(Icons.person, size: size * 0.5, color: Colors.grey[600]),
            );
          },
        );
      }
    }

    // Default placeholder
    return Container(
      width: size,
      height: size,
      color: Colors.grey[300],
      child: Icon(Icons.person, size: size * 0.5, color: Colors.grey[600]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Account',
          style: TextStyle(
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateToHome,
        ),
      ),
      body: _isDeleting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting account...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Information Card
                    _buildProfileCard(isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24 : 16),

                    // Truck Details Card
                    _buildTruckCard(isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24 : 16),

                    // License Details Card
                    _buildLicenseCard(isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24 : 16),

                    // Account Actions Card
                    _buildAccountActionsCard(isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24 : 16),

                    // App Version
                    Center(
                      child: Text(
                        'App Version: 1.0.0',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isLargeScreen ? 14 : 12,
                        ),
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 24 : 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _isSaving && _isEditingProfile
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          _isEditingProfile ? Icons.save : Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          if (_isEditingProfile) {
                            _saveProfileChanges();
                          } else {
                            setState(() => _isEditingProfile = true);
                          }
                        },
                      ),
              ],
            ),
            const SizedBox(height: 16),

            // Profile Image
            Center(
              child: Stack(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: isLargeScreen ? 120 : 100,
                      height: isLargeScreen ? 120 : 100,
                      child: _buildProfileImageWidget(isLargeScreen ? 120 : 100),
                    ),
                  ),
                  if (_isEditingProfile)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Fields
            _buildProfileField(
              'Name',
              _driverName.isNotEmpty ? _driverName : 'Not set',
              _nameController,
              isLargeScreen,
              isEditing: _isEditingProfile,
            ),
            _buildProfileField(
              'Phone',
              _driverPhone.isNotEmpty ? _driverPhone : 'Not set',
              _phoneController,
              isLargeScreen,
              isEditing: _isEditingProfile,
              keyboardType: TextInputType.phone,
            ),
            _buildProfileField(
              'Email',
              _driverEmail.isNotEmpty ? _driverEmail : 'Not set',
              _emailController,
              isLargeScreen,
              isEditing: _isEditingProfile,
              keyboardType: TextInputType.emailAddress,
            ),
            _buildProfileField(
              'Rating',
              '${double.tryParse(_driverRating) ?? 0.0}/5',
              null,
              isLargeScreen,
              isEditing: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTruckCard(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Truck Details',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _isSaving && _isEditingTruck
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          _isEditingTruck ? Icons.save : Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          if (_isEditingTruck) {
                            _saveTruckChanges();
                          } else {
                            setState(() => _isEditingTruck = true);
                          }
                        },
                      ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileField(
              'Truck Number',
              _truckNumber.isNotEmpty ? _truckNumber : 'Not set',
              _truckNumberController,
              isLargeScreen,
              isEditing: _isEditingTruck,
            ),
            _buildProfileField(
              'Truck Type',
              _truckType.isNotEmpty ? _truckType : 'Not set',
              _truckTypeController,
              isLargeScreen,
              isEditing: _isEditingTruck,
            ),
            _buildProfileField(
              'Model/Capacity',
              _truckCapacity.isNotEmpty ? _truckCapacity : 'Not set',
              _truckCapacityController,
              isLargeScreen,
              isEditing: _isEditingTruck,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseCard(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'License Details',
              style: TextStyle(
                fontSize: isLargeScreen ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileField(
              'License Number',
              _licenseNumber.isNotEmpty ? _licenseNumber : 'Not set',
              _licenseNumberController,
              isLargeScreen,
              isEditing: false,
            ),
            _buildProfileField(
              'Expiry Date',
              _licenseExpiry.isNotEmpty ? _licenseExpiry : 'Not set',
              _licenseExpiryController,
              isLargeScreen,
              isEditing: false,
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_licensePhotoUrl != null && _licensePhotoUrl!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LicenseImageScreen(imageUrl: _licensePhotoUrl!),
                      ),
                    );
                  } else {
                    _showErrorSnackBar('No license image available');
                  }
                },
                icon: const Icon(Icons.remove_red_eye),
                label: const Text('View License'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 24 : 16,
                    vertical: isLargeScreen ? 12 : 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard(bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Actions',
              style: TextStyle(
                fontSize: isLargeScreen ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.green),
              title: const Text('Contact Support'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // TODO: Implement contact support
                _showSuccessSnackBar('Contact Support - Coming Soon');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Logout'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showLogoutConfirmationDialog(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showDeleteAccountConfirmationDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    String value,
    TextEditingController? controller,
    bool isLargeScreen, {
    bool isEditing = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          if (isEditing && controller != null)
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLargeScreen ? 16 : 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isLargeScreen ? 16 : 12,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Text(
                value,
                style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  await _auth.signOut();
                } catch (e) {
                  debugPrint('Error signing out: $e');
                }

                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const OnboardingPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteAccountConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account?\n\n'
            '⚠️ This action cannot be undone!\n\n'
            'All your data including:\n'
            '• Profile information\n'
            '• Truck details\n'
            '• Photos\n'
            '• Ride history\n\n'
            'will be permanently deleted.',
            style: TextStyle(height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child:
                  const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }
}