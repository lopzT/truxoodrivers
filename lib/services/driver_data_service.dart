// lib/services/driver_data_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DriverDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'truxoodriver',
  );
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get drivers collection reference
  static CollectionReference get _driversCollection =>
      _firestore.collection('drivers');

  // Get booking requests collection reference
  static CollectionReference get _bookingsCollection =>
      _firestore.collection('booking_requests');

  // Get current driver ID
  static String? get currentDriverId => _auth.currentUser?.uid;

  // ==================== IMAGE UPLOAD METHODS ====================

  // Upload single image to Firebase Storage
  static Future<String?> uploadImage({
    required File imageFile,
    required String folder,
    required String fileName,
    String? customUid,
  }) async {
    try {
      final uid = customUid ?? _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('Upload failed: No user ID');
        return null;
      }

      final String storagePath = 'drivers/$uid/$folder/$fileName';
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'userId': uid,
        },
      );

      debugPrint('Uploading image to: $storagePath');

      final uploadTask = ref.putFile(imageFile, metadata);

      // Monitor progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Upload multiple images
  static Future<Map<String, String?>> uploadMultipleImages({
    required Map<String, File?> images,
    String? customUid,
  }) async {
    final Map<String, String?> urls = {};

    for (final entry in images.entries) {
      if (entry.value != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final url = await uploadImage(
          imageFile: entry.value!,
          folder: entry.key,
          fileName: '${entry.key}_$timestamp.jpg',
          customUid: customUid,
        );
        urls[entry.key] = url;
      }
    }

    return urls;
  }

  // ==================== DRIVER REGISTRATION ====================

  // Register new driver with all details
  static Future<Map<String, dynamic>> registerDriver({
    required DriverRegistrationData data,
    String? customUid,
  }) async {
    try {
      // Determine UID
      String uid;
      if (customUid != null) {
        uid = customUid;
      } else if (_auth.currentUser != null) {
        uid = _auth.currentUser!.uid;
      } else {
        // For test mode, create a UID from phone number
        uid = 'driver_${data.phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}';
      }

      debugPrint('Registering driver with UID: $uid');

      // Upload all images first
      final imageUrls = await uploadMultipleImages(
        images: {
          'profile_photo': data.driverPhoto,
          'license_photo': data.licensePhoto,
          'pan_aadhar_photo': data.panAadharPhoto,
          'truck_photo': data.truckPhoto,
        },
        customUid: uid,
      );

      debugPrint(
          'Images uploaded: ${imageUrls.keys.where((k) => imageUrls[k] != null).toList()}');

      // Prepare driver document
      final driverDoc = {
        // System fields
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),

        // Personal Information
        'name': data.name,
        'phoneNumber':
            '+91${data.phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}',
        'email': data.email?.isNotEmpty == true ? data.email : null,
        'dateOfBirth': data.dateOfBirth,
        'state': data.state,
        'city': data.city,
        'languagesSpoken': data.languagesSpoken,

        // License Information
        'licenseNumber': data.licenseNumber,
        'licenseExpiry': data.licenseExpiry,

        // Truck Information
        'truckType': data.truckType,
        'truckModel': data.truckModel,
        'truckNumber': data.truckNumber?.toUpperCase(),

        // Association Information
        'associationType': data.associationType,
        'companyName':
            data.associationType == 'company' ? data.companyName : null,
        'operationRules': data.operationRules,

        // Image URLs
        'profilePhotoUrl': imageUrls['profile_photo'],
        'licensePhotoUrl': imageUrls['license_photo'],
        'panAadharPhotoUrl': imageUrls['pan_aadhar_photo'],
        'truckPhotoUrl': imageUrls['truck_photo'],

        // Status fields
        'isVerified': false,
        'isActive': true,
        'isOnline': false,
        'profileCompleted': true,
        'availableForBooking': false,
        'hasActiveBooking': false,
        'currentBookingId': null,

        // Stats (initialized)
        'rating': 0.0,
        'totalRides': 0,
        'totalEarnings': 0.0,
        'completedRides': 0,
        'cancelledRides': 0,
      };

      // Save to Firestore
      await _driversCollection.doc(uid).set(driverDoc, SetOptions(merge: true));

      debugPrint('Driver registered successfully');

      return {
        'success': true,
        'uid': uid,
        'message': 'Registration successful',
      };
    } catch (e) {
      debugPrint('Error registering driver: $e');
      return {
        'success': false,
        'error': 'Registration failed: ${e.toString()}',
      };
    }
  }

  // ==================== DRIVER PROFILE METHODS ====================

  // Get driver profile
  static Future<Map<String, dynamic>?> getDriverProfile([String? uid]) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) return null;

      final doc = await _driversCollection.doc(targetUid).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting driver profile: $e');
      return null;
    }
  }

  // Update driver profile
  static Future<Map<String, dynamic>> updateDriverProfile({
    required Map<String, dynamic> updates,
    File? newProfilePhoto,
    String? uid,
  }) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Upload new profile photo if provided
      if (newProfilePhoto != null) {
        final photoUrl = await uploadImage(
          imageFile: newProfilePhoto,
          folder: 'profile_photo',
          fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          customUid: targetUid,
        );
        if (photoUrl != null) {
          updates['profilePhotoUrl'] = photoUrl;
        }
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _driversCollection.doc(targetUid).update(updates);

      return {'success': true, 'message': 'Profile updated successfully'};
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return {'success': false, 'error': 'Update failed: ${e.toString()}'};
    }
  }

  // ==================== ONLINE STATUS METHODS ====================

  // Update online status - Returns bool for success/failure
  static Future<bool> updateOnlineStatus(bool isOnline, [String? uid]) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) {
        debugPrint('❌ No driver logged in');
        return false;
      }

      await _driversCollection.doc(targetUid).update({
        'isOnline': isOnline,
        'lastOnlineAt': FieldValue.serverTimestamp(),
        'availableForBooking': isOnline,
        'lastOnlineUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Driver online status updated: $isOnline');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating online status: $e');
      return false;
    }
  }

  // Get driver's current online status
  static Future<bool> getOnlineStatus([String? uid]) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) return false;

      final doc = await _driversCollection.doc(targetUid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isOnline'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error getting online status: $e');
      return false;
    }
  }

  // ==================== LOCATION METHODS ====================

  // Update location
  static Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? uid,
  }) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) return;

      await _driversCollection.doc(targetUid).update({
        'currentLocation': GeoPoint(latitude, longitude),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📍 Location updated: ($latitude, $longitude)');
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
    }
  }

  // ==================== BOOKING STREAMS ====================

  /// Stream of available bookings (pending and not denied by this driver)
  static Stream<List<Map<String, dynamic>>> getAvailableBookingsStream() {
    final uid = currentDriverId;
    if (uid == null) {
      debugPrint('❌ No driver ID for booking stream');
      return Stream.value([]);
    }

    return _bookingsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final deniedBy = List<String>.from(data['deniedBy'] ?? []);
        return !deniedBy.contains(uid);
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    });
  }

  /// Stream of driver's accepted booking
  static Stream<DocumentSnapshot?> getAcceptedBookingStream() {
    final uid = currentDriverId;
    if (uid == null) {
      return Stream.value(null);
    }

    return _bookingsCollection
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
      return null;
    });
  }

  /// Stream of pending booking requests (legacy method)
  static Stream<QuerySnapshot> getBookingRequestsStream() {
    final uid = currentDriverId;
    if (uid == null) {
      debugPrint('❌ No driver ID for booking stream');
      return const Stream.empty();
    }

    return _bookingsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  // ==================== BOOKING ACTIONS ====================

  /// Accept a booking request
  static Future<bool> acceptBooking(String bookingId) async {
    try {
      final uid = currentDriverId;
      if (uid == null) {
        debugPrint('❌ No driver logged in');
        return false;
      }

      // Get driver info
      final driverDoc = await _driversCollection.doc(uid).get();
      final driverData = driverDoc.data() as Map<String, dynamic>?;

      if (driverData == null) {
        debugPrint('❌ Driver data not found');
        return false;
      }

      // Use transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        final bookingRef = _bookingsCollection.doc(bookingId);
        final bookingSnapshot = await transaction.get(bookingRef);

        if (!bookingSnapshot.exists) {
          throw Exception('Booking not found');
        }

        final bookingData = bookingSnapshot.data() as Map<String, dynamic>;
        if (bookingData['status'] != 'pending') {
          throw Exception('Booking is no longer available');
        }

        // Update booking with driver info
        transaction.update(bookingRef, {
          'status': 'accepted',
          'driverId': uid,
          'driverName': driverData['name'] ?? '',
          'driverPhone': driverData['phoneNumber'] ?? '',
          'driverPhoto': driverData['profilePhotoUrl'] ?? '',
          'truckNumber': driverData['truckNumber'] ?? '',
          'truckType': driverData['truckType'] ?? '',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Update driver status
        final driverRef = _driversCollection.doc(uid);
        transaction.update(driverRef, {
          'currentBookingId': bookingId,
          'hasActiveBooking': true,
          'availableForBooking': false,
        });
      });

      debugPrint('✅ Booking accepted: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting booking: $e');
      return false;
    }
  }

  /// Deny a booking request
  static Future<bool> denyBooking(String bookingId) async {
    try {
      final uid = currentDriverId;
      if (uid == null) {
        debugPrint('❌ No driver logged in');
        return false;
      }

      await _bookingsCollection.doc(bookingId).update({
        'deniedBy': FieldValue.arrayUnion([uid]),
      });

      debugPrint('✅ Booking denied: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error denying booking: $e');
      return false;
    }
  }

  /// Cancel an accepted booking
  static Future<bool> cancelBooking(String bookingId) async {
    try {
      final uid = currentDriverId;
      if (uid == null) {
        debugPrint('❌ No driver logged in');
        return false;
      }

      await _firestore.runTransaction((transaction) async {
        final bookingRef = _bookingsCollection.doc(bookingId);
        transaction.update(bookingRef, {
          'status': 'cancelled',
          'cancelledBy': 'driver',
          'cancelledAt': FieldValue.serverTimestamp(),
          'driverId': null,
        });

        final driverRef = _driversCollection.doc(uid);
        transaction.update(driverRef, {
          'currentBookingId': null,
          'hasActiveBooking': false,
          'availableForBooking': true,
        });
      });

      debugPrint('✅ Booking cancelled: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling booking: $e');
      return false;
    }
  }

  /// Complete a booking
  static Future<bool> completeBooking(String bookingId, {double? fare}) async {
    try {
      final uid = currentDriverId;
      if (uid == null) {
        debugPrint('❌ No driver logged in');
        return false;
      }

      await _firestore.runTransaction((transaction) async {
        final bookingRef = _bookingsCollection.doc(bookingId);
        transaction.update(bookingRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'finalFare': fare,
        });

        final driverRef = _driversCollection.doc(uid);
        transaction.update(driverRef, {
          'currentBookingId': null,
          'hasActiveBooking': false,
          'availableForBooking': true,
          'totalRides': FieldValue.increment(1),
          'completedRides': FieldValue.increment(1),
          'totalEarnings': FieldValue.increment(fare ?? 0),
        });
      });

      debugPrint('✅ Booking completed: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error completing booking: $e');
      return false;
    }
  }

  // ==================== CLIENT DATA METHODS ====================

  /// Get client details
  static Future<Map<String, dynamic>?> getClientDetails(String clientId) async {
    try {
      // Try clients collection first
      var doc = await _firestore.collection('clients').doc(clientId).get();

      if (!doc.exists) {
        // Try users collection
        doc = await _firestore.collection('users').doc(clientId).get();
      }

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting client details: $e');
      return null;
    }
  }

  /// Get complete booking details with client info
  static Future<Map<String, dynamic>?> getCompleteBookingDetails(
      String bookingId) async {
    try {
      final doc = await _bookingsCollection.doc(bookingId).get();
      if (!doc.exists) return null;

      final bookingData = doc.data() as Map<String, dynamic>;

      // Get client details if available
      final clientId = bookingData['clientId'];
      Map<String, dynamic>? clientData;
      if (clientId != null) {
        clientData = await getClientDetails(clientId);
      }

      return {
        'bookingId': doc.id,
        ...bookingData,
        'clientDetails': clientData,
      };
    } catch (e) {
      debugPrint('❌ Error getting booking details: $e');
      return null;
    }
  }

  // ==================== DOWNLOAD BOOKING INFO ====================

  /// Download booking info as PDF
  static Future<File?> downloadBookingInfo(String bookingId) async {
    try {
      final details = await getCompleteBookingDetails(bookingId);
      if (details == null) {
        debugPrint('❌ Booking details not found');
        return null;
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'TRUXOO',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Booking Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // Booking Info Section
                _buildPdfSectionHeader('Booking Information'),
                pw.SizedBox(height: 10),
                _buildPdfRow('Booking ID:', bookingId),
                _buildPdfRow('Date:', details['date'] ?? 'N/A'),
                _buildPdfRow('Status:', (details['status'] ?? 'N/A').toString().toUpperCase()),
                _buildPdfRow('Pickup Location:', details['pickupLocation'] ?? 'N/A'),
                _buildPdfRow('Pickup Address:', details['pickupAddress'] ?? 'N/A'),
                _buildPdfRow('Drop Location:', details['dropLocation'] ?? 'N/A'),
                _buildPdfRow('Drop Address:', details['dropAddress'] ?? 'N/A'),
                _buildPdfRow('Estimated Fare:', '₹${details['estimatedFare'] ?? 'N/A'}'),
                if (details['finalFare'] != null)
                  _buildPdfRow('Final Fare:', '₹${details['finalFare']}'),
                _buildPdfRow('Goods Type:', details['goodsType'] ?? 'N/A'),
                _buildPdfRow('Weight:', '${details['weight'] ?? 'N/A'} kg'),
                _buildPdfRow('Vehicle Type:', details['vehicleType'] ?? 'N/A'),

                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Client Info Section
                _buildPdfSectionHeader('Client Information'),
                pw.SizedBox(height: 10),
                _buildPdfRow('Name:', details['clientName'] ?? 'N/A'),
                _buildPdfRow('Phone:', details['clientPhone'] ?? 'N/A'),
                if (details['clientDetails'] != null) ...[
                  _buildPdfRow('Email:', details['clientDetails']['email'] ?? 'N/A'),
                  _buildPdfRow('Address:', details['clientDetails']['address'] ?? 'N/A'),
                  _buildPdfRow('City:', details['clientDetails']['city'] ?? 'N/A'),
                  _buildPdfRow('State:', details['clientDetails']['state'] ?? 'N/A'),
                ],

                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Additional Notes
                if (details['notes'] != null && details['notes'].toString().isNotEmpty) ...[
                  _buildPdfSectionHeader('Additional Notes'),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Text(
                      details['notes'] ?? '',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],

                pw.Spacer(),

                // Footer
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Generated on ${DateTime.now().toString().split('.')[0]}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'www.truxoo.com | support@truxoo.com',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/booking_$bookingId.pdf');
      await file.writeAsBytes(await pdf.save());

      debugPrint('✅ PDF saved: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('❌ Error downloading booking info: $e');
      return null;
    }
  }

  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey800,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UTILITY METHODS ====================

  // Check if phone number is already registered
  static Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    try {
      final formattedPhone =
          '+91${phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}';
      final query = await _driversCollection
          .where('phoneNumber', isEqualTo: formattedPhone)
          .where('profileCompleted', isEqualTo: true)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking phone number: $e');
      return false;
    }
  }

  // Get driver statistics
  static Future<Map<String, dynamic>> getDriverStats([String? uid]) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) {
        return {
          'totalRides': 0,
          'totalEarnings': 0.0,
          'rating': 0.0,
          'completedRides': 0,
          'cancelledRides': 0,
        };
      }

      final doc = await _driversCollection.doc(targetUid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'totalRides': data['totalRides'] ?? 0,
          'totalEarnings': (data['totalEarnings'] ?? 0.0).toDouble(),
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'completedRides': data['completedRides'] ?? 0,
          'cancelledRides': data['cancelledRides'] ?? 0,
        };
      }

      return {
        'totalRides': 0,
        'totalEarnings': 0.0,
        'rating': 0.0,
        'completedRides': 0,
        'cancelledRides': 0,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {
        'totalRides': 0,
        'totalEarnings': 0.0,
        'rating': 0.0,
        'completedRides': 0,
        'cancelledRides': 0,
      };
    }
  }

  // Check if driver exists by phone
  static Future<bool> driverExists(String phoneNumber) async {
    try {
      final formattedPhone =
          '+91${phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}';
      final query = await _driversCollection
          .where('phoneNumber', isEqualTo: formattedPhone)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking driver: $e');
      return false;
    }
  }

  // Get driver's ride history
  static Future<List<Map<String, dynamic>>> getRideHistory({
    int limit = 50,
    String? uid,
  }) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) return [];

      final query = await _bookingsCollection
          .where('driverId', isEqualTo: targetUid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      debugPrint('Error getting ride history: $e');
      return [];
    }
  }

  // Get monthly earnings
  static Future<List<Map<String, dynamic>>> getMonthlyEarnings({
    int months = 6,
    String? uid,
  }) async {
    try {
      final targetUid = uid ?? _auth.currentUser?.uid;
      if (targetUid == null) return [];

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - months + 1, 1);

      final query = await _bookingsCollection
          .where('driverId', isEqualTo: targetUid)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      // Group by month
      final Map<String, double> monthlyTotals = {};
      final List<String> monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        final fare = (data['finalFare'] ?? data['estimatedFare'] ?? 0.0).toDouble();

        if (completedAt != null) {
          final monthKey = '${monthNames[completedAt.month - 1]} ${completedAt.year}';
          monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + fare;
        }
      }

      return monthlyTotals.entries.map((entry) => {
        'month': entry.key,
        'amount': entry.value,
      }).toList();
    } catch (e) {
      debugPrint('Error getting monthly earnings: $e');
      return [];
    }
  }
}

// Data model for driver registration
class DriverRegistrationData {
  // Personal Information
  final String name;
  final String phoneNumber;
  final String? email;
  final String? dateOfBirth;
  final String? state;
  final String? city;
  final String? languagesSpoken;

  // License Information
  final String licenseNumber;
  final String? licenseExpiry;

  // Truck Information
  final String? truckType;
  final String? truckModel;
  final String? truckNumber;

  // Association Information
  final String associationType;
  final String? companyName;
  final String? operationRules;

  // Images
  final File? driverPhoto;
  final File? licensePhoto;
  final File? panAadharPhoto;
  final File? truckPhoto;

  DriverRegistrationData({
    required this.name,
    required this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.state,
    this.city,
    this.languagesSpoken,
    required this.licenseNumber,
    this.licenseExpiry,
    this.truckType,
    this.truckModel,
    this.truckNumber,
    this.associationType = 'individual',
    this.companyName,
    this.operationRules,
    this.driverPhoto,
    this.licensePhoto,
    this.panAadharPhoto,
    this.truckPhoto,
  });
}