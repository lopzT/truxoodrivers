import 'package:flutter/material.dart';
import 'dart:async';
import 'package:truxoo_partners/onboarding_page.dart';

class TypingSplashScreen extends StatefulWidget {
  const TypingSplashScreen({super.key});

  @override
  State<TypingSplashScreen> createState() => _TypingSplashScreenState();
}

class _TypingSplashScreenState extends State<TypingSplashScreen>
    with TickerProviderStateMixin {
  static const String _fullText = "Truxoo";
  static const Duration _imageAnimationDuration = Duration(milliseconds: 1500);
  static const Duration _textAnimationDuration = Duration(milliseconds: 800);
  static const Duration _typingDelay = Duration(milliseconds: 400);
  static const Duration _finalDelay = Duration(milliseconds: 800);

  late AnimationController _imageAnimationController;
  late AnimationController _textAnimationController;
  late Animation<double> _imageAnimation;
  late Animation<double> _textAnimation;

  String _visibleText = "";
  bool _showImage = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSplashSequence();
    });
  }

  void _initializeAnimations() {
    _imageAnimationController = AnimationController(
      duration: _imageAnimationDuration,
      vsync: this,
    );

    _textAnimationController = AnimationController(
      duration: _textAnimationDuration,
      vsync: this,
    );

    _imageAnimation = CurvedAnimation(
      parent: _imageAnimationController,
      curve: Curves.easeInOut,
    );

    _textAnimation = CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/loading_image.png'), context);
  }

  Future<void> _startSplashSequence() async {
    if (!mounted) return;

    setState(() => _showImage = true);
    _imageAnimationController.forward();
    
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await _startTypingAnimation();
    if (!mounted) return;

    _textAnimationController.forward();
    
    await Future.delayed(_finalDelay);
    if (!mounted) return;

    _navigateToNextScreen();
  }

  Future<void> _startTypingAnimation() async {
    for (int i = 0; i < _fullText.length; i++) {
      if (!mounted) return;
      await Future.delayed(_typingDelay);
      if (!mounted) return;
      
      setState(() => _visibleText = _fullText.substring(0, i + 1));
    }
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _imageAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final imageSize = isTablet ? 200.0 : 150.0;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_imageAnimation, _textAnimation]),
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image with animation
                    Transform.scale(
                      scale: _imageAnimation.value,
                      child: Opacity(
                        opacity: _showImage ? _imageAnimation.value : 0.0,
                        child: _buildImageContainer(imageSize),
                      ),
                    ),
                    SizedBox(height: isTablet ? 40 : 30),
                    // Text with animation
                    Transform.scale(
                      scale: 0.8 + (_textAnimation.value * 0.2),
                      child: _buildTextWidget(isTablet),
                    ),
                    // Loading indicator
                    if (_visibleText.length == _fullText.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: SizedBox.square(
                          dimension: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey[400]!,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContainer(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/loading_image.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.image_not_supported,
                size: size * 0.5,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextWidget(bool isTablet) {
    return Text(
      _visibleText,
      style: TextStyle(
        fontSize: isTablet ? 50 : 40,
        color: Colors.black,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}