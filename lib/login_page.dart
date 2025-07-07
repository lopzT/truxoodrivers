import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_page.dart';

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

    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        setState(() => _isLoading = false);
        
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to send OTP. Please try again.');
      }
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
//ready