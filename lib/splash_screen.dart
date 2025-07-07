import 'package:flutter/material.dart';
import 'dart:async';
import 'package:truxoo_partners/onboarding_page.dart';

class TypingSplashScreen extends StatefulWidget {
  const TypingSplashScreen({super.key});

  @override
  _TypingSplashScreenState createState() => _TypingSplashScreenState();
}

class _TypingSplashScreenState extends State<TypingSplashScreen>
    with TickerProviderStateMixin {
  final String _fullText = "Truxoo";
  String _visibleText = "";
  bool _showImage = false;
  bool _isDisposed = false;

  late AnimationController _imageAnimationController;
  late AnimationController _textAnimationController;
  late Animation<double> _imageAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    _imageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    if (_isDisposed) return;
    
    try {
      setState(() => _showImage = true);
      _imageAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 800));
      if (_isDisposed) return;
      await _startTypingAnimation();
      if (_isDisposed) return;
      _textAnimationController.forward();
      await Future.delayed(const Duration(seconds: 1));
      if (_isDisposed) return;
      _navigateToNextScreen();
      
    } catch (e) {
      _navigateToNextScreen();
    }
  }

  Future<void> _startTypingAnimation() async {
    for (int i = 0; i < _fullText.length; i++) {
      if (_isDisposed) return;
      
      await Future.delayed(const Duration(milliseconds: 400));
      
      if (_isDisposed) return;
      setState(() {
        _visibleText += _fullText[i];
      });
    }
  }

  void _navigateToNextScreen() {
    if (_isDisposed || !mounted) return;
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OnboardingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _imageAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _imageAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _imageAnimation.value,
                    child: Opacity(
                      opacity: _showImage ? _imageAnimation.value : 0.0,
                      child: Container(
                        width: isTablet ? 200 : 150,
                        height: isTablet ? 200 : 150,
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
                                  size: isTablet ? 80 : 60,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: isTablet ? 40 : 30),
              
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (_textAnimation.value * 0.2),
                    child: Text(
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
                    ),
                  );
                },
              ),
              
              if (_visibleText.length == _fullText.length)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[400]!,
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
}
//ready