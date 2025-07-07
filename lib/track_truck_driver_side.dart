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

  // This would come from your backend
  final Map<String, DeliveryInfo> _deliveryDatabase = {
    'TRX123456': DeliveryInfo(
      truckId: 'OD02AB1234',
      driverName: 'Soumesh Padhaya',
      pickupLocation: 'Bhubaneswar',
      dropLocation: 'Cuttack',
      status: 'In Transit',
      estimatedDelivery: '18 Jun 2025, 15:30',
      currentLocation: 'Near Rasulgarh Square, Bhubaneswar',
    ),
    // Add more deliveries
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
          content: Text('Invalid tracking number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTracking = true;
      _currentTrackingId = trackingId;
    });

    // Start periodic location updates
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(hours: 1), // Update every hour
      (timer) => _updateLocation(),
    );

    // Initial update
    _updateLocation();
  }

  void _updateLocation() {
    if (!_isTracking || _currentTrackingId == null) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      final delivery = _deliveryDatabase[_currentTrackingId!];
      if (delivery == null) return;

      // Simulate location update
      delivery.currentLocation = 'Updated location: ${DateTime.now().toString()}';

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
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
            _buildInfoRow(
              'Current Location',
              delivery.currentLocation,
              isLargeScreen,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Location updates every hour',
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
  final String status;
  final String estimatedDelivery;
  String currentLocation;

  DeliveryInfo({
    required this.truckId,
    required this.driverName,
    required this.pickupLocation,
    required this.dropLocation,
    required this.status,
    required this.estimatedDelivery,
    required this.currentLocation,
  });
}