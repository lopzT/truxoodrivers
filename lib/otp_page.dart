// lib/otp_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'driver_side_home.dart';
import 'driver_sign_up_page.dart';
import 'services/firebase_auth_service.dart';

class OtpPageConstants {
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Duration scaleAnimationDuration = Duration(milliseconds: 600);
  static const Duration digitAnimationDuration = Duration(milliseconds: 300);
  static const Duration verifyDelay = Duration(milliseconds: 1500);
  static const Duration focusDelay = Duration(milliseconds: 500);
  static const int resendTimeout = 30;
  static const int otpLength = 6;
  static const double largeScreenBreakpoint = 600;
  static const double smallScreenBreakpoint = 360;
  static const double inputWidthRatio = 0.8;
  static const double maxInputWidth = 350.0;
  static const double paddingRatio = 0.04;
  static const double verticalSpacingRatio = 0.03;
}

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final bool isLoginFlow; // Add this
  
  const OtpPage({
    super.key, 
    required this.phoneNumber,
    this.verificationId = '',
    this.isLoginFlow = true, // Default to login flow
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late ValueNotifier<String> _otpNotifier;
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late List<AnimationController> _digitControllers;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _digitAnimations;

  bool _isLoading = false;
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendCountdown = OtpPageConstants.resendTimeout;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _otpNotifier = ValueNotifier(_otpController.text);
    _otpController.addListener(() {
      _otpNotifier.value = _otpController.text;
    });
    
    _initializeAnimations();
    _startAnimations();
    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: OtpPageConstants.animationDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: OtpPageConstants.scaleAnimationDuration,
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

    _digitControllers = List.generate(OtpPageConstants.otpLength, (index) {
      return AnimationController(
        duration: OtpPageConstants.digitAnimationDuration,
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
      Future.delayed(
        Duration(milliseconds: 200 + (i * 100)),
        () {
          if (mounted) {
            _digitControllers[i].forward();
          }
        },
      );
    }
  }

  void _startResendTimer() {
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _resetResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _canResend = false;
      _resendCountdown = OtpPageConstants.resendTimeout;
    });
    _startResendTimer();
  }

  void _animateDigitEntry(int index) {
    if (index < _digitControllers.length) {
      _digitControllers[index].forward().then((_) {
        if (mounted) {
          _digitControllers[index].reverse();
        }
      });
    }
  }

  void _resetAndPlayScaleAnimation() {
    _scaleController.reset();
    if (mounted) {
      _scaleController.forward();
    }
  }

  @override
  void dispose() {
    _otpController.dispose(); 
    _focusNode.dispose();
    _otpNotifier.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _resendTimer?.cancel();
    
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }

  Map<String, double> _getResponsiveSizes(double screenWidth, double screenHeight) {
    final isLargeScreen = screenWidth > OtpPageConstants.largeScreenBreakpoint;
    final isSmallScreen = screenWidth < OtpPageConstants.smallScreenBreakpoint;
    
    return {
      'headerFontSize': isLargeScreen ? 20.0 : (isSmallScreen ? 14.0 : 16.0),
      'digitFontSize': isLargeScreen ? 28.0 : (isSmallScreen ? 20.0 : 24.0),
      'labelFontSize': isLargeScreen ? 14.0 : (isSmallScreen ? 9.0 : 10.0),
      'buttonFontSize': isLargeScreen ? 18.0 : (isSmallScreen ? 14.0 : 16.0),
      'verticalSpacing': screenHeight * OtpPageConstants.verticalSpacingRatio,
      'inputWidth': (screenWidth * OtpPageConstants.inputWidthRatio > OtpPageConstants.maxInputWidth) 
          ? OtpPageConstants.maxInputWidth
          : screenWidth * OtpPageConstants.inputWidthRatio,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final sizes = _getResponsiveSizes(screenWidth, screenHeight);
    final isLargeScreen = screenWidth > OtpPageConstants.largeScreenBreakpoint;
    
    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        appBar: _buildAppBar(screenHeight, isLargeScreen),
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
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_otpController.text.isEmpty) {
      return true;
    }

    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard OTP?'),
        content: const Text(
          'Are you sure you want to go back? You\'ll need to enter OTP again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _resendTimer?.cancel();
              Navigator.pop(context, true);
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    ) ?? false;
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
      padding: EdgeInsets.all(screenWidth * OtpPageConstants.paddingRatio),
      child: Center(
        child: Text(
          'Please enter OTP sent to +91 ${widget.phoneNumber}',
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
    final digitBoxWidth = (inputWidth - 30) / OtpPageConstants.otpLength;
    
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: inputWidth,
            child: ValueListenableBuilder<String>(
              valueListenable: _otpNotifier,
              builder: (context, otpValue, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(OtpPageConstants.otpLength, (index) {
                    return _buildDigitBox(
                      index,
                      otpValue,
                      digitBoxWidth,
                      sizes,
                    );
                  }),
                );
              },
            ),
          ),
          Positioned.fill(
            child: Semantics(
              label: 'OTP input field. Enter ${OtpPageConstants.otpLength} digits',
              textField: true,
              enabled: !_isLoading,
              child: TextField(
                controller: _otpController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: OtpPageConstants.otpLength,
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
                  LengthLimitingTextInputFormatter(OtpPageConstants.otpLength),
                ],
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    HapticFeedback.selectionClick();
                    _animateDigitEntry(value.length - 1);
                  }
                  
                  if (value.length == OtpPageConstants.otpLength) {
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
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox(
    int index,
    String otpValue,
    double digitBoxWidth,
    Map<String, double> sizes,
  ) {
    final hasValue = index < otpValue.length;
    final isCurrent = index == otpValue.length;
    
    return AnimatedBuilder(
      animation: _digitAnimations[index],
      builder: (context, child) {
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
                hasValue ? otpValue[index] : '',
                key: ValueKey('$index-${hasValue ? otpValue[index] : ''}'),
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

  Widget _buildActionButtons(
    double screenWidth,
    double screenHeight,
    Map<String, double> sizes,
  ) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: TextButton(
          onPressed: (_isLoading || _isVerifying) ? null : _verifyOtp,
          style: TextButton.styleFrom(
            backgroundColor: (_isLoading || _isVerifying) ? Colors.grey[300] : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: Size(screenWidth * 0.8, screenHeight * 0.06),
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.015,
            ),
          ),
          child: (_isLoading || _isVerifying)
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey[600]!,
                    ),
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

  Future<void> _resendOtp() async {
    if (_isLoading) return;
    
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      await FirebaseAuthService.sendOTP(
        phoneNumber: widget.phoneNumber,
        resendToken: FirebaseAuthService.resendToken,
        isLoginFlow: widget.isLoginFlow,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() => _isLoading = false);
            _resetResendTimer();
            _resetAndPlayScaleAnimation();
            
            _showSnackBar('OTP sent successfully!', Colors.green);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar(error, Colors.red);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to resend OTP', Colors.red);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying || _isLoading) return;
    
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < OtpPageConstants.otpLength) {
      _showSnackBar(
        'Please enter a valid ${OtpPageConstants.otpLength}-digit OTP',
        Colors.red,
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isVerifying = true;
    });

    try {
      final result = await FirebaseAuthService.verifyOTP(
        otp: otp,
        phoneNumber: widget.phoneNumber,
        isLoginFlow: widget.isLoginFlow,
      );
      
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isVerifying = false;
      });
      
      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        
        final isTestMode = result['testMode'] == true;
        final isNewUser = result['isNewUser'] == true;
        final isRegistered = result['isRegistered'] == true;
        
        debugPrint('📱 OTP Verification Result:');
        debugPrint('   isNewUser: $isNewUser');
        debugPrint('   isRegistered: $isRegistered');
        debugPrint('   isLoginFlow: ${widget.isLoginFlow}');
        
        _showSnackBar(
          isTestMode 
            ? 'TEST MODE: Verification successful!' 
            : 'Verification successful!',
          isTestMode ? Colors.orange : Colors.green,
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          if (widget.isLoginFlow) {
            // Login flow - user should be registered
            if (isRegistered) {
              _navigateToHome();
            } else {
              // This shouldn't happen in login flow, but handle it
              _showSnackBar('Account not fully registered. Please complete registration.', Colors.orange);
              _navigateToRegistration();
            }
          } else {
            // Registration flow
            if (isNewUser) {
              _navigateToRegistration();
            } else {
              // Already registered - go to home
              _showSnackBar('Account already exists. Logging in...', Colors.blue);
              _navigateToHome();
            }
          }
        }
      } else {
        _showSnackBar(result['error'] ?? 'Verification failed', Colors.red);
        _otpController.clear();
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVerifying = false;
        });
        _showSnackBar('Verification failed. Please try again.', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _navigateToRegistration() {
    _resendTimer?.cancel();
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            DriverRegistrationPage(phoneNumber: widget.phoneNumber),
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

  void _navigateToHome() {
    _resendTimer?.cancel();
    
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const DriverSideHome(),
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
      (route) => false, // Remove all previous routes
    );
  }
}