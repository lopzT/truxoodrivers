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
  // Map Controllers
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(20.3490, 85.8077);
  
  // Booking Details
  late LatLng _pickupLocation;
  late LatLng _destinationLocation;
  late String _customerName;
  late String _pickupLocationName;
  late String _destinationLocationName;
  late bool _isDriverOnline;
  late bool _hasAcceptedBooking;

  // Network & API
  final List<http.Client> _httpClients = [];
  double _locationAccuracy = 0.0;
  bool _isDisposed = false;
  String? _googleMapsApiKey;
  bool _isNetworkAvailable = true;
  bool _isLoadingRoute = false;
  
  // Map UI Elements
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  PolylinePoints _polylinePoints = PolylinePoints();
  final Map<String, List<LatLng>> _polylineCache = {};
  
  // Status Flags
  bool _isLoadingLocation = true;
  bool _isAtPickup = false;
  bool _isOtpVerified = false;
  bool _isSliding = false;
  bool _isVerifyingOtp = false;
  bool _hasInitialized = false;
  
  // OTP & Ride Management
  String _otpInput = '';
  final String _correctOtp = '1234';
  double _sliderValue = 0.0;
  RideStatus _rideStatus = RideStatus.accepted;
  int _otpRetryCount = 0;
  final int _maxOtpRetries = 3;
  
  // Tracking & Metrics
  double _distance = 0.0;
  String _estimatedTime = '';
  double _estimatedEarnings = 0.0;
  double _distanceToTarget = 0.0;
  String _rideId = '';
  
  // Location Stream Management
  StreamSubscription<Position>? _positionStream;
  Timer? _routeCalculationDebounce;
  int _locationRetryCount = 0;
  final int _maxLocationRetries = 3;
  
  // Ride History
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_hasInitialized) {
      _hasInitialized = true;
      
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
    _otpInput = '';
    _sliderValue = 0.0;
    _distance = 0.0;
    _estimatedTime = '';
    _estimatedEarnings = 0.0;
    _distanceToTarget = 0.0;
    _locationAccuracy = 0.0;
    _polylineCache.clear();
    _googleMapsApiKey = null;
  }

  void _stopLocationStream() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _loadEnvironment() async {
    try {
      // Environment is already loaded in main.dart
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
        // Add delay to ensure proper initialization
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _isDisposed) return;
          
          _getCurrentLocation();
          _checkNetworkStatus();
          
          if (_isDriverOnline && _hasAcceptedBooking) {
            _startLocationStream();
          }
        });
        break;
        
      case AppLifecycleState.inactive:
        break;
        
      case AppLifecycleState.paused:
        if (_positionStream != null) {
          _stopLocationStream();
          _startBackgroundLocationTracking();
        }
        break;
        
      case AppLifecycleState.detached:
        _stopLocationStream();
        _cleanupResources();
        break;
        
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _startBackgroundLocationTracking() {
    if (!mounted || !_isDriverOnline || !_hasAcceptedBooking || _isDisposed) {
      return;
    }

    try {
      LocationSettings backgroundSettings = LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 50,
        timeLimit: const Duration(seconds: 30),
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: backgroundSettings,
      ).listen(
        (Position position) {
          if (!mounted || _isDisposed) return;
          
          _updateLocationAndUI(position);
        },
        onError: (error) {
          // Handle silently in background
        },
        cancelOnError: false,
      );
      
    } catch (e) {
      // Handle silently
    }
  }

  void _cleanupResources() {
    _stopLocationStream();
    _markers.clear();
    _polylines.clear();
    _polylineCoordinates.clear();
    _polylineCache.clear();
    _mapController?.dispose();
    _mapController = null;
  }

  Future<void> _initializeMap() async {
    await _checkLocationPermission();
    _getCurrentLocation();
    _checkNetworkStatus();
  }

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

  Future<Map<String, dynamic>?> _getDirectionsWithETA(LatLng origin, LatLng destination) async {
    if (_isDisposed || !_isNetworkAvailable || _googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      return null;
    }
    
    final client = http.Client();
    _httpClients.add(client);
    
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
      
      if (!mounted || _isDisposed) return null;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final polylineString = route['overview_polyline']['points'];
          final List<LatLng> routePoints = _decodePolyline(polylineString);
          
          if (routePoints.isEmpty) {
            throw FormatException('No route points received');
          }
          
          return {
            'polylinePoints': routePoints,
            'distance': leg['distance']['text'],
            'duration': leg['duration']['text'],
            'durationValue': leg['duration']['value'],
            'distanceValue': leg['distance']['value'],
            'trafficDuration': leg['duration_in_traffic']?['text'] ?? leg['duration']['text'],
            'trafficDurationValue': leg['duration_in_traffic']?['value'] ?? leg['duration']['value'],
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      _httpClients.remove(client);
      client.close();
    }
  }

  List<LatLng> _decodePolyline(String polylineString) {
    // Check cache first
    if (_polylineCache.containsKey(polylineString)) {
      return _polylineCache[polylineString]!;
    }
    
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
    
    // Cache the result
    _polylineCache[polylineString] = points;
    
    // Limit cache size
    if (_polylineCache.length > 10) {
      _polylineCache.remove(_polylineCache.keys.first);
    }
    
    return points;
  }

  void _startLocationStream() {
    _stopLocationStream();
    _locationRetryCount = 0;
    
    if (!mounted || !_isDriverOnline || !_hasAcceptedBooking || _isDisposed) {
      return;
    }

    try {
      LocationSettings locationSettings = LocationSettings(
        accuracy: _getLocationAccuracy(),
        distanceFilter: _getDistanceFilter(),
        timeLimit: const Duration(seconds: 15),
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          if (!mounted || _isDisposed) return;
          
          _updateLocationAndUI(position);
        },
        onError: (error) {
          if (mounted && !_isDisposed) {
            _handleLocationStreamError(error);
          }
        },
        cancelOnError: false,
      );
      
    } catch (e) {
      if (mounted && !_isDisposed) {
        _showErrorSnackbar('Failed to start location tracking: ${e.toString()}');
      }
    }
  }

  void _updateLocationAndUI(Position position) {
    if (!mounted || _isDisposed) return;
    
    final previousLocation = _currentLocation;
    final newLocation = LatLng(position.latitude, position.longitude);
    
    // Batch state updates
    _safeSetState(() {
      _currentLocation = newLocation;
      _locationAccuracy = position.accuracy;
      _updateMarkers();
    });
    
    // Perform non-state operations outside setState
    _updateDistanceToTarget();
    _checkIfAtPickup();
    _updateCameraIfNeeded(previousLocation);
    
    // Handle route updates with debouncing
    if (!_isOtpVerified && _isNetworkAvailable) {
      _getDirectionsRoute();
    } else if (_isOtpVerified) {
      _clearRoutes();
    }
    
    _checkLocationAccuracy(position.accuracy);
  }

  LocationAccuracy _getLocationAccuracy() {
    switch (_rideStatus) {
      case RideStatus.atPickup:
      case RideStatus.inProgress:
        return LocationAccuracy.best;
      case RideStatus.enRoute:
        return LocationAccuracy.high;
      default:
        return LocationAccuracy.medium;
    }
  }

  int _getDistanceFilter() {
    switch (_rideStatus) {
      case RideStatus.atPickup:
        return 3;
      case RideStatus.inProgress:
        return 5;
      case RideStatus.enRoute:
        if (_distanceToTarget < 500) {
          return 5;
        } else {
          return 15;
        }
      default:
        return 10;
    }
  }

  void _handleLocationStreamError(dynamic error) {
    if (!mounted || _isDisposed) return;
    
    if (error is LocationServiceDisabledException) {
      _showErrorSnackbar('Location services are disabled. Please enable them.');
      _showLocationServiceDialog();
    } else if (error is PermissionDeniedException) {
      _showErrorSnackbar('Location permission denied. Please grant permission.');
      _showPermissionDeniedDialog();
    } else if (error is TimeoutException) {
      if (_locationRetryCount < _maxLocationRetries) {
        _locationRetryCount++;
        final delay = Duration(seconds: _locationRetryCount * 2);
        _showWarningSnackbar('Location update timed out. Retrying in ${delay.inSeconds} seconds...');
        
        Future.delayed(delay, () {
          if (mounted && !_isDisposed) _startLocationStream();
        });
      } else {
        _showErrorSnackbar('Unable to get location updates. Please check your settings.');
        _locationRetryCount = 0;
      }
    } else {
      _showErrorSnackbar('Location error: ${error.toString()}');
    }
  }

  void _updateCameraIfNeeded(LatLng previousLocation) {
    if (_mapController == null) return;
    
    double distanceMoved = Geolocator.distanceBetween(
      previousLocation.latitude,
      previousLocation.longitude,
      _currentLocation.latitude,
      _currentLocation.longitude,
    );

    if (distanceMoved > 20 || _rideStatus == RideStatus.atPickup) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentLocation),
      );
    }
  }

  void _checkLocationAccuracy(double accuracy) {
    if (accuracy > 50) {
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse) {
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (!mounted) return;
        
        if (permission == LocationPermission.denied) {
          await _showPermissionDeniedDialog();
          return;
        }
      }

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
    if (!mounted || _isDisposed) return;
    
    _safeSetState(() {
      _isLoadingLocation = true;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationServiceDialog();
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedDialog();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted || _isDisposed) return;

      _safeSetState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
        _isLoadingLocation = false;
      });

      if (_isDriverOnline && _hasAcceptedBooking && !_isOtpVerified && _isNetworkAvailable) {
        _getDirectionsRoute();
      } else if (_isOtpVerified) {
        _clearRoutes();
      }

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
    // Cancel previous debounce
    _routeCalculationDebounce?.cancel();
    
    // Debounce route calculations
    _routeCalculationDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (_isDisposed || !_isNetworkAvailable || _googleMapsApiKey == null || 
          _googleMapsApiKey!.isEmpty || _isOtpVerified) {
        return;
      }
      
      try {
        _safeSetState(() => _isLoadingRoute = true);
        
        final routeData = await _getDirectionsWithETA(_currentLocation, _pickupLocation)
            ?.timeout(const Duration(seconds: 15));
            
        if (routeData != null && mounted && !_isDisposed) {
          _safeSetState(() {
            _polylineCoordinates = routeData['polylinePoints'];
            _distance = routeData['distanceValue'].toDouble();
            _estimatedTime = routeData['trafficDuration'];
            
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

          if (_polylineCoordinates.isNotEmpty) {
            _showSuccessSnackbar('Route calculated successfully!');
          }
        }
      } on TimeoutException {
        if (mounted && !_isDisposed) {
          _showErrorSnackbar('Route calculation timed out. Check your internet connection.');
        }
      } catch (e) {
        if (mounted && !_isDisposed) {
          _showErrorSnackbar('Failed to calculate route. Please try again.');
        }
      } finally {
        if (mounted && !_isDisposed) {
          _safeSetState(() => _isLoadingRoute = false);
        }
      }
    });
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
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
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

    if (_estimatedTime.isNotEmpty) {
      final timeInMinutes = _parseTimeString(_estimatedTime);
      fare += timeInMinutes * 2;
    }
    
    _safeSetState(() {
      _estimatedEarnings = fare;
    });
  }
  
  double _parseTimeString(String timeString) {
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

  void _verifyOtp() async {
    if (_isVerifyingOtp) return;
    
    _safeSetState(() {
      _isVerifyingOtp = true;
    });
    
    // Simulate verification delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_otpInput == _correctOtp) {
      _safeSetState(() {
        _isOtpVerified = true;
        _rideStatus = RideStatus.inProgress;
        _otpRetryCount = 0;
      });
      _saveOtpVerificationState();
      _updateMarkers();
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
    
    _safeSetState(() {
      _isVerifyingOtp = false;
    });
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
    _isDisposed = true;
    
    // Cancel all timers and streams
    _routeCalculationDebounce?.cancel();
    _stopLocationStream();
    _positionStream?.cancel();
    _positionStream = null;
    
    // Clear collections
    _cancelPendingRequests();
    _markers.clear();
    _polylines.clear();
    _polylineCoordinates.clear();
    _polylineCache.clear();
    _rideHistory.clear();
    _monthlyEarnings.clear();
    
    // Dispose controllers
    _mapController?.dispose();
    _mapController = null;
    
    // Clear temporary data
    _clearTemporaryData();
    
    // Remove observers
    WidgetsBinding.instance.removeObserver(this);
    BackButtonInterceptor.remove(_backButtonInterceptor);
    
    _hasInitialized = false;
    
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
                                  onPressed: _isVerifyingOtp ? null : _verifyOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 16 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                                    ),
                                  ),
                                  child: _isVerifyingOtp 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
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