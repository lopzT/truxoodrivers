import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const double _largeScreenBreakpoint = 600;
  static const double _buttonWidthRatio = 0.8;
  static const double _horizontalPaddingRatio = 0.08;
  static const double _imageAspectRatio = 0.6;
  
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });

    try {
      final futures = <Future>[];
      futures.add(
        precacheImage(const AssetImage('assets/onboarding_logo.png'), context)
          .catchError((e) => debugPrint('Logo not found: $e'))
      );
      futures.add(
        precacheImage(const AssetImage('assets/onboarding_main.jpg'), context)
          .catchError((e) => debugPrint('Main image not found: $e'))
      );
      await Future.wait(futures);
      debugPrint('✅ Assets preloaded successfully');
    } catch (e) {
      debugPrint('Asset preloading failed: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenWidth > _largeScreenBreakpoint;
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(isLargeScreen),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainImage(screenWidth),
              _buildContent(screenWidth, screenHeight, isLargeScreen),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isLargeScreen) {
    return PreferredSize(
      preferredSize: Size.fromHeight(isLargeScreen ? 100 : 80),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: isLargeScreen ? 20 : 10),
            Flexible(
              child: Text(
                'Welcome To',
                style: TextStyle(
                  fontSize: isLargeScreen ? 40 : 36,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: isLargeScreen ? 24 : 16),
            _buildLogo(isLargeScreen),
          ],
        ),
        toolbarHeight: isLargeScreen ? 100 : 80,
      ),
    );
  }

  Widget _buildLogo(bool isLargeScreen) {
    return Image.asset(
      'assets/onboarding_logo.png',
      height: isLargeScreen ? 45 : 35,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: isLargeScreen ? 45 : 35,
          height: isLargeScreen ? 45 : 35,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.business,
            size: isLargeScreen ? 20 : 15,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  Widget _buildMainImage(double screenWidth) {
    return SizedBox(
      width: screenWidth,
      child: Image.asset(
        'assets/onboarding_main.jpg',
        fit: BoxFit.fitWidth,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder(screenWidth);
        },
      ),
    );
  }

  Widget _buildImagePlaceholder(double screenWidth) {
    return Container(
      width: screenWidth,
      height: screenWidth * _imageAspectRatio,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.blue[100]!,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping,
            size: 80,
            color: Colors.blue[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Truxoo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logistics Made Simple',
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double screenWidth, double screenHeight, bool isLargeScreen) {
    final verticalSpacing = isLargeScreen ? 50.0 : 30.0;
    final buttonSpacing = isLargeScreen ? screenHeight * 0.1 : screenHeight * 0.06;
    final bottomSpacing = isLargeScreen ? 40.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: verticalSpacing),
        _buildTagline(screenWidth, isLargeScreen),
        SizedBox(height: buttonSpacing),
        _buildContinueButton(screenWidth, isLargeScreen),
        SizedBox(height: isLargeScreen ? 20 : 12),
        _buildTermsText(screenWidth, isLargeScreen),
        SizedBox(height: bottomSpacing),
      ],
    );
  }

  Widget _buildTagline(double screenWidth, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(left: screenWidth * _horizontalPaddingRatio),
      child: Text(
        'Logistics Made Simple',
        style: TextStyle(
          fontSize: isLargeScreen ? 40 : 36,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildContinueButton(double screenWidth, bool isLargeScreen) {
    return Center(
      child: SizedBox(
        width: screenWidth * _buttonWidthRatio,
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _navigateToLogin();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size(screenWidth * _buttonWidthRatio, isLargeScreen ? 65 : 50),
              padding: EdgeInsets.symmetric(
                vertical: isLargeScreen ? 18 : 12,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue with Phone Number',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 18 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: isLargeScreen ? 12 : 8),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: isLargeScreen ? 24 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText(double screenWidth, bool isLargeScreen) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * _horizontalPaddingRatio),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: isLargeScreen ? 12 : 10,
              color: Colors.grey[600],
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'By continuing, you agree that you have read and accept our '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showTermsAndConditions();
                  },
                  child: Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.black87,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ' and '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showPrivacyPolicy();
                  },
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsAndConditions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const Text(
                    'Your terms and conditions content would go here. This is a placeholder for the actual terms and conditions that users need to agree to before using your app.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: const Text(
                    'Your privacy policy content would go here. This is a placeholder for the actual privacy policy that explains how you collect, use, and protect user data.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const Login(),
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
}