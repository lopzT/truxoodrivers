// lib/driver_sign_up_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'services/driver_data_service.dart';
import 'driver_side_home.dart';

class RegistrationConstants {
  static const double largeScreenBreakpoint = 600;
  static const double horizontalPadding = 16.0;
  static const double verticalSpacing = 16.0;
  static const double sectionSpacing = 24.0;
  static const double imagePickerHeight = 120.0;
  static const double buttonHeight = 50.0;
}

class RegistrationValidator {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your mobile number';
    }
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 10) {
      return 'Please enter a valid 10-digit number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digitsOnly)) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  static String? validateLicenseNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter license number';
    }
    if (value.length < 8) {
      return 'License number must be at least 8 characters';
    }
    return null;
  }

  static String? validateTruckNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter truck number';
    }
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(value)) {
      return 'Invalid truck number format (e.g., OD02AB1234)';
    }
    return null;
  }
}

class DriverRegistrationPage extends StatefulWidget {
  final String? phoneNumber;
  
  const DriverRegistrationPage({
    Key? key,
    this.phoneNumber,
  }) : super(key: key);

  @override
  State<DriverRegistrationPage> createState() => _DriverRegistrationPageState();
}

class _DriverRegistrationPageState extends State<DriverRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Personal Information Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Vehicle Details Controllers
  final TextEditingController _truckTypeController = TextEditingController();
  final TextEditingController _truckModelController = TextEditingController();
  final TextEditingController _truckNumberController = TextEditingController();

  // Professional Details Controllers
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _operationRulesController = TextEditingController();

  // Images
  File? _truckPhoto;
  File? _panAadharPhoto;
  File? _licensePhoto;
  File? _driverPhoto;

  String _transportCompanyType = 'individual';
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone number if provided
    if (widget.phoneNumber != null) {
      _mobileController.text = widget.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    _licenseNumberController.dispose();
    _expiryDateController.dispose();
    _emailController.dispose();
    _truckTypeController.dispose();
    _truckModelController.dispose();
    _truckNumberController.dispose();
    _languageController.dispose();
    _companyNameController.dispose();
    _operationRulesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String imageType) async {
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

      final settings = _getImageSettings(imageType);
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: settings['maxWidth'],
        maxHeight: settings['maxHeight'],
        imageQuality: settings['quality'],
      );

      if (image != null) {
        setState(() {
          switch (imageType) {
            case 'truck':
              _truckPhoto = File(image.path);
              break;
            case 'panAadhar':
              _panAadharPhoto = File(image.path);
              break;
            case 'license':
              _licensePhoto = File(image.path);
              break;
            case 'driver':
              _driverPhoto = File(image.path);
              break;
          }
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: $e');
      }
    }
  }

  Map<String, dynamic> _getImageSettings(String imageType) {
    switch (imageType) {
      case 'panAadhar':
      case 'license':
        return {'maxWidth': 1200.0, 'maxHeight': 1200.0, 'quality': 95};
      case 'driver':
        return {'maxWidth': 800.0, 'maxHeight': 800.0, 'quality': 80};
      case 'truck':
        return {'maxWidth': 1000.0, 'maxHeight': 1000.0, 'quality': 85};
      default:
        return {'maxWidth': 800.0, 'maxHeight': 800.0, 'quality': 80};
    }
  }

  String _getImageHint(String imageType) {
    switch (imageType) {
      case 'panAadhar':
        return 'Tap to upload Aadhar/PAN\n(High quality for verification)';
      case 'license':
        return 'Tap to upload License\n(High quality for verification)';
      case 'driver':
        return 'Tap to upload your Photo';
      case 'truck':
        return 'Tap to upload Truck Photo';
      default:
        return 'Tap to select image';
    }
  }

  Future<void> _selectDate(TextEditingController controller, {bool isExpiry = false}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? now.add(const Duration(days: 365)) : now.subtract(const Duration(days: 365 * 25)),
      firstDate: isExpiry ? now : DateTime(1950),
      lastDate: isExpiry ? now.add(const Duration(days: 365 * 20)) : now.subtract(const Duration(days: 365 * 18)),
    );
    
    if (picked != null) {
      setState(() {
        controller.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildImagePickerSection(
    String title,
    File? image,
    String imageType, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(imageType),
          child: Container(
            height: RegistrationConstants.imagePickerHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: image != null ? Colors.green : Colors.grey,
                width: image != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getImageHint(imageType),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRegistrationForm() async {
  if (!_formKey.currentState!.validate()) {
    _showErrorSnackBar('Please fill all required fields correctly');
    return;
  }

  // Validate required images
  if (_panAadharPhoto == null) {
    _showErrorSnackBar('Please upload your PAN/Aadhar photo');
    return;
  }
  if (_licensePhoto == null) {
    _showErrorSnackBar('Please upload your License photo');
    return;
  }
  if (_driverPhoto == null) {
    _showErrorSnackBar('Please upload your Driver photo');
    return;
  }

  HapticFeedback.lightImpact();
  setState(() {
    _isLoading = true;
    _uploadProgress = 0.0;
  });

  try {
    // CHECK FOR DUPLICATE PHONE NUMBER
    final phoneNumber = _mobileController.text.trim();
    final isAlreadyRegistered = await DriverDataService.isPhoneNumberRegistered(phoneNumber);
    
    if (isAlreadyRegistered) {
      setState(() => _isLoading = false);
      _showDuplicatePhoneDialog(phoneNumber);
      return;
    }

    // Show progress dialog
    _showProgressDialog();

    // Rest of your existing registration code...
    final registrationData = DriverRegistrationData(
      name: _nameController.text.trim(),
      phoneNumber: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      state: _stateController.text.trim(),
      city: _cityController.text.trim(),
      languagesSpoken: _languageController.text.trim(),
      licenseNumber: _licenseNumberController.text.trim(),
      licenseExpiry: _expiryDateController.text.trim(),
      truckType: _truckTypeController.text.trim(),
      truckModel: _truckModelController.text.trim(),
      truckNumber: _truckNumberController.text.trim().toUpperCase(),
      associationType: _transportCompanyType,
      companyName: _transportCompanyType == 'company' 
          ? _companyNameController.text.trim() 
          : null,
      operationRules: _operationRulesController.text.trim(),
      driverPhoto: _driverPhoto,
      licensePhoto: _licensePhoto,
      panAadharPhoto: _panAadharPhoto,
      truckPhoto: _truckPhoto,
    );

    // Register driver
    final result = await DriverDataService.registerDriver(data: registrationData);

    // Close progress dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSuccessSnackBar('Registration successful!');

        // Navigate to home
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DriverSideHome()),
            (route) => false,
          );
        }
      } else {
        _showErrorSnackBar(result['error'] ?? 'Registration failed');
      }
    }
  } catch (e) {
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Registration failed: $e');
    }
  }
}

void _showDuplicatePhoneDialog(String phoneNumber) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Already Registered'),
      content: Text(
        'Phone number +91 $phoneNumber is already registered.\n\nPlease login instead.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
          ),
          child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Uploading documents...'),
            const SizedBox(height: 8),
            Text(
              'Please wait while we process your registration',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text("Driver Registration"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RegistrationConstants.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.phoneNumber != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phone verified: +91 ${widget.phoneNumber}',
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // ===== PERSONAL INFORMATION SECTION =====
              _buildSectionHeader('Personal Information'),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              _buildImagePickerSection(
                'Your Photo',
                _driverPhoto,
                'driver',
                isRequired: true,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Full Name *'),
                validator: RegistrationValidator.validateName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _mobileController,
                decoration: _buildInputDecoration('Mobile Number *'),
                keyboardType: TextInputType.phone,
                enabled: widget.phoneNumber == null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MobileNumberFormatter(),
                ],
                validator: RegistrationValidator.validateMobile,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: _buildInputDecoration('State *'),
                      validator: (value) =>
                          RegistrationValidator.validateRequired(value, 'state'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: RegistrationConstants.verticalSpacing),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: _buildInputDecoration('City *'),
                      validator: (value) =>
                          RegistrationValidator.validateRequired(value, 'city'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _dobController,
                decoration: _buildInputDecoration(
                  'Date of Birth *',
                  suffixIcon: Icons.calendar_today,
                ),
                readOnly: true,
                onTap: () => _selectDate(_dobController),
                validator: (value) =>
                    RegistrationValidator.validateRequired(value, 'date of birth'),
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration('Email (Optional)'),
                keyboardType: TextInputType.emailAddress,
                validator: RegistrationValidator.validateEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: RegistrationConstants.sectionSpacing),

              // ===== LICENSE INFORMATION SECTION =====
              _buildSectionHeader('License Information'),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _licenseNumberController,
                decoration: _buildInputDecoration('Driving License Number *'),
                validator: RegistrationValidator.validateLicenseNumber,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _expiryDateController,
                decoration: _buildInputDecoration(
                  'License Expiry Date *',
                  suffixIcon: Icons.calendar_today,
                ),
                readOnly: true,
                onTap: () => _selectDate(_expiryDateController, isExpiry: true),
                validator: (value) =>
                    RegistrationValidator.validateRequired(value, 'expiry date'),
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              _buildImagePickerSection(
                'License Photo',
                _licensePhoto,
                'license',
                isRequired: true,
              ),
              const SizedBox(height: RegistrationConstants.sectionSpacing),
              _buildSectionHeader('Vehicle Details'),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _truckTypeController,
                decoration: _buildInputDecoration('Truck Type *'),
                validator: (value) =>
                    RegistrationValidator.validateRequired(value, 'truck type'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _truckModelController,
                decoration: _buildInputDecoration('Truck Model *'),
                validator: (value) =>
                    RegistrationValidator.validateRequired(value, 'truck model'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _truckNumberController,
                decoration: _buildInputDecoration('Truck Number * (e.g., OD02AB1234)'),
                validator: RegistrationValidator.validateTruckNumber,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              _buildImagePickerSection(
                'Truck Photo',
                _truckPhoto,
                'truck',
                isRequired: false,
              ),
              const SizedBox(height: RegistrationConstants.sectionSpacing),
              _buildSectionHeader('Professional Details'),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _languageController,
                decoration: _buildInputDecoration('Languages Spoken *'),
                validator: (value) =>
                    RegistrationValidator.validateRequired(value, 'languages spoken'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              const Text(
                'Transport Company Association',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              
              Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Individual'),
                    value: 'individual',
                    groupValue: _transportCompanyType,
                    onChanged: (value) {
                      setState(() {
                        _transportCompanyType = value!;
                        _companyNameController.clear();
                      });
                      HapticFeedback.selectionClick();
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Associated with Company'),
                    value: 'company',
                    groupValue: _transportCompanyType,
                    onChanged: (value) {
                      setState(() => _transportCompanyType = value!);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
              
              if (_transportCompanyType == 'company') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _companyNameController,
                  decoration: _buildInputDecoration('Company Name *'),
                  validator: (value) {
                    if (_transportCompanyType == 'company' &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter company name';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
              ],
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              TextFormField(
                controller: _operationRulesController,
                decoration: _buildInputDecoration('Preferred Operation Rules (Optional)'),
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: RegistrationConstants.sectionSpacing),

              // ===== DOCUMENT UPLOADS SECTION =====
              _buildSectionHeader('Identity Document'),
              const SizedBox(height: RegistrationConstants.verticalSpacing),
              
              _buildImagePickerSection(
                'PAN/Aadhar Card Photo',
                _panAadharPhoto,
                'panAadhar',
                isRequired: true,
              ),
              const SizedBox(height: RegistrationConstants.sectionSpacing),

              // ===== SUBMIT BUTTON =====
              SizedBox(
                width: double.infinity,
                height: RegistrationConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRegistrationForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, {IconData? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}

// Text formatters
class _MobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 10) {
      final limitedDigits = digitsOnly.substring(0, 10);
      return TextEditingValue(
        text: _formatMobileNumber(limitedDigits),
        selection: TextSelection.collapsed(offset: _formatMobileNumber(limitedDigits).length),
      );
    }
    final formattedText = _formatMobileNumber(digitsOnly);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatMobileNumber(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 5) return digits;
    return '${digits.substring(0, 5)} ${digits.substring(5)}';
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}