// lib/services/firebase_auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'truxoodriver',
      );

  static String? _verificationId;
  static int? _resendToken;

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static int? get resendToken => _resendToken;
  static String? get verificationId => _verificationId;

  // ========== NORMALIZE PHONE NUMBER ==========
  static String normalizePhoneNumber(String phoneNumber) {
    String digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.startsWith('91') && digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(2);
    }
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  // ========== CHECK IF DRIVER EXISTS ==========
  static Future<Map<String, dynamic>> checkDriverExists(String phoneNumber) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phoneNumber);
      final formattedPhone = '+91$normalizedPhone';

      debugPrint('🔍 Checking if driver exists: $formattedPhone');

      final querySnapshot = await _firestore
          .collection('drivers')
          .where('phoneNumber', isEqualTo: formattedPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final profileCompleted = data['profileCompleted'] == true;

        debugPrint('✅ Driver found: ${doc.id}, profileCompleted: $profileCompleted');

        return {
          'exists': true,
          'profileCompleted': profileCompleted,
          'uid': doc.id,
          'data': data,
        };
      }

      debugPrint('❌ Driver not found in database');
      return {
        'exists': false,
        'profileCompleted': false,
      };
    } catch (e) {
      debugPrint('❌ Error checking driver: $e');
      return {
        'exists': false,
        'profileCompleted': false,
        'error': e.toString(),
      };
    }
  }

  // ========== CHECK IF PHONE IS REGISTERED ==========
  static Future<Map<String, dynamic>> checkPhoneForLogin(String phoneNumber) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phoneNumber);
      final formattedPhone = '+91$normalizedPhone';

      debugPrint('🔍 Checking phone for login: $formattedPhone');

      final querySnapshot = await _firestore
          .collection('drivers')
          .where('phoneNumber', isEqualTo: formattedPhone)
          .where('profileCompleted', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return {
          'isRegistered': true,
          'uid': querySnapshot.docs.first.id,
          'data': querySnapshot.docs.first.data(),
        };
      }

      return {'isRegistered': false};
    } catch (e) {
      debugPrint('❌ Error checking phone for login: $e');
      return {'isRegistered': false, 'error': e.toString()};
    }
  }

  // ========== SEND OTP ==========
  static Future<Map<String, dynamic>> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    int? resendToken,
    bool isLoginFlow = true,
  }) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phoneNumber);
      debugPrint('📱 Sending OTP to: +91$normalizedPhone');

      // NOTE: For test numbers (added in Firebase Console), Firebase will NOT send an SMS.
      // It will simply succeed here and wait for you to enter the code defined in Console.

      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$normalizedPhone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken ?? _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Auto-verification completed');
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            debugPrint('Auto sign-in error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Verification failed: ${e.code} - ${e.message}');
          String errorMessage = _getErrorMessage(e.code);
          onError(errorMessage);
        },
        codeSent: (String verificationId, int? token) {
          debugPrint('✅ OTP verification started');
          _verificationId = verificationId;
          _resendToken = token;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ Auto retrieval timeout');
          _verificationId = verificationId;
        },
      );

      return {'success': true};
    } catch (e) {
      debugPrint('❌ Send OTP error: $e');
      onError('Failed to send OTP. Please try again.');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========== VERIFY OTP ==========
  static Future<Map<String, dynamic>> verifyOTP({
    required String otp,
    String? phoneNumber,
    bool isLoginFlow = true,
  }) async {
    try {
      debugPrint('🔐 Verifying OTP: $otp');

      if (_verificationId == null) {
        return {
          'success': false,
          'error': 'Session expired. Please request OTP again.'
        };
      }

      // Create credential with the OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Sign in using the credential
      // If using a test number, Firebase validates against the Console code (123456)
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        debugPrint('✅ OTP verified & User Signed In!');
        debugPrint('👤 User UID: ${userCredential.user!.uid}');

        // Check if driver profile exists
        final phone = normalizePhoneNumber(userCredential.user!.phoneNumber ?? '');
        final driverCheck = await checkDriverExists(phone);

        final bool isExistingUser = driverCheck['exists'] == true && 
                                    driverCheck['profileCompleted'] == true;

        // Create basic record if new user
        if (!driverCheck['exists']) {
          await _createBasicDriverRecord(userCredential.user!);
        }

        return {
          'success': true,
          'user': userCredential.user,
          'uid': userCredential.user!.uid,
          'phoneNumber': userCredential.user!.phoneNumber,
          'isNewUser': !isExistingUser,
          'isRegistered': isExistingUser,
          'driverData': driverCheck['data'],
        };
      }

      return {'success': false, 'error': 'Authentication failed'};
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code}');
      return {'success': false, 'error': _getErrorMessage(e.code)};
    } catch (e) {
      debugPrint('❌ Verify OTP error: $e');
      return {
        'success': false,
        'error': 'Verification failed. Please try again.'
      };
    }
  }

  // Create basic driver record
  static Future<void> _createBasicDriverRecord(User user) async {
    try {
      await _firestore.collection('drivers').doc(user.uid).set({
        'uid': user.uid,
        'phoneNumber': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isOnline': false,
        'isVerified': false,
        'profileCompleted': false,
      }, SetOptions(merge: true));
      debugPrint('✅ Basic driver record created');
    } catch (e) {
      debugPrint('Error creating driver record: $e');
    }
  }

  // Get error message
  static String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again';
      case 'session-expired':
        return 'OTP expired. Please request a new one';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred. Please try again';
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ User signed out');
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}