import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'my_accounts_driver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_driver.dart';
import 'dart:math';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum RideStatus {
  accepted,
  enRoute,
  atPickup,
  inProgress,
  completed,
  cancelled
}

class Maps extends StatefulWidget {
  final bool isDriverOnline;
  final bool hasAcceptedBooking;
  final String customerName;
  final String pickupLocationName;
  final String destinationLocationName;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final int selectedIndex;
  final Function(Map<String, dynamic>) onCompletion;
  const Maps({
    super.key, 
    this.isDriverOnline = true,
    this.hasAcceptedBooking = true,
    this.customerName = "Customer Name",
    this.pickupLocationName = "Bhubaneswar",
    this.destinationLocationName = "Cuttack",
    this.pickupLocation = const LatLng(20.3590, 85.8277),
    this.destinationLocation = const LatLng(20.4590, 85.9077),
    this.selectedIndex = 2,
    required this.onCompletion, 
  });

  @override
  State<Maps> createState() => _MapsState();
}

class _MapsState extends State<Maps> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(20.3490, 85.8077);
  late LatLng _pickupLocation;
  late LatLng _destinationLocation;
  late String _customerName;
  late String _pickupLocationName;
  late String _destinationLocationName;
  late bool _isDriverOnline;
  late bool _hasAcceptedBooking;

  final List<http.Client> _httpClients = [];
  double _locationAccuracy = 0.0;
  bool _isDisposed = false;
  
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  PolylinePoints _polylinePoints = PolylinePoints();
  
  bool _isLoadingLocation = true;
  bool _isAtPickup = false;
  bool _isOtpVerified = false;
  String _otpInput = '';
  final String _correctOtp = '1234';
  double _sliderValue = 0.0;
  bool _isSliding = false;
  
  RideStatus _rideStatus = RideStatus.accepted;
  int _otpRetryCount = 0;
  final int _maxOtpRetries = 3;
  double _distance = 0.0;
  String _estimatedTime = '';
  double _estimatedEarnings = 0.0;
  double _distanceToTarget = 0.0;
  String _rideId = '';
  bool _isNetworkAvailable = true;
  bool _isLoadingRoute = false;
  String? _googleMapsApiKey;
  
  StreamSubscription<Position>? _positionStream;
  final List<RideHistory> _rideHistory = [
    RideHistory(
      customerName: 'Guru Prasad Panda',
      pickupLocation: 'Bhubaneswar',
      dropLocation: 'Rourkela',
      date: '10 Jun 2025',
      amount: 3500.00,
      status: 'Completed',
    ),
  ];
  
  final double _totalEarnings = 45678.50;
  
  final List<MonthlyEarning> _monthlyEarnings = [
    MonthlyEarning(month: 'Mar', amount: 8500.75),
    MonthlyEarning(month: 'Apr', amount: 10200.25),
    MonthlyEarning(month: 'May', amount: 12450.50),
    MonthlyEarning(month: 'Jun', amount: 14527.00),
  ];

  bool _hasInitialized = false;

@override
void initState() {
  super.initState();
  _isDisposed = false;  
  
  WidgetsBinding.instance.addObserver(this);
  BackButtonInterceptor.add(_backButtonInterceptor);
  
  _pickupLocation = widget.pickupLocation;
  _destinationLocation = widget.destinationLocation;
  _customerName = widget.customerName;
  _pickupLocationName = widget.pickupLocationName;
  _destinationLocationName = widget.destinationLocationName;
  _isDriverOnline = widget.isDriverOnline;
  _hasAcceptedBooking = widget.hasAcceptedBooking;
  
  _rideId = _generateTrackingNumber();
  _calculateEstimatedEarnings();
  
  // NO context-dependent calls here!
  // Move them to didChangeDependencies
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  // Only initialize once
  if (!_hasInitialized) {
    _hasInitialized = true;
    
    // Now it's safe to call context-dependent methods
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEnvironment();
      _initializeMap();
      
      if (_isDriverOnline && _hasAcceptedBooking) {
        _loadOtpVerificationState();
        _startLocationStream();
      } else {
        _resetMapState();
      }
    });
  }
}

  // Safe setState method
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  void _cancelPendingRequests() {
    for (final client in _httpClients) {
      client.close();
    }
    _httpClients.clear();
  }

  void _clearTemporaryData() {
    // Clear any cached/temporary data
    _otpInput = '';
    _sliderValue = 0.0;
    _distance = 0.0;
    _estimatedTime = '';
    _estimatedEarnings = 0.0;
    _distanceToTarget = 0.0;
    _locationAccuracy = 0.0;
    
    // Clear API key from memory (security)
    _googleMapsApiKey = null;
  }

  void _stopLocationStream() {
    if (_positionStream != null) {
      _positionStream!.cancel();
      _positionStream = null;
    }
  }

  Future<void> _loadEnvironment() async {
    try {
      await dotenv.load();
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Google Maps API key not found in environment file');
      }
      
      _safeSetState(() {
        _googleMapsApiKey = apiKey;
      });
      
    } catch (e) {
      _showApiKeyError();
    }
  }

  void _showApiKeyError() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Maps API not configured. Please check your setup.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _loadEnvironment,
        ),
      ),
    );
  });
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and responding to user input
        _getCurrentLocation();
        _checkNetworkStatus();
        
        // Restart location stream with full accuracy if driver is active
        if (_isDriverOnline && _hasAcceptedBooking && !_isDisposed) {
          _startLocationStream();
        }
        break;
        
      case AppLifecycleState.inactive:
        // App is inactive (transitioning, phone call, etc.)
        // Don't stop location tracking completely, but reduce frequency
        // This state is usually temporary (phone calls, notifications, etc.)
        break;
        
      case AppLifecycleState.paused:
        // App is backgrounded but still running
        // Reduce location accuracy to save battery when backgrounded
        if (_positionStream != null) {
          _stopLocationStream();
          // Restart with lower accuracy for background tracking
          _startBackgroundLocationTracking();
        }
        break;
        
      case AppLifecycleState.detached:
        // App is being shut down
        _stopLocationStream();
        _cleanupResources();
        break;
        
      case AppLifecycleState.hidden:
        // App is hidden (minimized or obscured)
        // Similar to paused, but less aggressive
        break;
    }
  }

  // Background location tracking with reduced accuracy
  void _startBackgroundLocationTracking() {
    if (!mounted || !_isDriverOnline || !_hasAcceptedBooking || _isDisposed) {
      return;
    }

    try {
      LocationSettings backgroundSettings = LocationSettings(
        accuracy: LocationAccuracy.low, // Lower accuracy for background
        distanceFilter: 50, // Update only when moved 50 meters (vs 5-15m normally)
        timeLimit: const Duration(seconds: 30), // Longer timeout
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: backgroundSettings,
      ).listen(
        (Position position) {
          if (!mounted || _isDisposed) return;
          
          _safeSetState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _locationAccuracy = position.accuracy;
          });

          // Only essential updates in background
          _updateDistanceToTarget();
          _checkIfAtPickup();
          
          // Don't calculate routes in background to save battery/data
        },
        onError: (error) {
          // Handle background location errors silently
        },
        cancelOnError: false,
      );
      
    } catch (e) {
      // Handle error silently in background mode
    }
  }

  // Clean up resources when app is being terminated
  void _cleanupResources() {
    _stopLocationStream();
    _markers.clear();
    _polylines.clear();
    _polylineCoordinates.clear();
    _mapController?.dispose();
    _mapController = null;
  }

  Future<void> _initializeMap() async {
    await _checkLocationPermission();
    _getCurrentLocation();
    _checkNetworkStatus();
  }

  // Network connectivity check
  Future<void> _checkNetworkStatus() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com')).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );
      
      _safeSetState(() {
        _isNetworkAvailable = response.statusCode == 200;
      });
    } catch (e) {
      _safeSetState(() {
        _isNetworkAvailable = false;
      });
      _showNetworkErrorSnackbar();
    }
  }
  
  void _showNetworkErrorSnackbar() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No internet connection. Route calculation disabled.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _checkNetworkStatus,
        ),
      ),
    );
  });
}

  // Google Geocoding API integration
  Future<LatLng?> _geocodeAddress(String address) async {
    if (!_isNetworkAvailable || _googleMapsApiKey == null || _googleMapsApiKey!.isEmpty || _isDisposed) {
      return null;
    }
    
    final client = http.Client();
    _httpClients.add(client);
    
    try {
      final String url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_googleMapsApiKey';
      
      final response = await client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {
      // Handle geocoding error silently
    } finally {
      _httpClients.remove(client);
      client.close();
    }
    return null;
  }

  // Google Places API integration
  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    if (!_isNetworkAvailable || _googleMapsApiKey == null || _googleMapsApiKey!.isEmpty || _isDisposed) {
      return null;
    }
    
    final client = http.Client();
    _httpClients.add(client);
    
    try {
      final String url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,geometry,formatted_address,types'
          '&key=$_googleMapsApiKey';
      
      final response = await client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return data['result'];
        }
      }
    } catch (e) {
      // Handle places API error silently
    } finally {
      _httpClients.remove(client);
      client.close();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getDirectionsWithETA(LatLng origin, LatLng destination) async {
    if (_isDisposed || !_isNetworkAvailable || _googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      return null;
    }
    
    final client = http.Client();
    _httpClients.add(client); // Track the client
    
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$_googleMapsApiKey';
      
      final response = await client.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Extract polyline points
          final polylineString = route['overview_polyline']['points'];
          final List<LatLng> routePoints = _decodePolyline(polylineString);
          
          if (routePoints.isEmpty) {
            throw FormatException('No route points received');
          }
          
          return {
            'polylinePoints': routePoints,
            'distance': leg['distance']['text'],
            'duration': leg['duration']['text'],
            'durationValue': leg['duration']['value'], // in seconds
            'distanceValue': leg['distance']['value'], // in meters
            'trafficDuration': leg['duration_in_traffic']?['text'] ?? leg['duration']['text'],
            'trafficDurationValue': leg['duration_in_traffic']?['value'] ?? leg['duration']['value'],
          };
        } else {
          // Handle API errors
          final status = data['status'];
          final errorMessage = data['error_message'] ?? 'Unknown API error';
          throw Exception('Directions API error: $status - $errorMessage');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on TimeoutException {
      rethrow; // Let the calling method handle timeout
    } on FormatException {
      rethrow; // Let the calling method handle format errors
    } catch (e) {
      throw Exception('Directions API request failed: $e');
    } finally {
      _httpClients.remove(client);
      client.close();
    }
  }

  // Decode polyline string from Google Directions API
  List<LatLng> _decodePolyline(String polylineString) {
    List<LatLng> points = [];
    int index = 0, len = polylineString.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polylineString.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polylineString.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _startLocationStream() {
  // Cancel any existing stream
  _positionStream?.cancel();
  
  if (!mounted || !_isDriverOnline || !_hasAcceptedBooking || _isDisposed) {
    return;
  }

  try {
    // Configure location settings based on ride status
    LocationSettings locationSettings = LocationSettings(
      accuracy: _getLocationAccuracy(),
      distanceFilter: _getDistanceFilter(), // Only update when moved this distance
      timeLimit: const Duration(seconds: 15), // Timeout for each location request
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (!mounted || _isDisposed) return;
        
        // Store previous location for distance calculation
        final previousLocation = _currentLocation;
        
        _safeSetState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _locationAccuracy = position.accuracy;
          _updateMarkers();
        });

        // Update distance calculations
        _updateDistanceToTarget();
        _checkIfAtPickup();

        // Update camera if significant movement
        _updateCameraIfNeeded(previousLocation);

        // Get route only if needed
        if (!_isOtpVerified && _isNetworkAvailable) {
          _getDirectionsRoute();
        } else if (_isOtpVerified) {
          _clearRoutes();
        }

        // Show location accuracy warnings if needed
        _checkLocationAccuracy(position.accuracy);
      },
      onError: (error) {
        if (mounted && !_isDisposed) {
          _handleLocationStreamError(error);
        }
      },
      cancelOnError: false, // Keep stream alive even after errors
    );

    // REMOVE this line - it was causing the error:
    // _showSuccessSnackbar('Location tracking started');
    
  } catch (e) {
    if (mounted && !_isDisposed) {
      _showErrorSnackbar('Failed to start location tracking: ${e.toString()}');
    }
  }
}

  // Get location accuracy based on ride status
  LocationAccuracy _getLocationAccuracy() {
    switch (_rideStatus) {
      case RideStatus.atPickup:
      case RideStatus.inProgress:
        return LocationAccuracy.best; // Highest accuracy when active
      case RideStatus.enRoute:
        return LocationAccuracy.high; // High accuracy when driving
      default:
        return LocationAccuracy.medium; // Normal accuracy otherwise
    }
  }

  // Get distance filter based on ride status  
  int _getDistanceFilter() {
    switch (_rideStatus) {
      case RideStatus.atPickup:
        return 3; // Very sensitive when at pickup (3 meters)
      case RideStatus.inProgress:
        return 5; // Sensitive during ride (5 meters)
      case RideStatus.enRoute:
        if (_distanceToTarget < 500) {
          return 5; // More sensitive when close to pickup
        } else {
          return 15; // Less sensitive when far from pickup (15 meters)
        }
      default:
        return 10; // Default filter (10 meters)
    }
  }

  // Handle location stream errors
  void _handleLocationStreamError(dynamic error) {
    if (error is LocationServiceDisabledException) {
      _showErrorSnackbar('Location services are disabled. Please enable them.');
      _showLocationServiceDialog();
    } else if (error is PermissionDeniedException) {
      _showErrorSnackbar('Location permission denied. Please grant permission.');
      _showPermissionDeniedDialog();
    } else if (error is TimeoutException) {
      _showWarningSnackbar('Location update timed out. Retrying...');
      // Automatically restart stream after timeout
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isDisposed) _startLocationStream();
      });
    } else {
      _showErrorSnackbar('Location error: ${error.toString()}');
    }
  }

  // Update camera only if moved significantly
  void _updateCameraIfNeeded(LatLng previousLocation) {
    if (_mapController == null) return;
    
    // Calculate distance moved
    double distanceMoved = Geolocator.distanceBetween(
      previousLocation.latitude,
      previousLocation.longitude,
      _currentLocation.latitude,
      _currentLocation.longitude,
    );
    
    // Only update camera if moved more than 20 meters or if at pickup
    if (distanceMoved > 20 || _rideStatus == RideStatus.atPickup) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentLocation),
      );
    }
  }

  // Check location accuracy and warn user if too low
  void _checkLocationAccuracy(double accuracy) {
    if (accuracy > 50) { // More than 50 meters accuracy
      _showWarningSnackbar('GPS accuracy is low (${accuracy.toInt()}m). Move to open area for better signal.');
    }
  }
  
  void _updateDistanceToTarget() {
    final target = _isOtpVerified ? _destinationLocation : _pickupLocation;
    _safeSetState(() {
      _distanceToTarget = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        target.latitude,
        target.longitude,
      );
    });
  }
  
  void _showArrivalNotification() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have arrived at the pickup location! Please collect OTP from customer.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
  });
}

  void _resetMapState() {
    _safeSetState(() {
      _polylines.clear();
      _polylineCoordinates.clear();
      _isOtpVerified = false;
      _isAtPickup = false;
      _otpInput = '';
      _sliderValue = 0.0;
      _rideStatus = RideStatus.accepted;
      _otpRetryCount = 0;
      _distance = 0.0;
      _estimatedTime = '';
      _estimatedEarnings = 0.0;
    });
    
    _markers = {
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
    
    _clearOtpVerificationState();
  }

  void _checkIfAtPickup() {
    if (_isOtpVerified) return;
    
    double distanceInMeters = Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      _pickupLocation.latitude,
      _pickupLocation.longitude,
    );
    
    _safeSetState(() {
      _distanceToTarget = distanceInMeters;
    });
    
    // Check if within 100 meters of pickup location
    if (distanceInMeters <= 100 && !_isAtPickup) {
      _safeSetState(() {
        _isAtPickup = true;
        _rideStatus = RideStatus.atPickup;
      });
      _showArrivalNotification();
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await _showLocationServiceDialog();
        return;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      // If permission is already granted, return
      if (permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse) {
        return;
      }
      
      // Handle denied permissions
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (!mounted) return;
        
        if (permission == LocationPermission.denied) {
          await _showPermissionDeniedDialog();
          return;
        }
      }
      
      // Handle permanently denied
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await _showPermanentlyDeniedDialog();
      }
      
    } catch (e) {
      if (mounted) {
        _showLocationError('Failed to check location permissions');
      }
    }
  }

  Future<void> _saveOtpVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOtpVerified_${_customerName}_${_pickupLocationName}_$_destinationLocationName', _isOtpVerified);
    await prefs.setInt('rideStatus_$_rideId', _rideStatus.index);
  }

  Future<void> _loadOtpVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    _safeSetState(() {
      _isOtpVerified = prefs.getBool('isOtpVerified_${_customerName}_${_pickupLocationName}_$_destinationLocationName') ?? false;
      
      final savedRideStatusIndex = prefs.getInt('rideStatus_$_rideId');
      if (savedRideStatusIndex != null) {
        _rideStatus = RideStatus.values[savedRideStatusIndex];
      }
    });
    
    if (_isOtpVerified) {
      _safeSetState(() {
        _rideStatus = RideStatus.inProgress;
      });
      _updateMarkers();
      // Don't show routes when OTP is verified (after pickup)
      _clearRoutes();
    }
  }

  void _clearRoutes() {
    _safeSetState(() {
      _polylines.clear();
      _polylineCoordinates.clear();
    });
  }
  
  Future<void> _showLocationServiceDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Location Services Disabled',
          style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
        ),
        content: Text(
          'Location services are disabled. Please enable location services in your device settings to use the map features.',
          style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showPermissionDeniedDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Location Permission Required',
          style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
        ),
        content: Text(
          'This app needs location permission to show your position on the map and provide navigation services.',
          style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkLocationPermission(); 
            },
            child: Text('Try Again', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showPermanentlyDeniedDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Location Permission Required',
          style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
        ),
        content: Text(
          'Location permission is permanently denied. Please enable it in app settings.',
          style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Text('Open Settings', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted || _isDisposed) return; // Check if widget is still mounted
    
    _safeSetState(() {
      _isLoadingLocation = true;
    });

    try {
      // Step 1: Check if location services are enabled on device
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationServiceDialog();
        return;
      }

      // Step 2: Check app permissions
      LocationPermission permission = await Geolocator.checkPermission();
      
      // Step 3: Request permission if denied
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        // Still denied after request
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      // Step 4: Handle permanently denied
      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedDialog();
        return;
      }

      // Step 5: Get location (only if we have permission)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Add timeout
      );

      // Check if widget is still mounted before updating state
      if (!mounted || _isDisposed) return;

      _safeSetState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
        _isLoadingLocation = false;
      });

      // Only get routes if driver hasn't reached pickup yet AND we have network + API key
      if (_isDriverOnline && _hasAcceptedBooking && !_isOtpVerified && _isNetworkAvailable) {
        _getDirectionsRoute();
      } else if (_isOtpVerified) {
        // Clear routes after pickup
        _clearRoutes();
      }

      // Update camera
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15),
        );
      }

    } on TimeoutException catch (e) {
      _showLocationError('Location request timed out. Please try again.');
    } on LocationServiceDisabledException catch (e) {
      _showLocationServiceDialog();
    } on PermissionDeniedException catch (e) {
      _showPermissionDeniedDialog();
    } catch (e) {
      _showLocationError('Unable to get your location: ${e.toString()}');
    } finally {
      // Always stop loading, even if error occurs
      if (mounted && !_isDisposed) {
        _safeSetState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _showLocationError(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _getCurrentLocation,
        ),
      ),
    );
  });
}

  Future<void> _getDirectionsRoute() async {
    // Only proceed if we have network, API key, and haven't verified OTP
    if (_isDisposed || !_isNetworkAvailable || _googleMapsApiKey == null || _googleMapsApiKey!.isEmpty || _isOtpVerified) {
      return;
    }
    
    try {
      _safeSetState(() => _isLoadingRoute = true);
      
      // Only show route to pickup location, not destination
      final routeData = await _getDirectionsWithETA(_currentLocation, _pickupLocation)
          .timeout(const Duration(seconds: 15)); // Add timeout
      
      // Check if widget is still mounted before updating state
      if (routeData != null && mounted && !_isDisposed) {
        _safeSetState(() {
          _polylineCoordinates = routeData['polylinePoints'];
          _distance = routeData['distanceValue'].toDouble();
          _estimatedTime = routeData['trafficDuration']; // Use traffic-aware duration
          
          _calculateEstimatedEarnings();
          
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              points: _polylineCoordinates,
              width: 5,
            ),
          );
        });
        
        // Show success feedback for first route calculation
        if (_polylineCoordinates.isNotEmpty) {
          _showSuccessSnackbar('Route calculated successfully!');
        }
      } else if (mounted && !_isDisposed) {
        _showErrorSnackbar('Unable to calculate route. Please try again.');
      }
      
    } on TimeoutException catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('Route calculation timed out. Check your internet connection.');
      }
    } on FormatException catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('Invalid route data received. Please try again.');
      }
    } on Exception catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('Failed to calculate route: ${e.toString()}');
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted && !_isDisposed) {
        _safeSetState(() => _isLoadingRoute = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            _getDirectionsRoute();
          },
        ),
      ),
    );
  });
}

  void _showSuccessSnackbar(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  });
}

  void _showWarningSnackbar(String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  });
}
  
  void _calculateEstimatedEarnings() {
    double fare = 8000.00;
    fare += (_distance / 1000) * 10;
    
    // Parse estimated time if it's a string (from API)
    if (_estimatedTime.isNotEmpty) {
      final timeInMinutes = _parseTimeString(_estimatedTime);
      fare += timeInMinutes * 2;
    }
    
    _safeSetState(() {
      _estimatedEarnings = fare;
    });
  }
  
  double _parseTimeString(String timeString) {
    // Parse Google's time format (e.g., "15 mins", "1 hour 5 mins")
    double totalMinutes = 0;
    
    final hourMatch = RegExp(r'(\d+)\s*hour').firstMatch(timeString.toLowerCase());
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(timeString.toLowerCase());
    
    if (hourMatch != null) {
      totalMinutes += double.parse(hourMatch.group(1)!) * 60;
    }
    if (minMatch != null) {
      totalMinutes += double.parse(minMatch.group(1)!);
    }
    
    return totalMinutes;
  }
  
  void _updateMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
    
    if (_isDriverOnline && _hasAcceptedBooking) {
      if (!_isOtpVerified) {
        // Show pickup marker only until OTP is verified
        _markers.add(
          Marker(
            markerId: const MarkerId('pickupLocation'),
            position: _pickupLocation,
            infoWindow: InfoWindow(title: 'Pickup: $_pickupLocationName'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    }
  }

  void _verifyOtp() {
    if (_otpInput == _correctOtp) {
      _safeSetState(() {
        _isOtpVerified = true;
        _rideStatus = RideStatus.inProgress;
        _otpRetryCount = 0;
      });
      _saveOtpVerificationState();
      _updateMarkers();
      
      // Clear routes after OTP verification
      _clearRoutes();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP verified successfully! Navigate to destination using your preferred navigation app.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      _handleOtpError();
    }
  }
  
  void _handleOtpError() {
    if (_otpRetryCount < _maxOtpRetries) {
      _safeSetState(() {
        _otpRetryCount++;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incorrect OTP. Attempt $_otpRetryCount of $_maxOtpRetries'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      _showOtpFailureDialog();
    }
  }
  
  Future<void> _showOtpFailureDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('OTP Verification Failed'),
        content: const Text('Please contact customer support or request the customer to generate a new OTP.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetOtpRetryCount();
            },
            child: Text('Try Again', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _contactCustomerSupport();
            },
            child: Text('Contact Support', style: TextStyle(fontSize: isLargeScreen ? 16 : 14)),
          ),
        ],
      ),
    );
  }
  
  void _resetOtpRetryCount() {
    _safeSetState(() {
      _otpRetryCount = 0;
      _otpInput = '';
    });
  }
  
  void _contactCustomerSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connecting to customer support...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _clearOtpVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isOtpVerified_${_customerName}_${_pickupLocationName}_$_destinationLocationName');
    await prefs.remove('rideStatus_$_rideId');
  }

  void _navigateBackToHome() {
    widget.onCompletion({
      'selectedIndex': 0,
      'resetRequest': false,
    });
    Navigator.of(context).pop();
  }
  
  String _generateTrackingNumber() {
    const String prefix = 'TRX';
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final String random = (1000 + Random().nextInt(9000)).toString();
    return '$prefix$timestamp$random';
  }

  Future<void> _showCompletionDialog() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    _safeSetState(() {
      _rideStatus = RideStatus.completed;
    });

    _clearOtpVerificationState();

    final newRide = RideHistory(
      customerName: _customerName,
      pickupLocation: _pickupLocationName,
      dropLocation: _destinationLocationName,
      date: '${DateTime.now().day} Jun 2025',
      amount: _estimatedEarnings,
      status: 'Completed',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              'Ride Completed!',
              style: TextStyle(fontSize: isLargeScreen ? 24 : 20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code,
                      size: 100,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Total is: ₹ ${_estimatedEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();

                  widget.onCompletion({
                    'selectedIndex': 0,
                    'resetRequest': true,
                    'newRideHistory': newRide,
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
void dispose() {
  // 1. Remove system observers
  WidgetsBinding.instance.removeObserver(this);
  BackButtonInterceptor.remove(_backButtonInterceptor);
  
  // 2. Cancel location tracking
  _stopLocationStream();
  _positionStream?.cancel();
  _positionStream = null;
  
  // 3. Dispose map controller
  _mapController?.dispose();
  _mapController = null;
  
  // 4. Clear all collections to free memory
  _markers.clear();
  _polylines.clear();
  _polylineCoordinates.clear();
  _rideHistory.clear();
  _monthlyEarnings.clear();
  
  // 5. Cancel any pending HTTP requests
  _cancelPendingRequests();
  
  // 6. Clear cached data
  _clearTemporaryData();
  
  // 7. Reset state variables to prevent callbacks
  _isDisposed = true;
  _hasInitialized = false; // Add this line
  
  // 8. Call super.dispose() last
  super.dispose();
}

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    _navigateBackToHome();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Navigation',
          style: TextStyle(
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBackToHome,
        ),
        actions: [
          if (_isLoadingRoute)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _safeSetState(() {
                _mapController = controller;
              });
              _getCurrentLocation();
            },
          ),
          if (_isLoadingLocation)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Network status indicator
          if (!_isNetworkAvailable)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Offline - Route calculation disabled',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _checkNetworkStatus,
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Location button
          Positioned(
            right: 16,
            bottom: isLargeScreen ? 40 : 30,
            child: FloatingActionButton(
              heroTag: "locationButton",
              mini: !isLargeScreen,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: Icon(
                Icons.my_location,
                color: Colors.black,
                size: isLargeScreen ? 28 : 24,
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _isDriverOnline && _hasAcceptedBooking ? 
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isOtpVerified) 
              if (_isAtPickup)
                // OTP Input UI
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.blue, width: 2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(isLargeScreen ? 20.0 : 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _customerName,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 24 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'At Pickup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isLargeScreen ? 14 : 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 20.0 : 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _pickupLocationName,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 18 : 16,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 12.0 : 8.0),
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.red,
                                size: isLargeScreen ? 24 : 20,
                              ),
                            ),
                            Text(
                              _destinationLocationName,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 18 : 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isLargeScreen ? 20 : 16),
                      CircleAvatar(
                        radius: isLargeScreen ? 40 : 30,
                        backgroundColor: Colors.grey,
                        child: Icon(
                          Icons.person,
                          size: isLargeScreen ? 50 : 40,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isLargeScreen ? 20 : 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 20.0 : 16.0),
                        child: Text(
                          "Enter OTP to start ride",
                          style: TextStyle(
                            fontSize: isLargeScreen ? 18 : 16,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(isLargeScreen ? 20.0 : 16.0),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: isLargeScreen ? 20 : 18),
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                              borderSide: BorderSide.none,
                            ),
                            hintText: "Ask customer for OTP",
                          ),
                          onChanged: (value) {
                            _safeSetState(() {
                              _otpInput = value;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: isLargeScreen ? 20.0 : 16.0,
                          left: isLargeScreen ? 20.0 : 16.0,
                          right: isLargeScreen ? 20.0 : 16.0,
                        ),
                        child: Row(
                          children: [
                            if (_otpRetryCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Text(
                                  'Attempt ${_otpRetryCount + 1} of ${_maxOtpRetries + 1}',
                                  style: TextStyle(
                                    color: _otpRetryCount >= _maxOtpRetries ? Colors.red : Colors.orange,
                                    fontSize: isLargeScreen ? 14 : 12,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _verifyOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 16 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                                    ),
                                  ),
                                  child: Text(
                                    'Verify OTP',
                                    style: TextStyle(fontSize: isLargeScreen ? 18 : 16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Navigation to pickup UI
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: Colors.green, width: 2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isLargeScreen ? 20.0 : 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.navigation,
                                  color: Colors.green,
                                  size: isLargeScreen ? 30 : 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Navigating to pickup",
                                  style: TextStyle(
                                    fontSize: isLargeScreen ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "${(_distanceToTarget / 1000).toStringAsFixed(1)} km away",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeScreen ? 16 : 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text("Customer: $_customerName"),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Text("Pickup: $_pickupLocationName"),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.flag, size: 16, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Text("Destination: $_destinationLocationName"),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 16, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text("ETA: ${_estimatedTime.isNotEmpty ? _estimatedTime : 'Calculating...'}"),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "You'll be prompted to enter OTP when you reach the pickup location",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isLargeScreen ? 14 : 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
            else
              // Slide to end ride UI (when OTP verified)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 12.0 : 8.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivering to $_destinationLocationName',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isLargeScreen ? 16 : 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'In Progress',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isLargeScreen ? 14 : 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Use your preferred navigation app to reach the destination',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isLargeScreen ? 14 : 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 20.0 : 16.0,
                        vertical: isLargeScreen ? 12.0 : 8.0,
                      ),
                      child: Container(
                        height: isLargeScreen ? 60 : 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(isLargeScreen ? 30 : 25),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: screenWidth * _sliderValue,
                              height: isLargeScreen ? 60 : 50,
                              decoration: BoxDecoration(
                                color: _isSliding ? Colors.blue : Colors.green,
                                borderRadius: BorderRadius.circular(isLargeScreen ? 30 : 25),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              height: isLargeScreen ? 60 : 50,
                              alignment: Alignment.center,
                              child: Text(
                                _sliderValue > 0.9 ? 'Completing ride...' : 'Slide to end ride',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: _sliderValue > 0.5 ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            Positioned(
                              left: (screenWidth - (isLargeScreen ? 40.0 : 32.0)) * _sliderValue - (isLargeScreen ? 30.0 : 25.0),
                              top: 0,
                              child: GestureDetector(
                                onHorizontalDragStart: (details) {
                                  _safeSetState(() {
                                    _isSliding = true;
                                  });
                                },
                                onHorizontalDragUpdate: (details) {
                                  final newValue = _sliderValue + details.delta.dx / (screenWidth - (isLargeScreen ? 40.0 : 32.0));
                                  _safeSetState(() {
                                    _sliderValue = newValue.clamp(0.0, 1.0);
                                  });
                                  
                                  if (_sliderValue >= 0.75) {
                                    _safeSetState(() {
                                      _sliderValue = 1.0; 
                                    });
                                    
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      _showCompletionDialog();
                                    });
                                  }
                                },
                                onHorizontalDragEnd: (details) {
                                  _safeSetState(() {
                                    _isSliding = false;
                                    if (_sliderValue < 0.75) {
                                      _sliderValue = 0.0; 
                                    }
                                  });
                                },
                                child: Container(
                                  width: isLargeScreen ? 60 : 50,
                                  height: isLargeScreen ? 60 : 50,
                                  decoration: BoxDecoration(
                                    color: _isSliding ? Colors.blue : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: _isSliding ? Colors.white : Colors.green,
                                    size: isLargeScreen ? 30 : 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ) : null,
    );
  }
}