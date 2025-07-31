import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
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
  bool _isLoading = false;

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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing image...\nPlease wait'),
            ],
          ),
        ),
      );
      
      Map<String, dynamic> imageSettings = _getImageSettings(imageType);
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: imageSettings['maxWidth'],
        maxHeight: imageSettings['maxHeight'],
        imageQuality: imageSettings['quality'],
      );
      
      Navigator.pop(context); 
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
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }


  Map<String, dynamic> _getImageSettings(String imageType) {
    switch (imageType) {
      case 'panAadhar':
      case 'license':

        return {
          'maxWidth': 1200.0,
          'maxHeight': 1200.0,
          'quality': 95,
        };
      
      case 'driver':
        return {
          'maxWidth': 800.0,
          'maxHeight': 800.0,
          'quality': 70,
        };
      
      case 'truck':
        return {
          'maxWidth': 600.0,
          'maxHeight': 600.0,
          'quality': 60,
        };
      
      default:
        return {
          'maxWidth': 800.0,
          'maxHeight': 800.0,
          'quality': 70,
        };
    }
  }

  String _getImageHint(String imageType) {
    switch (imageType) {
      case 'panAadhar':
        return 'Tap to select Aadhar/PAN\n(High quality for verification)';
      case 'license':
        return 'Tap to select License\n(High quality for verification)';
      case 'driver':
        return 'Tap to select Driver Photo';
      case 'truck':
        return 'Tap to select Truck Photo\n(Optional)';
      default:
        return 'Tap to select image';
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
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedSwitcher(
                          duration: Duration(milliseconds: 200),
                          child: frame != null 
                            ? child 
                            : Container(
                                color: Colors.grey[200],
                                child: Center(child: CircularProgressIndicator()),
                              ),
                        );
                      },
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        _getImageHint(imageType),
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> submitRegistrationForm() async {
    setState(() => _isLoading = true);

    final url = Uri.parse('http://localhost:3000/api/driver/register');

    try {
      final request = http.MultipartRequest('POST', url);

      request.fields['name'] = _nameController.text;
      request.fields['mobile'] = _mobileController.text;
      request.fields['state'] = _stateController.text;
      request.fields['city'] = _cityController.text;
      request.fields['dob'] = _dobController.text;
      request.fields['license_number'] = _licenseNumberController.text;
      request.fields['expiry_date'] = _expiryDateController.text;
      request.fields['email'] = _emailController.text;
      request.fields['truck_type'] = _truckTypeController.text;
      request.fields['truck_model'] = _truckModelController.text;
      request.fields['truck_number'] = _truckNumberController.text;
      request.fields['language'] = _languageController.text;
      request.fields['transport_type'] = _transportCompanyType;
      request.fields['company_name'] = _companyNameController.text;
      request.fields['operation_rules'] = _operationRulesController.text;

      if (_truckPhoto != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'truck_photo', _truckPhoto!.path,
        ));
      }
      if (_panAadharPhoto != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'pan_aadhar_photo', _panAadharPhoto!.path,
        ));
      }
      if (_licensePhoto != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'license_photo', _licensePhoto!.path,
        ));
      }
      if (_driverPhoto != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'driver_photo', _driverPhoto!.path,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration submitted successfully')),
        );

        final phoneNumber = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpPage(phoneNumber: phoneNumber)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting form: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Driver Registration"),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Your Name *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mobileController,
                    decoration: const InputDecoration(labelText: 'Mobile Number *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (value) => value == null || value.length != 10 ? 'Enter valid 10-digit number' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(labelText: 'State *', border: OutlineInputBorder()),
                          validator: (value) => value == null || value.isEmpty ? 'Please enter state' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City *', border: OutlineInputBorder()),
                          validator: (value) => value == null || value.isEmpty ? 'Please enter city' : null,
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
                    validator: (value) => value == null || value.isEmpty ? 'Please select date of birth' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseNumberController,
                    decoration: const InputDecoration(labelText: 'Driving License Number *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter license number' : null,
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
                    validator: (value) => value == null || value.isEmpty ? 'Please select expiry date' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email (Optional)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),

                  const Text('Vehicle Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _truckTypeController,
                    decoration: const InputDecoration(labelText: 'Truck Type *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter truck type' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _truckModelController,
                    decoration: const InputDecoration(labelText: 'Truck Model *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter truck model' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _truckNumberController,
                    decoration: const InputDecoration(labelText: 'Truck Number *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter truck number' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildImagePickerSection('Truck Photo (optional)', _truckPhoto, 'truck'),
                  const SizedBox(height: 24),

                  const Text('Professional Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _languageController,
                    decoration: const InputDecoration(labelText: 'Language Spoken *', border: OutlineInputBorder()),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter languages spoken' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Transport Company Association', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                      decoration: const InputDecoration(labelText: 'Company Name *', border: OutlineInputBorder()),
                      validator: (value) {
                        if (_transportCompanyType == 'company' && (value == null || value.isEmpty)) {
                          return 'Please enter company name';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _operationRulesController,
                    decoration: const InputDecoration(labelText: 'Preferred Operation Rules (Optional)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  const Text('Document Uploads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildImagePickerSection('PAN/Aadhar Card Photo *', _panAadharPhoto, 'panAadhar'),
                  const SizedBox(height: 16),
                  _buildImagePickerSection('License Photo *', _licensePhoto, 'license'),
                  const SizedBox(height: 16),
                  _buildImagePickerSection('Driver Photo *', _driverPhoto, 'driver'),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
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
                          await submitRegistrationForm();
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