import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'driver_side_home.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  
  const OtpPage({
    super.key, 
    required this.phoneNumber,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with TickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 800);
  static const int _otpLength = 4;
  static const double _largeScreenBreakpoint = 600;
  static const double _smallScreenBreakpoint = 360;
  static const double _inputWidthRatio = 0.8;
  static const double _maxInputWidth = 289.0;
  static const double _paddingRatio = 0.04;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late List<AnimationController> _digitControllers;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _digitAnimations;

  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _startResendTimer();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _digitControllers = List.generate(_otpLength, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
    });

    _digitAnimations = _digitControllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      );
    }).toList();
  }

  void _startAnimations() {
    _fadeController.forward();
    
    for (int i = 0; i < _digitControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 100)), () {
        if (mounted) {
          _digitControllers[i].forward();
        }
      });
    }
  }

  void _startResendTimer() {
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _resetResendTimer() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });
    _startResendTimer();
  }

  void _animateDigitEntry(int index) {
    if (index < _digitControllers.length) {
      _digitControllers[index].forward().then((_) {
        _digitControllers[index].reverse();
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose(); 
    _focusNode.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _resendTimer?.cancel();
    
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }

  Map<String, double> _getResponsiveSizes(double screenWidth, double screenHeight) {
    final isLargeScreen = screenWidth > _largeScreenBreakpoint;
    final isSmallScreen = screenWidth < _smallScreenBreakpoint;
    
    return {
      'headerFontSize': isLargeScreen ? 20.0 : (isSmallScreen ? 14.0 : 16.0),
      'digitFontSize': isLargeScreen ? 28.0 : (isSmallScreen ? 20.0 : 24.0),
      'labelFontSize': isLargeScreen ? 14.0 : (isSmallScreen ? 9.0 : 10.0),
      'buttonFontSize': isLargeScreen ? 18.0 : (isSmallScreen ? 14.0 : 16.0),
      'verticalSpacing': screenHeight * 0.03,
      'inputWidth': (screenWidth * _inputWidthRatio > _maxInputWidth) 
          ? _maxInputWidth 
          : screenWidth * _inputWidthRatio,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final sizes = _getResponsiveSizes(screenWidth, screenHeight);
    
    return Scaffold(
      appBar: _buildAppBar(screenHeight, screenWidth > _largeScreenBreakpoint),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(screenWidth, sizes),
              SizedBox(height: sizes['verticalSpacing']!),
              _buildOtpInput(sizes),
              SizedBox(height: sizes['verticalSpacing']!),
              _buildResendSection(screenWidth, sizes),
              SizedBox(height: screenHeight * 0.03),
              _buildActionButtons(screenWidth, screenHeight, sizes),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(double screenHeight, bool isLargeScreen) {
    return PreferredSize(
      preferredSize: Size.fromHeight(screenHeight * 0.08), 
      child: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back, 
            size: isLargeScreen ? 28 : 24,
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

  Widget _buildHeader(double screenWidth, Map<String, double> sizes) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * _paddingRatio),
      child: Center(
        child: Text(
          'Please Wait. We will auto verify OTP sent to +91 ${widget.phoneNumber}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sizes['headerFontSize'],
            height: 1.4,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpInput(Map<String, double> sizes) {
  final inputWidth = sizes['inputWidth']!;
  final digitBoxWidth = (inputWidth - 30) / _otpLength;
  
  return Center(
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: inputWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_otpLength, (index) {
              return AnimatedBuilder(
                animation: _digitAnimations[index],
                builder: (context, child) {
                  final hasValue = index < _otpController.text.length;
                  final isCurrent = index == _otpController.text.length;
                  
                  return Transform.scale(
                    scale: 1.0 + (_digitAnimations[index].value * 0.1),
                    child: Container(
                      width: digitBoxWidth,
                      height: digitBoxWidth * 1.2,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: hasValue 
                                ? Colors.black 
                                : (isCurrent ? Colors.blue : Colors.grey),
                            width: hasValue || isCurrent ? 2.0 : 1.0,
                          ),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          hasValue ? _otpController.text[index] : '',
                          key: ValueKey('$index-${hasValue ? _otpController.text[index] : ''}'),
                          style: TextStyle(
                            fontSize: sizes['digitFontSize'],
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),

        Positioned.fill(
          child: TextField(
            controller: _otpController,
            focusNode: _focusNode,
            autofocus: true, 
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done, 
            maxLength: _otpLength,
            enableInteractiveSelection: false, 
            showCursor: false, 
            style: const TextStyle(
              color: Colors.transparent,
              fontSize: 1, 
              height: 1, 
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false, 
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_otpLength), 
            ],
            onChanged: (value) {
              setState(() {});
              
              if (value.isNotEmpty) {
                HapticFeedback.selectionClick();
                _animateDigitEntry(value.length - 1);
              }
              
              if (value.length == _otpLength) {
                _focusNode.unfocus(); 
                _verifyOtp();
              }
            },
            onTap: () {
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
              }
            },
          ),
        ),
      ],
    ),
  );
}

  Widget _buildResendSection(double screenWidth, Map<String, double> sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.09),
          child: Text(
            "Didn't receive OTP?",
            style: TextStyle(
              fontSize: sizes['labelFontSize'],
              color: Colors.grey[600],
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _canResend
                ? TextButton(
                    key: const ValueKey('resend'),
                    onPressed: _resendOtp,
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontSize: sizes['labelFontSize'],
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  )
                : Text(
                    key: const ValueKey('countdown'),
                    'Resend OTP in ${_resendCountdown}s',
                    style: TextStyle(
                      fontSize: sizes['labelFontSize'],
                      color: Colors.grey[600],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(double screenWidth, double screenHeight, Map<String, double> sizes) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: TextButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: TextButton.styleFrom(
            backgroundColor: _isLoading ? Colors.grey[300] : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: Size(screenWidth * 0.8, screenHeight * 0.06),
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.015,
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                )
              : Text(
                  'Verify OTP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sizes['buttonFontSize'],
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  void _resendOtp() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (mounted) {
      setState(() => _isLoading = false);
      _resetResendTimer();
      _scaleController.forward();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP sent successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < _otpLength) {
      _showErrorSnackBar('Please enter a valid ${_otpLength}-digit OTP');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.mediumImpact();
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DriverSideHome(),
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
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Verification failed. Please try again.');
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
    ),
  );
}
}
//ready