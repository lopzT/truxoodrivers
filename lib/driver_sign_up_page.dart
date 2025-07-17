import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'otp_page.dart';

class DriverRegistrationPage extends StatefulWidget {
  const DriverRegistrationPage({Key? key}) : super(key: key);

  @override
  State<DriverRegistrationPage> createState() => _DriverRegistrationPageState();
}

class _DriverRegistrationPageState extends State<DriverRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _truckTypeController = TextEditingController();
  final TextEditingController _truckModelController = TextEditingController();
  final TextEditingController _truckNumberController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _operationRulesController = TextEditingController();
  
  File? _truckPhoto;
  File? _panAadharPhoto;
  File? _licensePhoto;
  File? _driverPhoto;
  
  String _transportCompanyType = 'individual';
  
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
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  Widget _buildImagePickerSection(String title, File? image, String imageType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickImage(imageType),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Tap to select image',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (value.length != 10) {
                    return 'Please enter valid 10-digit mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter state';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter city';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_dobController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select date of birth';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _licenseNumberController,
                decoration: const InputDecoration(
                  labelText: 'Driving License Number *',
                  helperText: 'Please Double Check Before Submitting',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter driving license number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Date of Expiry *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(_expiryDateController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select expiry date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Vehicle Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _truckTypeController,
                decoration: const InputDecoration(
                  labelText: 'Truck Type *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter truck type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _truckModelController,
                decoration: const InputDecoration(
                  labelText: 'Truck Model *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter truck model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _truckNumberController,
                decoration: const InputDecoration(
                  labelText: 'Truck Number *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter truck number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              _buildImagePickerSection(
                'Truck Photo (For illustration purposes)',
                _truckPhoto,
                'truck',
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Professional Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: 'Language Spoken *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter languages spoken';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
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
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Associated with Company'),
                    value: 'company',
                    groupValue: _transportCompanyType,
                    onChanged: (value) {
                      setState(() {
                        _transportCompanyType = value!;
                      });
                    },
                  ),
                ],
              ),
              
              if (_transportCompanyType == 'company') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_transportCompanyType == 'company' && 
                        (value == null || value.isEmpty)) {
                      return 'Please enter company name';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _operationRulesController,
                decoration: const InputDecoration(
                  labelText: 'Preferred Operation Rules (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Document Uploads',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              _buildImagePickerSection(
                'PAN/Aadhar Card Photo *',
                _panAadharPhoto,
                'panAadhar',
              ),
              const SizedBox(height: 16),
              
              _buildImagePickerSection(
                'License Photo *',
                _licensePhoto,
                'license',
              ),
              const SizedBox(height: 16),
              
              _buildImagePickerSection(
                'Driver Photo *',
                _driverPhoto,
                'driver',
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (_panAadharPhoto == null || 
                          _licensePhoto == null || 
                          _driverPhoto == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please upload all required documents'),
                          ),
                        );
                        return;
                      }
                      
                      final phoneNumber = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
                      
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => 
                              OtpPage(phoneNumber: phoneNumber),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Registration',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}