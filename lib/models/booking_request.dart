import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, accepted, denied, completed, cancelled }

class BookingRequest {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String clientPhoto;
  final String pickupLocation;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String dropLocation;
  final String dropAddress;
  final double? dropLat;
  final double? dropLng;
  final String date;
  final DateTime timestamp;
  final BookingStatus status;
  final double? estimatedFare;
  final String? vehicleType;
  final String? goodsType;
  final double? weight;
  final String? notes;
  final List<String> deniedBy;

  BookingRequest({
    required this.id,
    this.clientId = '',
    required this.clientName,
    required this.clientPhone,
    this.clientPhoto = '',
    required this.pickupLocation,
    this.pickupAddress = '',
    this.pickupLat,
    this.pickupLng,
    required this.dropLocation,
    this.dropAddress = '',
    this.dropLat,
    this.dropLng,
    required this.date,
    required this.timestamp,
    this.status = BookingStatus.pending,
    this.estimatedFare,
    this.vehicleType,
    this.goodsType,
    this.weight,
    this.notes,
    this.deniedBy = const [],
  });
  factory BookingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingRequest.fromMap(doc.id, data);
  }
  factory BookingRequest.fromMap(String id, Map<String, dynamic> data) {
    return BookingRequest(
      id: id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? 'Unknown Customer',
      clientPhone: data['clientPhone'] ?? '',
      clientPhoto: data['clientPhoto'] ?? '',
      pickupLocation: data['pickupLocation'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      dropLocation: data['dropLocation'] ?? '',
      dropAddress: data['dropAddress'] ?? '',
      dropLat: (data['dropLat'] as num?)?.toDouble(),
      dropLng: (data['dropLng'] as num?)?.toDouble(),
      date: data['date'] ?? _formatDate(data['createdAt']),
      timestamp: _parseTimestamp(data['createdAt']),
      status: _parseStatus(data['status']),
      estimatedFare: (data['estimatedFare'] as num?)?.toDouble(),
      vehicleType: data['vehicleType'],
      goodsType: data['goodsType'],
      weight: (data['weight'] as num?)?.toDouble(),
      notes: data['notes'],
      deniedBy: List<String>.from(data['deniedBy'] ?? []),
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return DateTime.now();
  }

  static String _formatDate(dynamic timestamp) {
    try {
      final date = _parseTimestamp(timestamp);
      return '${date.day}/${date.month}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  static BookingStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return BookingStatus.pending;
      case 'accepted':
        return BookingStatus.accepted;
      case 'denied':
        return BookingStatus.denied;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientPhoto': clientPhoto,
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropLocation': dropLocation,
      'dropAddress': dropAddress,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'date': date,
      'createdAt': Timestamp.fromDate(timestamp),
      'status': status.name,
      'estimatedFare': estimatedFare,
      'vehicleType': vehicleType,
      'goodsType': goodsType,
      'weight': weight,
      'notes': notes,
      'deniedBy': deniedBy,
    };
  }

  // Create a copy with updated fields
  BookingRequest copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? clientPhoto,
    String? pickupLocation,
    String? dropLocation,
    String? date,
    DateTime? timestamp,
    BookingStatus? status,
    double? estimatedFare,
  }) {
    return BookingRequest(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientPhoto: clientPhoto ?? this.clientPhoto,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      estimatedFare: estimatedFare ?? this.estimatedFare,
    );
  }
}