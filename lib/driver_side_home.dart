import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:truxoo_partners/map_driver.dart';
import 'package:truxoo_partners/services/notification_service.dart';
import 'onboarding_page.dart';
import 'my_accounts_driver.dart';
import 'history_driver.dart';
import 'track_truck_driver_side.dart';
import 'package:url_launcher/url_launcher.dart';
import 'license_image_screen.dart';
import 'chat_screen.dart'; 
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class DriverConstants {
  static const double mapHeightRatio = 0.35;
  static const double bookingSectionHeightRatio = 0.3;
  static const int maxVisibleRequests = 3;
  static const int carouselAutoScrollInterval = 3;
  static const Duration backPressThreshold = Duration(seconds: 2);
  static const double largeScreenBreakpoint = 600;
  static const String defaultTruckNumber = 'OD02AB1234';
  static const double appBarHeightRatio = 0.08;
  static const int demoBookingInterval = 45; // Added for demo timing
}

enum BookingStatus { pending, accepted, denied, completed, cancelled }

class BookingRequest {
  final String id;
  final String clientName;
  final String clientPhone; 
  final String pickupLocation;
  final String dropLocation;
  final String date;
  final DateTime timestamp;
  final BookingStatus status;

  BookingRequest({
    required this.id,
    required this.clientName,
    required this.clientPhone, 
    required this.pickupLocation,
    required this.dropLocation,
    required this.date,
    required this.timestamp,
    this.status = BookingStatus.pending,
  });
}
class ValidationHelper {
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^\+91[6-9]\d{9}$').hasMatch(phone);
  }
  
  static bool isValidTruckNumber(String truckNumber) {
    return RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(truckNumber);
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

class DriverError {
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ImageCacheManager {
  static final Map<String, ImageProvider> _cache = {};
  
  static ImageProvider getImage(String path, {bool isLocal = false}) {
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }
    
    final image = isLocal 
        ? FileImage(File(path))
        : AssetImage(path) as ImageProvider;
    
    _cache[path] = image;
    return image;
  }

  static void clearCache() {
    _cache.clear();
  }
}

class DriverDrawer extends StatelessWidget {
  final String displayName;
  final String truckNumber;
  final String displayProfilePicture;
  final bool isUsingLocalImage;
  final bool isLargeScreen;
  final VoidCallback onMyAccount;
  final VoidCallback onHistory;
  final VoidCallback onTrackTruck;
  final VoidCallback onNotificationSettings;
  final VoidCallback onLogout;

  const DriverDrawer({
    super.key,
    required this.displayName,
    required this.truckNumber,
    required this.displayProfilePicture,
    required this.isUsingLocalImage,
    required this.isLargeScreen,
    required this.onMyAccount,
    required this.onHistory,
    required this.onTrackTruck,
    required this.onNotificationSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItems(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            backgroundImage: ImageCacheManager.getImage(
              displayProfilePicture,
              isLocal: isUsingLocalImage,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,  
            style: TextStyle(
              color: Colors.white,
              fontSize: isLargeScreen ? 20 : 16,
            ),
          ),
          Text(
            truckNumber,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isLargeScreen ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItems(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('My Account'),
          onTap: onMyAccount,
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('History & Payments'),
          onTap: onHistory,
        ),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('Track the Truck'),
          onTap: onTrackTruck,
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          subtitle: Text(
            NotificationService.hasPermission ? 'Enabled' : 'Disabled',
            style: TextStyle(
              color: NotificationService.hasPermission ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
          onTap: onNotificationSettings,
        ),
        ListTile(
          leading: const Icon(Icons.question_answer),
          title: const Text('FAQs'),
          onTap: () async {
            Navigator.pop(context);
            final Uri url = Uri.parse('https://www.truxxo.com/faqs');
            _launchUrl(url, context, 'FAQ page');
          },
        ),
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Terms & Conditions'),
          onTap: () {
            Navigator.pop(context);
            final Uri url = Uri.parse('https://www.truxoo.com/terms');
            _launchUrl(url, context, 'Terms & Conditions page');
          },
        ),
        ListTile(
          leading: const Icon(Icons.support_agent),
          title: const Text('Helpline'),
          onTap: () {
            Navigator.pop(context);
            final Uri url = Uri.parse('https://www.truxoo.com/helpline');
            _launchUrl(url, context, 'Helpline page');
          },
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About Us'),
          onTap: () {
            Navigator.pop(context);
            final Uri url = Uri.parse('https://www.truxoo.com/about-us');
            _launchUrl(url, context, 'About Us page');
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log Out'),
          onTap: onLogout,
        ),
      ],
    );
  }

  Future<void> _launchUrl(Uri url, BuildContext context, String pageName) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        DriverError.showError(context, 'Could not open the $pageName');
      }
    } catch (e) {
      DriverError.showError(context, 'Error: ${e.toString()}');
    }
  }
}

class DriverSideHome extends StatefulWidget {
  final String truckNumber;
  
  const DriverSideHome({
    super.key, 
    this.truckNumber = DriverConstants.defaultTruckNumber,
  });

  @override
  State<DriverSideHome> createState() => _DriverSideHomeState();
}

class _DriverSideHomeState extends State<DriverSideHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isOnline = false;
  bool _isBothWays = false; 
  bool _isLoadingLocation = true;
  bool _isLoadingBookings = false;
  GoogleMapController? _mapController;
  BookingRequest? _acceptedRequest;
  bool _hasAcceptedBooking = false;
  int _selectedIndex = 0;
  
  final List<BookingRequest> _deniedRequests = [];
  final _driverName = "Soumesh Padhaya";
  final _driverPhone = "8875658758";
  final _driverEmail = "soush34@gmail.com";
  final _driverRating = 4.4;
  final String _profilePicture = 'assets/driver_image.webp';
  final String _truckType = "Open Truck";
  final String _truckCapacity = "10 Tons";
  final String _licenseNumber = "DL-0420110012345";
  final String _licenseExpiry = "10/05/2026";

  String? _updatedDriverName;
  String? _updatedDriverPhone;
  String? _updatedDriverEmail;
  String? _updatedProfilePicture;
  bool _isUsingLocalImage = false;
  
  String get displayName => _updatedDriverName ?? _driverName;
  String get displayPhone => _updatedDriverPhone ?? _driverPhone;
  String get displayEmail => _updatedDriverEmail ?? _driverEmail;
  String get displayProfilePicture => _updatedProfilePicture ?? _profilePicture;
  
  LatLng _currentLocation = const LatLng(20.3490, 85.8077);
  Set<Marker> _markers = {};

  final List<BookingRequest> bookingRequests = [
    BookingRequest(
      id: "1",
      clientName: "Guru Prasad Panda",
      clientPhone: "+919438166637",
      pickupLocation: "Bhubaneswar",
      dropLocation: "Rourkela",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "2",
      clientName: "John Doe",
      clientPhone: "+919876543210",
      pickupLocation: "Cuttack",
      dropLocation: "Puri",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "3",
      clientName: "Somesh Padhaya",
      clientPhone: "+919237153558",
      pickupLocation: "Khordha",
      dropLocation: "Balasore",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
  ];

  final List<BookingRequest> _demoBookings = [
    BookingRequest(
      id: "4",
      clientName: "Rajesh Kumar",
      clientPhone: "+919876543211",
      pickupLocation: "Saheed Nagar",
      dropLocation: "Patia",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "5",
      clientName: "Priya Sharma",
      clientPhone: "+919876543212",
      pickupLocation: "Khandagiri",
      dropLocation: "Kalinga Nagar",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "6",
      clientName: "Amit Patel",
      clientPhone: "+919876543213",
      pickupLocation: "Jaydev Vihar",
      dropLocation: "Infocity",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "7",
      clientName: "Sneha Das",
      clientPhone: "+919876543214",
      pickupLocation: "Old Town",
      dropLocation: "Chandrasekharpur",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "8",
      clientName: "Vikash Singh",
      clientPhone: "+919876543215",
      pickupLocation: "Rasulgarh",
      dropLocation: "Nayapalli",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "9",
      clientName: "Kavita Roy",
      clientPhone: "+919876543216",
      pickupLocation: "Mancheswar",
      dropLocation: "Sundarpada",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "10",
      clientName: "Manoj Mohanty",
      clientPhone: "+919876543217",
      pickupLocation: "Laxmisagar",
      dropLocation: "Baramunda",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
    BookingRequest(
      id: "11",
      clientName: "Sunita Jena",
      clientPhone: "+919876543218",
      pickupLocation: "Sisupalgarh",
      dropLocation: "Jatni",
      date: "10/2/25",
      timestamp: DateTime.now(),
    ),
  ];

  int _nextBookingIndex = 0;

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

  DateTime? _lastBackPressTime;

  final List<String> _carouselImages = [
    'assets/driver_image.webp',
    'assets/driver_image.webp',
    'assets/driver_image.webp',
    'assets/driver_image.webp',
  ];
  int _currentCarouselIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);
  Timer? _carouselTimer;
  Timer? _bookingSimulationTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _initializeNotifications();
    BackButtonInterceptor.add(_backButtonInterceptor);
    _startCarouselTimer();
    _startBookingSimulation();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      
      // Set context for navigation
      NotificationService.setContext(context);
      
      // Set callback for notification taps
      NotificationService.setNotificationTappedCallback((bookingId) {
        print('Notification tapped for booking: $bookingId');
        
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
      
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (!NotificationService.hasPermission) {
        final shouldRequest = await _showNotificationPermissionDialog();
        
        if (shouldRequest == true) {
          final granted = await NotificationService.requestPermission();
          
          if (mounted) {
            if (granted) {
              DriverError.showSuccess(context, 'Notifications enabled successfully');
              setState(() {});
            } else {
              DriverError.showError(context, 'Notification permission denied. You can enable it in settings.');
            }
          }
        }
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
      if (mounted) {
        DriverError.showError(context, 'Error enabling notifications');
      }
    }
  }

  Future<bool?> _showNotificationPermissionDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'Truxoo needs notification permission to alert you about new booking requests, even when the app is in the background.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationSettings() {
    Navigator.pop(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.notifications,
                color: NotificationService.hasPermission ? Colors.green : Colors.red,
              ),
              title: const Text('Booking Notifications'),
              subtitle: Text(
                NotificationService.hasPermission 
                    ? 'You will receive notifications for new booking requests'
                    : 'Tap to enable notifications for booking requests',
              ),
              trailing: Switch(
                value: NotificationService.hasPermission,
                onChanged: (value) async {
                  Navigator.of(context).pop();
                  if (value) {
                    await _requestNotificationPermission();
                  } else {
                    DriverError.showInfo(context, 'Please disable notifications from phone settings');
                  }
                },
              ),
              onTap: () async {
                Navigator.of(context).pop();
                if (!NotificationService.hasPermission) {
                  await _requestNotificationPermission();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(
      Duration(seconds: DriverConstants.carouselAutoScrollInterval), 
      (timer) {
        if (_currentCarouselIndex < _carouselImages.length - 1) {
          _currentCarouselIndex++;
        } else {
          _currentCarouselIndex = 0;
        }
        
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentCarouselIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn,
          );
        }
      }
    );
  }

  Future<void> _initializeApp() async {
    await _checkLocationPermission();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isLargeScreen = screenWidth > DriverConstants.largeScreenBreakpoint;
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(screenHeight, isLargeScreen),
      drawer: _buildDrawer(isLargeScreen),
      body: _buildBody(screenWidth, screenHeight, isLargeScreen),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  PreferredSizeWidget _buildAppBar(double screenHeight, bool isLargeScreen) {
    return PreferredSize(
      preferredSize: Size.fromHeight(screenHeight * DriverConstants.appBarHeightRatio),
      child: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: Colors.white,
            size: isLargeScreen ? 28 : 24,
          ),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: _showMiniProfileDialog, 
              child: Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      image: DecorationImage(
                        image: ImageCacheManager.getImage(
                          displayProfilePicture,
                          isLocal: _isUsingLocalImage,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? Colors.green : Colors.red,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                'Truxoo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLargeScreen ? 24 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isLargeScreen) {
    return DriverDrawer(
      displayName: displayName,
      truckNumber: widget.truckNumber,
      displayProfilePicture: displayProfilePicture,
      isUsingLocalImage: _isUsingLocalImage,
      isLargeScreen: isLargeScreen,
      onMyAccount: _navigateToMyAccount,
      onHistory: _navigateToHistory,
      onTrackTruck: () {
        Navigator.pop(context);
        Navigator.of(context).push<void>( 
          MaterialPageRoute(builder: (context) => const TrackTruck()),
        );
      },
      onNotificationSettings: _showNotificationSettings,
      onLogout: () {
        Navigator.pop(context);
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
          (Route<dynamic> route) => false,
        );
      },
    );
  }

  Widget _buildBody(double screenWidth, double screenHeight, bool isLargeScreen) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildMapSection(screenHeight),
            _buildControlButtons(screenWidth),
            _buildBookingHeader(isLargeScreen),
            _buildBookingContent(screenHeight, isLargeScreen),
            _buildPromotionsSection(isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(double screenHeight) {
    return SizedBox(
      height: screenHeight * DriverConstants.mapHeightRatio,
      width: double.infinity,
      child: Stack(
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
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
              });
              _getCurrentLocation();
            },
          ),
          if (_isLoadingLocation)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(
                Icons.my_location,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (_isOnline && _hasAcceptedBooking) {
                  _showCancelRideConfirmation();
                } else {
                  _toggleOnlineStatus();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isOnline ? 'Go-offline' : 'Go-live',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isBothWays = !_isBothWays;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBothWays ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isBothWays ? 'Both Ways' : 'Single Way'),
                  const SizedBox(width: 4),
                  Icon(
                    _isBothWays ? Icons.swap_horiz : Icons.arrow_forward,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleOnlineStatus() async {
    if (!_isOnline) {
      if (!NotificationService.hasPermission) {
        await _requestNotificationPermission();
      }
      
      setState(() {
        _isOnline = true;
      });
      
      _addInitialBookingsWhenOnline();
      await NotificationService.showOnlineStatusNotification(isOnline: true);
      DriverError.showSuccess(context, 'You are now online and available for bookings');
    } else {
      setState(() {
        _isOnline = false;
      });
      
      await NotificationService.showOnlineStatusNotification(isOnline: false);
      DriverError.showInfo(context, 'You are now offline');
    }
  }

  Widget _buildBookingHeader(bool isLargeScreen) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Booking',
          style: TextStyle(
            fontSize: isLargeScreen ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingContent(double screenHeight, bool isLargeScreen) {
    return SizedBox(
      height: screenHeight * DriverConstants.bookingSectionHeightRatio,
      child: _buildBookingSection(isLargeScreen),
    );
  }

  Widget _buildPromotionsSection(bool isLargeScreen) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Promotions',
              style: TextStyle(
                fontSize: isLargeScreen ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildImageCarousel(),
        ),
      ],
    );
  }

  Widget _buildBookingSection(bool isLargeScreen) {
    if (_isLoadingBookings) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.car_rental,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Go online to receive booking requests',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_hasAcceptedBooking && _acceptedRequest != null) {
      return _buildAcceptedBookingCard();
    }

    if (bookingRequests.isEmpty) {
      return Center(
        child: Text(
          'No pending requests!', 
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return _buildBookingRequestsList();
  }

  Widget _buildAcceptedBookingCard() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_acceptedRequest!.pickupLocation} → ${_acceptedRequest!.dropLocation}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _acceptedRequest!.clientName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Download Info'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Date: ${_acceptedRequest!.date}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_acceptedRequest?.clientPhone != null) {
                            _makePhoneCall(_acceptedRequest!.clientPhone);
                          } else {
                            DriverError.showError(context, 'Client phone number not available');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone, size: 18),
                            SizedBox(width: 4),
                            Text('Call'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                clientName: _acceptedRequest!.clientName,
                                clientPhone: _acceptedRequest!.clientPhone,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 18),
                            SizedBox(width: 4),
                            Text('Chat'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _cancelBooking,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('X Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingRequestsList() {
    List<BookingRequest> visibleRequests = [...bookingRequests];
    
    if (visibleRequests.length > DriverConstants.maxVisibleRequests) {
      visibleRequests = visibleRequests.sublist(0, DriverConstants.maxVisibleRequests);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: visibleRequests.length,
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final request = visibleRequests[index];
        return _buildBookingRequestCard(request);
      },
    );
  }

  Widget _buildBookingRequestCard(BookingRequest request) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.pickupLocation} → ${request.dropLocation}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.clientName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('Download Info'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Date: ${request.date}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _acceptBooking(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _denyBookingRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Deny'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.home, 'Home'),
          _buildNavItem(1, Icons.access_time, 'History'),
          _buildNavItem(2, Icons.location_on, 'Location'),
          _buildNavItem(3, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemCount: _carouselImages.length,
            itemBuilder: (context, index) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.8,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    _carouselImages[index],
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _carouselImages.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentCarouselIndex == entry.key
                    ? Colors.black
                    : Colors.grey.shade400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          DriverError.showError(context, 'Could not launch phone dialer');
        }
      }
    } catch (e) {
      if (mounted) {
        DriverError.showError(context, 'Error making call: $e');
      }
    }
  }

  Future<void> _navigateToMyAccount() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    final Map<String, dynamic>? result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MyAccountDriver(
          currentProfileImagePath: displayProfilePicture,
          isLocalImage: _isUsingLocalImage,
          driverName: displayName,
          driverPhone: displayPhone,
          driverEmail: displayEmail,
          driverRating: _driverRating.toString(),
          truckNumber: widget.truckNumber,
          truckType: _truckType,
          truckCapacity: _truckCapacity,
          licenseNumber: _licenseNumber,
          licenseExpiry: _licenseExpiry,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        if (result.containsKey('selectedIndex')) {
          _selectedIndex = result['selectedIndex'];
        }
        if (result['updatedProfile'] == true) {
          _updatedDriverName = result['driverName'] ?? _updatedDriverName;
          _updatedDriverPhone = result['driverPhone'] ?? _updatedDriverPhone;
          _updatedDriverEmail = result['driverEmail'] ?? _updatedDriverEmail;
          if (result['profileImagePath'] != null) {
            _updatedProfilePicture = result['profileImagePath'];
            _isUsingLocalImage = true;
          }
        }
      });
    }
  }

  Future<void> _showCancelRideConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Ongoing Ride?'),
          content: const Text(
            'You currently have an ongoing ride. Going offline will cancel this ride. Do you want to continue?'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isOnline = false;
                  _hasAcceptedBooking = false;
                  _acceptedRequest = null;
                });
                NotificationService.showOnlineStatusNotification(isOnline: false);
              },
              child: const Text('Yes, Cancel Ride'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToHistory() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    final Map<String, dynamic>? result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryDriver(
          rideHistory: _rideHistory,
          totalEarnings: _totalEarnings,
          monthlyEarnings: _monthlyEarnings,
        ),
      ),
    );
    if (result != null && result.containsKey('selectedIndex')) {
      setState(() {
        _selectedIndex = result['selectedIndex'];
      });
    }
  }
  
  void _showMiniProfileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mini Profile',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 40,
                  backgroundImage: ImageCacheManager.getImage(
                    displayProfilePicture,
                    isLocal: _isUsingLocalImage,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileInfoRow('Truck No.-', widget.truckNumber),
                const SizedBox(height: 8),
                _buildProfileInfoRow('PH No-', displayPhone),
                const SizedBox(height: 8),
                _buildProfileInfoRow('Email-', displayEmail),
                const SizedBox(height: 8),
                _buildProfileInfoRow('Rating-', '$_driverRating/5'),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openLicenseImage(context);
                  },
                  child: const Text(
                    'License',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await _showLocationServiceDialog();
        return;
      }

      var status = await Permission.location.status;
      
      if (status.isGranted) {
        return;
      }
      
      status = await Permission.location.request();
      
      if (!mounted) return; 
      
      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog();
      } else if (status.isDenied) {
        await _showPermissionDeniedDialog();
      }
    } catch (e) {
      print('Error checking location permission: $e');
    }
  }
  
  Future<void> _showLocationServiceDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
          'Location services are disabled. Please enable location services in your device settings to use the map features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showPermissionDeniedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to show your position on the map and provide navigation services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkLocationPermission(); 
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermanentlyDeniedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _updateMarker();
          _isLoadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  void _handleMapScreenCompletion(Map<String, dynamic> result) {
    if (mounted) {
      setState(() {
        if (result.containsKey('selectedIndex')) {
          _selectedIndex = result['selectedIndex'];
        }
        if (result['resetRequest'] == true) {
          _acceptedRequest = null;
          _hasAcceptedBooking = false;
        }
        if (result.containsKey('newRideHistory')) {
          final RideHistory newRide = result['newRideHistory'];
          _rideHistory.insert(0, newRide);
        }
      });
    }
  }

  void _updateMarker() {
    _markers = {
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: 'Current Location'),
      ),
    };
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _mapController?.dispose();
    _pageController.dispose();
    _carouselTimer?.cancel();
    _bookingSimulationTimer?.cancel();
    NotificationService.cancelAllNotifications();
    super.dispose();
  }

  void _acceptBooking(BookingRequest request) {
    setState(() {
      _acceptedRequest = request;
      _hasAcceptedBooking = true;
      bookingRequests.remove(request);
    });
    
    NotificationService.showBookingAcceptedNotification();
    DriverError.showSuccess(context, 'Booking accepted successfully!');
  }

  void _cancelBooking() {
    setState(() {
      _acceptedRequest = null;
      _hasAcceptedBooking = false;
    });
    DriverError.showInfo(context, 'Booking cancelled');
  }

  void _navigateToMap() {
    Navigator.push<void>( 
      context,
      MaterialPageRoute(
        builder: (context) => Maps(
          isDriverOnline: _isOnline,
          hasAcceptedBooking: _hasAcceptedBooking,
          customerName: _acceptedRequest?.clientName ?? "Customer Name",
          pickupLocationName: _acceptedRequest?.pickupLocation ?? "Pickup Location",
          destinationLocationName: _acceptedRequest?.dropLocation ?? "Destination",
          pickupLocation: const LatLng(20.3590, 85.8277),
          destinationLocation: const LatLng(20.4590, 85.9077),
          selectedIndex: 2,
          onCompletion: _handleMapScreenCompletion,
        ),
      ),
    );
  }
  
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break; 
      case 1:
        _navigateToHistory(); 
        break;
      case 2:
        _navigateToMap();
        break;
      case 3:
        _navigateToMyAccount(); 
        break;
    }
  }
    
  void _denyBookingRequest(BookingRequest request) {
    setState(() {
      bookingRequests.remove(request);
      _deniedRequests.add(request);
      
      if (_isOnline && _nextBookingIndex < _demoBookings.length) {
        final newBooking = _demoBookings[_nextBookingIndex];
        _nextBookingIndex++;
        
        bookingRequests.add(newBooking);
        
        NotificationService.showNewRideNotification(
          bookingId: newBooking.id,
        );
        
        _showInAppBookingNotification(newBooking);
      }
    });
    DriverError.showInfo(context, 'Booking request denied');
  }

  void _showInAppBookingNotification(BookingRequest request) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.notification_important,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🚛 New Booking Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.clientName}: ${request.pickupLocation} → ${request.dropLocation}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => overlayEntry.remove(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Timer(const Duration(seconds: 4), () {
      try {
        overlayEntry.remove();
      } catch (e) {
        // Overlay already removed
      }
    });
  }

  void _addInitialBookingsWhenOnline() {
    if (_isOnline && bookingRequests.length < DriverConstants.maxVisibleRequests) {
      setState(() {
        while (bookingRequests.length < DriverConstants.maxVisibleRequests && 
               _nextBookingIndex < _demoBookings.length) {
          bookingRequests.add(_demoBookings[_nextBookingIndex]);
          _nextBookingIndex++;
        }
      });
    }
  }

  void _startBookingSimulation() {
    _bookingSimulationTimer = Timer.periodic(
      Duration(seconds: DriverConstants.demoBookingInterval), 
      (timer) {
        if (_isOnline && 
            !_hasAcceptedBooking && 
            bookingRequests.isNotEmpty &&
            _nextBookingIndex < _demoBookings.length &&
            bookingRequests.length < DriverConstants.maxVisibleRequests + 1) {
          
          final newBooking = _demoBookings[_nextBookingIndex];
          _nextBookingIndex++;
          
          setState(() {
            bookingRequests.add(newBooking);
          });
          
          NotificationService.showNewRideNotification(
            bookingId: newBooking.id,
          );
          
          _showInAppBookingNotification(newBooking);
        }
      }
    );
  }
  
  void _openLicenseImage(BuildContext context) {
    final String licenseImageUrl = 'https://api.com/licensesimage/$_driverPhone';
    
    Navigator.push(
      context,
      MaterialPageRoute(
       builder: (context) => LicenseImageScreen(imageUrl: licenseImageUrl),
      ),
    );
  }

  void onNewBookingReceived(BookingRequest request) {
    NotificationService.showNewRideNotification(
      bookingId: request.id,
    );
    
    setState(() {
      bookingRequests.insert(0, request);
    });
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return true;
    }
    
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return true;
    }
    
    final now = DateTime.now();
    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > DriverConstants.backPressThreshold) {
      _lastBackPressTime = now;
      DriverError.showInfo(context, 'Press back again to exit');
      return true; 
    }
    SystemNavigator.pop();
    return true;
  }
}