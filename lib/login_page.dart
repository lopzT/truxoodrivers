import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'otp_page.dart';
import 'driver_sign_up_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class Config {
  static const bool isDev = kDebugMode;
  static const String devBaseUrl = 'http://10.0.2.2:3000';
  static const String productionBaseUrl = 'https://api.truxoo.com';
  
  static String get baseUrl => isDev ? devBaseUrl : productionBaseUrl;
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with TickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 800);
  static const Duration _staggerDelay = Duration(milliseconds: 200);
  static const Duration _transitionDuration = Duration(milliseconds: 500);
  static const double _largeScreenBreakpoint = 600;
  static const double _contentWidthRatio = 0.8;
  static const double _horizontalPaddingRatio = 0.05;
  static const int _phoneNumberLength = 10;
  static const String _countryCode = '+91';

  late final TextEditingController _contactNumberController;
  late final FocusNode _phoneFocusNode;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _buttonController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool _isLoading = false;
  bool _isValidNumber = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _startAnimations();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  void _initializeControllers() {
    _contactNumberController = TextEditingController();
    _phoneFocusNode = FocusNode();
    _contactNumberController.addListener(_validatePhoneNumber);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _buttonScaleAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    );
  }

  void _startAnimations() {
    _fadeController.forward();

    Future.delayed(_staggerDelay, () {
      if (mounted) {
        _slideController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _buttonController.forward();
      }
    });
  }

  void _validatePhoneNumber() {
    final phoneNumber = _contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');
    final isValid = phoneNumber.length == _phoneNumberLength &&
        RegExp(r'^[6-9]\d{9}$').hasMatch(phoneNumber);

    if (_isValidNumber != isValid) {
      setState(() {
        _isValidNumber = isValid;
      });
    }
  }

  @override
  void dispose() {
    _contactNumberController.removeListener(_validatePhoneNumber);
    _contactNumberController.dispose();
    _phoneFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Map<String, double> _getResponsiveSizes(double screenWidth, double screenHeight) {
    final isLargeScreen = screenWidth > _largeScreenBreakpoint;
    return {
      'titleFontSize': isLargeScreen ? 42.0 : 36.0,
      'subtitleFontSize': isLargeScreen ? 14.0 : 12.0,
      'inputFontSize': isLargeScreen ? 18.0 : 16.0,
      'buttonFontSize': isLargeScreen ? 18.0 : 16.0,
      'verticalSpacing': isLargeScreen ? screenHeight * 0.06 : screenHeight * 0.04,
      'buttonSpacing': isLargeScreen ? screenHeight * 0.07 : screenHeight * 0.04,
      'appBarHeight': isLargeScreen ? 60.0 : 50.0,
      'buttonHeight': isLargeScreen ? 60.0 : 47.0,
    };
  }

  Future<bool> sendPhoneNumberToBackend(String phoneNumber) async {
    const int maxRetries = 3;
    const Duration baseDelay = Duration(seconds: 1);
    
    final url = Uri.parse('${Config.baseUrl}/api/send-otp');
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint('Sending OTP request (attempt ${attempt + 1}/$maxRetries) to: $url');
        
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'TruxooDriver/1.0',
          },
          body: jsonEncode({'phone': phoneNumber}),
        ).timeout(const Duration(seconds: 15));
        
        debugPrint('Response status: ${response.statusCode}, body: ${response.body}');
        
        if (response.statusCode == 200) {
          return true;
        } else if (response.statusCode == 429) {
          _showErrorSnackBar('Too many requests. Please wait a moment.');
          return false;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          _showErrorSnackBar('Invalid phone number or request.');
          return false;
        } else if (response.statusCode >= 500) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(seconds: baseDelay.inSeconds * (attempt + 1)));
            continue;
          } else {
            _showErrorSnackBar('Server error. Please try again later.');
            return false;
          }
        }
        
      } on SocketException catch (e) {
        debugPrint('Network error (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: baseDelay.inSeconds * (attempt + 1)));
          continue;
        } else {
          _showErrorSnackBar('No internet connection. Please check your network.');
          return false;
        }
      } on TimeoutException catch (e) {
        debugPrint('Timeout error (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: baseDelay.inSeconds * (attempt + 1)));
          continue;
        } else {
          _showErrorSnackBar('Request timeout. Please try again.');
          return false;
        }
      } catch (e) {
        debugPrint('Unexpected error (attempt ${attempt + 1}): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: baseDelay.inSeconds * (attempt + 1)));
          continue;
        } else {
          _showErrorSnackBar('Failed to send OTP. Please try again.');
          return false;
        }
      }
    }
    
    return false;
  }

  void _handleNext() async {
    final contact = _contactNumberController.text.replaceAll(RegExp(r'[^\d]'), '');

    if (!_isValidNumber || contact.length != _phoneNumberLength) {
      _showErrorSnackBar('Please enter a valid 10-digit phone number');
      return;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(contact)) {
      _showErrorSnackBar('Please enter a valid Indian mobile number');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final success = await sendPhoneNumberToBackend(contact);

    setState(() => _isLoading = false);

    if (!success) {
      return;
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OtpPage(phoneNumber: contact),
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
          transitionDuration: _transitionDuration,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final sizes = _getResponsiveSizes(screenWidth, screenHeight);

    return Scaffold(
      appBar: _buildAppBar(sizes),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(screenWidth, screenHeight, sizes),
              SizedBox(height: sizes['verticalSpacing']!),
              _buildPhoneInput(screenWidth, sizes),
              SizedBox(height: sizes['buttonSpacing']!),
              _buildNextButton(screenWidth, sizes),
              SizedBox(height: screenHeight * 0.03),
              _buildSignUpLink(sizes),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Map<String, double> sizes) {
    return PreferredSize(
      preferredSize: Size.fromHeight(sizes['appBarHeight']!),
      child: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: sizes['appBarHeight']! > 55 ? 28 : 24,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight, Map<String, double> sizes) {
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.only(
          left: screenWidth * _horizontalPaddingRatio,
          right: screenWidth * _horizontalPaddingRatio,
          top: screenHeight * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Text(
                      'Enter Phone Number for verification',
                      style: TextStyle(
                        fontSize: sizes['titleFontSize'],
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: screenHeight * 0.01),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 15 * (1 - value)),
                    child: Text(
                      'This number will be used for all transport related communication. Upon entering you shall receive a SMS with code for verification', 
                      style: TextStyle(
                        fontSize: sizes['subtitleFontSize'],
                        color: const Color(0xFF5F5353),
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput(double screenWidth, Map<String, double> sizes) {
    return SlideTransition(
      position: _slideAnimation,
      child: SizedBox(
        width: screenWidth * _contentWidthRatio,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (value * 0.05),
              child: Opacity(
                opacity: value,
                child: TextField(
                  controller: _contactNumberController,
                  focusNode: _phoneFocusNode,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.phone,
                  maxLength: 11, 
                  style: TextStyle(
                    fontSize: sizes['inputFontSize'],
                    fontWeight: FontWeight.w500,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _PhoneNumberFormatter(),
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _isValidNumber ? Colors.green : Colors.blue,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _isValidNumber ? Colors.green[300]! : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                    prefixText: '$_countryCode ',
                    prefixStyle: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: sizes['inputFontSize'],
                    ),
                    hintText: 'Enter your phone number',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: sizes['inputFontSize']! > 17 ? 16 : 12,
                      horizontal: 16,
                    ),
                    suffixIcon: _contactNumberController.text.isNotEmpty
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _isValidNumber ? Icons.check_circle : Icons.error,
                              color: _isValidNumber ? Colors.green : Colors.red,
                              key: ValueKey(_isValidNumber),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      HapticFeedback.selectionClick();
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNextButton(double screenWidth, Map<String, double> sizes) {
    return ScaleTransition(
      scale: _buttonScaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: TextButton(
          onPressed: _isLoading ? null : _handleNext,
          style: TextButton.styleFrom(
            backgroundColor: _isValidNumber 
                ? Colors.black 
                : Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: Size(
              screenWidth * _contentWidthRatio, 
              sizes['buttonHeight']!,
            ),
            padding: EdgeInsets.symmetric(
              vertical: sizes['buttonHeight']! > 55 ? 15 : 10,
            ),
            elevation: _isValidNumber ? 2 : 0,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isValidNumber ? Colors.white : Colors.grey[600]!,
                    ),
                  ),
                )
              : Text(
                  'Send OTP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isValidNumber ? Colors.white : Colors.grey[600],
                    fontSize: sizes['buttonFontSize'],
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(Map<String, double> sizes) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't already have an account? ",
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF5F5353),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => 
                            const DriverRegistrationPage(),
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
                        transitionDuration: _transitionDuration,
                      ),
                    );
                  },
                  child: Text(
                    "Sign up here",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 10) {
      final limitedDigits = digitsOnly.substring(0, 10);
      final formattedText = _formatPhoneNumber(limitedDigits);
      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    }

    final formattedText = _formatPhoneNumber(digitsOnly);

    int cursorPosition = formattedText.length;
    if (newValue.selection.baseOffset < newValue.text.length) {
      final digitsBefore = newValue.text
          .substring(0, newValue.selection.baseOffset)
          .replaceAll(RegExp(r'[^\d]'), '')
          .length;

      if (digitsBefore <= 5) {
        cursorPosition = digitsBefore;
      } else {
        cursorPosition = digitsBefore + 1; 
      }
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(
        offset: cursorPosition.clamp(0, formattedText.length),
      ),
    );
  }

  String _formatPhoneNumber(String digits) {
    if (digits.length <= 5) {
      return digits;
    }

    final firstPart = digits.substring(0, 5);
    final secondPart = digits.substring(5);
    return '$firstPart $secondPart';
  }
}