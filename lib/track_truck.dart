import 'package:flutter/material.dart';
import 'dart:async';

class TrackTruck extends StatefulWidget {
  const TrackTruck({super.key});

  @override
  State<TrackTruck> createState() => _TrackTruckState();
}

class _TrackTruckState extends State<TrackTruck> {
  final TextEditingController _trackingController = TextEditingController();
  bool _isTracking = false;
  bool _isLoading = false;
  String? _currentTrackingId;
  Timer? _locationUpdateTimer;
  int _updateCount = 0;

  final Map<String, DeliveryInfo> _deliveryDatabase = {
    'TRX123456': DeliveryInfo(
      truckId: 'OD02AB1234',
      driverName: 'Soumesh Padhaya',
      pickupLocation: 'Bhubaneswar',
      dropLocation: 'Cuttack',
      status: 'In Transit',
      estimatedDelivery: '18 Jun 2025, 15:30',
      currentLocation: 'Near Rasulgarh Square, Bhubaneswar',
      lastUpdated: DateTime.now(),
    ),
  };


  final Map<String, List<String>> _locationProgression = {
    'TRX123456': [
      'Near Rasulgarh Square, Bhubaneswar',
      'Crossing Cuttack Road Bridge',
      'Approaching Jagatpur Industrial Area',
      'Near Cuttack Railway Station',
      'Entering Cuttack City Center',
    ],
  };

  @override
  void dispose() {
    _trackingController.dispose();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startTracking(String trackingId) {
    final delivery = _deliveryDatabase[trackingId];
    if (delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid tracking number.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isTracking = true;
      _currentTrackingId = trackingId;
      _updateCount = 0;
    });

    
    _locationUpdateTimer?.cancel();
    if (delivery.status.toLowerCase() == 'in transit') {
      _locationUpdateTimer = Timer.periodic(
        const Duration(minutes: 5), 
        (timer) => _updateLocation(),
      );
    }
  }

  void _updateLocation() {
    if (!_isTracking || _currentTrackingId == null) return;

    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      final delivery = _deliveryDatabase[_currentTrackingId!];
      if (delivery == null) return;

      if (_locationProgression.containsKey(_currentTrackingId!)) {
        final locations = _locationProgression[_currentTrackingId!]!;
        if (_updateCount < locations.length - 1) {
          _updateCount++;
          delivery.currentLocation = locations[_updateCount];
          delivery.lastUpdated = DateTime.now();
        } else {
          _locationUpdateTimer?.cancel();
          delivery.status = 'Delivered';
          delivery.currentLocation = 'Delivered at ${delivery.dropLocation}';
          delivery.lastUpdated = DateTime.now();
        }
      }

      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track Truck',
          style: TextStyle(
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _trackingController,
                        decoration: InputDecoration(
                          labelText: 'Enter Tracking Number',
                          
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              if (_trackingController.text.isNotEmpty) {
                                _startTracking(_trackingController.text);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_trackingController.text.isNotEmpty) {
                            _startTracking(_trackingController.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isLargeScreen ? 32 : 24,
                            vertical: isLargeScreen ? 16 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Track',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 18 : 16,
                          ),
                        ),
                      ),
                      if (!_isTracking)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            'Sample tracking number: TRX123456',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              if (_isTracking && _currentTrackingId != null && !_isLoading)
                _buildDeliveryInfo(_deliveryDatabase[_currentTrackingId!]!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo(DeliveryInfo delivery) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Card(
      margin: EdgeInsets.symmetric(vertical: isLargeScreen ? 24.0 : 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Truck ${delivery.truckId}',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(delivery.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    delivery.status,
                    style: TextStyle(
                      color: _getStatusColor(delivery.status),
                      fontSize: isLargeScreen ? 14 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Driver', delivery.driverName, isLargeScreen),
            _buildInfoRow('From', delivery.pickupLocation, isLargeScreen),
            _buildInfoRow('To', delivery.dropLocation, isLargeScreen),
            _buildInfoRow(
              'Estimated Delivery',
              delivery.estimatedDelivery,
              isLargeScreen,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(delivery, isLargeScreen),
            const SizedBox(height: 16),
            Center(
              child: Text(
                delivery.status.toLowerCase() == 'in transit'
                    ? 'Location updates every 5 minutes'
                    : 'Last updated: ${_formatTime(delivery.lastUpdated)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isLargeScreen ? 14 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(DeliveryInfo delivery, bool isLargeScreen) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.blue,
                size: isLargeScreen ? 20 : 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Current Location:',
                style: TextStyle(
                  fontSize: isLargeScreen ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            delivery.currentLocation,
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: ${_formatTime(delivery.lastUpdated)}',
            style: TextStyle(
              fontSize: isLargeScreen ? 12 : 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isLargeScreen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'delayed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class DeliveryInfo {
  final String truckId;
  final String driverName;
  final String pickupLocation;
  final String dropLocation;
  String status;
  final String estimatedDelivery;
  String currentLocation;
  DateTime lastUpdated;

  DeliveryInfo({
    required this.truckId,
    required this.driverName,
    required this.pickupLocation,
    required this.dropLocation,
    required this.status,
    required this.estimatedDelivery,
    required this.currentLocation,
    required this.lastUpdated,
  });
}
//ready