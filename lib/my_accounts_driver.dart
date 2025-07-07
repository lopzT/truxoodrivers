import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';

class MyAccountDriver extends StatefulWidget {
  final String? currentProfileImagePath;
  final bool isLocalImage;
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
    this.driverName = "Soumesh Padhaya",
    this.driverPhone = "8875658758",
    this.driverRating = "4.4",
    this.driverEmail = "soush34@gmail.com",
    this.truckNumber = "OD02AB1234",
    this.truckType = "Open Truck",
    this.truckCapacity = "10 Tons",
    this.licenseNumber = "DL-0420110012345", 
    this.licenseExpiry = "10/05/2026",
  });

  @override
  State<MyAccountDriver> createState() => _MyAccountDriverState();
}

class _MyAccountDriverState extends State<MyAccountDriver> {
  late String _driverName;
  late String _driverPhone;
  late String _driverEmail;
  late String _driverRating;
  late String _truckNumber;
  late String _truckType;
  late String _truckCapacity;
  late String _licenseNumber;
  late String _licenseExpiry;
  
  final String _profilePicture = 'assets/driver_image.webp';
  File? _newProfileImage;
  bool _isUsingLocalImage = false;
  bool _isEditingProfile = false;
  bool _isEditingTruck = false;

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
  
  _driverName = widget.driverName;
  _driverPhone = widget.driverPhone;
  _driverEmail = widget.driverEmail;
  _driverRating = widget.driverRating;
  _truckNumber = widget.truckNumber;
  _truckType = widget.truckType;
  _truckCapacity = widget.truckCapacity;
  _licenseNumber = widget.licenseNumber;  
  _licenseExpiry = widget.licenseExpiry; 
  _isUsingLocalImage = widget.isLocalImage;

  if (widget.currentProfileImagePath != null && widget.isLocalImage) {
    _newProfileImage = File(widget.currentProfileImagePath!);
  }
  _nameController = TextEditingController(text: _driverName);
  _emailController = TextEditingController(text: _driverEmail);
  _phoneController = TextEditingController(text: _driverPhone);
  _truckNumberController = TextEditingController(text: _truckNumber);
  _truckTypeController = TextEditingController(text: _truckType);
  _truckCapacityController = TextEditingController(text: _truckCapacity);
  _licenseNumberController = TextEditingController(text: _licenseNumber);
  _licenseExpiryController = TextEditingController(text: _licenseExpiry);
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

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_isEditingProfile || _isEditingTruck) {
      _showUnsavedChangesDialog();
      return true;
    }
    _navigateToHome();
    return true;
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }
  void _saveProfileChanges() {
  setState(() {
    _isEditingProfile = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Profile updated successfully'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 1), 
    ),
  );

  Future.delayed(const Duration(milliseconds: 1200), () {
    if (mounted) {
      Navigator.of(context).pop({
        'selectedIndex': 0,
        'updatedProfile': true,
        'driverName': _nameController.text,
        'driverPhone': _phoneController.text,
        'driverEmail': _emailController.text,
        'profileImagePath': _newProfileImage?.path,
      });
    }
  });
}

void _saveTruckChanges() {
  setState(() {
    _isEditingTruck = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Truck details updated successfully'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 1), 
    ),
  );

  Future.delayed(const Duration(milliseconds: 1200), () {
    if (mounted) {
      Navigator.of(context).pop({
        'selectedIndex': 0,
        'updatedProfile': true,
        'truckNumber': _truckNumberController.text,
        'truckType': _truckTypeController.text,
        'truckCapacity': _truckCapacityController.text,
      });
    }
  });
}
  void _navigateToHome() {
  if (_isEditingProfile || _isEditingTruck) {
    _showUnsavedChangesDialog();
  } else {
    Navigator.of(context).pop({
      'selectedIndex': 0,
      'updatedProfile': true,
      'driverName': _nameController.text,
      'driverPhone': _phoneController.text,
      'driverEmail': _emailController.text,
      'truckNumber': _truckNumberController.text,
      'profileImagePath': _newProfileImage?.path,
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
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(dialogContext).pop();  
            },
          ),
          TextButton(
            child: const Text('Discard'),
            onPressed: () {
              Navigator.of(dialogContext).pop(); 
              Navigator.of(context).pop({
                'selectedIndex': 0,
                'updatedProfile': false, 
              });
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              Navigator.of(dialogContext).pop();  // First close the dialog
              if (_isEditingProfile) _saveProfileChanges();
              if (_isEditingTruck) _saveTruckChanges();
              // Then navigate back with updates
              Navigator.of(context).pop({
                'selectedIndex': 0,
                'updatedProfile': true,
                'driverName': _nameController.text,
                'driverPhone': _phoneController.text,
                'driverEmail': _emailController.text,
                'truckNumber': _truckNumberController.text,
                'profileImagePath': _newProfileImage?.path,
              });
            },
          ),
        ],
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                          IconButton(
                            icon: Icon(
                              _isEditingProfile ? Icons.save : Icons.edit,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              if (_isEditingProfile) {
                                _saveProfileChanges();
                              } else {
                                setState(() {
                                  _isEditingProfile = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: isLargeScreen ? 60 : 50,
                              backgroundImage: _newProfileImage != null
                              ? FileImage(_newProfileImage!)
                              : widget.isLocalImage && widget.currentProfileImagePath != null
                              ? FileImage(File(widget.currentProfileImagePath!))
                              : AssetImage(_profilePicture) as ImageProvider,
                            ),
                            if (_isEditingProfile)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                    ),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProfileField(
                        'Name',
                        _driverName,
                        _nameController,
                        isLargeScreen,
                        isEditing: _isEditingProfile,
                      ),
                      _buildProfileField(
                        'Phone',
                        _driverPhone,
                        _phoneController,
                        isLargeScreen,
                        isEditing: _isEditingProfile,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildProfileField(
                        'Email',
                        _driverEmail,
                        _emailController,
                        isLargeScreen,
                        isEditing: _isEditingProfile,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _buildProfileField(
                        'Rating',
                        '$_driverRating/5',
                        null,
                        isLargeScreen,
                        isEditing: false,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
              
              // Truck Details Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                          IconButton(
                            icon: Icon(
                              _isEditingTruck ? Icons.save : Icons.edit,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              if (_isEditingTruck) {
                                _saveTruckChanges();
                              } else {
                                setState(() {
                                  _isEditingTruck = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildProfileField(
                        'Truck Number',
                        _truckNumber,
                        _truckNumberController,
                        isLargeScreen,
                        isEditing: _isEditingTruck,
                      ),
                      _buildProfileField(
                        'Truck Type',
                        _truckType,
                        _truckTypeController,
                        isLargeScreen,
                        isEditing: _isEditingTruck,
                      ),
                      _buildProfileField(
                        'Capacity',
                        _truckCapacity,
                        _truckCapacityController,
                        isLargeScreen,
                        isEditing: _isEditingTruck,
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
              
              // License Details Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                        _licenseNumber,
                        _licenseNumberController,
                        isLargeScreen,
                        isEditing: false,
                      ),
                      _buildProfileField(
                        'Expiry Date',
                        _licenseExpiry,
                        _licenseExpiryController,
                        isLargeScreen,
                        isEditing: false,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to license image screen
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
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
              
              // Account Actions Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                        leading: const Icon(Icons.lock, color: Colors.blue),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Navigate to change password screen
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.support_agent, color: Colors.green),
                        title: const Text('Contact Support'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Navigate to support screen or launch phone/email
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Logout'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Show logout confirmation dialog
                          _showLogoutConfirmationDialog(context, isLargeScreen);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Delete Account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Show delete account confirmation dialog
                          _showDeleteAccountConfirmationDialog(context, isLargeScreen);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
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
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
              ),
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
                style: TextStyle(
                  fontSize: isLargeScreen ? 16 : 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _showLogoutConfirmationDialog(BuildContext context, bool isLargeScreen) async {
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Perform logout action
                // Navigate to login screen
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', // Replace with your login route
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _showDeleteAccountConfirmationDialog(BuildContext context, bool isLargeScreen) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
            style: TextStyle(height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performAccountDeletion();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _performAccountDeletion() {
    // Here you would call your API to delete the account
    // For now, we'll just show a success message and navigate to login
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Navigate to login screen
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', // Replace with your login route
        (Route<dynamic> route) => false,
      );
    });
  }
}