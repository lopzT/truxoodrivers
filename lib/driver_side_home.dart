// lib/driver_side_home.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:truxoo_partners/map_driver.dart';
import 'package:truxoo_partners/services/notification_service.dart';
import 'package:truxoo_partners/services/driver_data_service.dart';
import 'package:truxoo_partners/models/booking_request.dart' as model;
import 'onboarding_page.dart';
import 'my_accounts_driver.dart';
import 'history_driver.dart';
import 'track_truck.dart';
import 'package:url_launcher/url_launcher.dart';
import 'license_image_screen.dart';
import 'chat_screen.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:open_file/open_file.dart';

class DriverConstants {
  static const double mapHeightRatio = 0.35;
  static const double bookingSectionHeightRatio = 0.3;
  static const int maxVisibleRequests = 3;
  static const int carouselAutoScrollInterval = 3;
  static const Duration backPressThreshold = Duration(seconds: 2);
  static const double largeScreenBreakpoint = 600;
  static const String defaultTruckNumber = 'OD02AB1234';
  static const double appBarHeightRatio = 0.08;
  static const int demoBookingInterval = 45;
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

  static ImageProvider getImage(String path,
      {bool isLocal = false, bool isNetwork = false}) {
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }

    ImageProvider image;
    if (isNetwork) {
      image = NetworkImage(path);
    } else if (isLocal) {
      image = FileImage(File(path));
    } else {
      image = AssetImage(path);
    }

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
  final bool isNetworkImage;
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
    this.isNetworkImage = false,
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
            backgroundImage: _getProfileImage(),
            child: displayProfilePicture.isEmpty
                ? const Icon(Icons.person, size: 30, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            displayName.isNotEmpty ? displayName : 'Driver',
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

  ImageProvider? _getProfileImage() {
    if (displayProfilePicture.isEmpty) return null;

    return ImageCacheManager.getImage(
      displayProfilePicture,
      isLocal: isUsingLocalImage,
      isNetwork: isNetworkImage,
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
              color:
                  NotificationService.hasPermission ? Colors.green : Colors.red,
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
  final String? truckNumber;

  const DriverSideHome({
    super.key,
    this.truckNumber,
  });

  @override
  State<DriverSideHome> createState() => _DriverSideHomeState();
}

class _DriverSideHomeState extends State<DriverSideHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Online/Offline status
  bool _isOnline = false;
  bool _isBothWays = false;
  bool _isLoadingLocation = true;
  bool _isLoadingBookings = false;
  bool _isLoadingProfile = true;
  bool _isDownloadingInfo = false;

  GoogleMapController? _mapController;
  model.BookingRequest? _acceptedRequest;
  bool _hasAcceptedBooking = false;
  int _selectedIndex = 0;

  // Booking streams
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSubscription;
  StreamSubscription<DocumentSnapshot?>? _acceptedBookingSubscription;
  List<model.BookingRequest> _pendingBookings = [];

  // ========== DRIVER INFO FROM FIREBASE ==========
  String _driverName = "";
  String _driverPhone = "";
  String _driverEmail = "";
  double _driverRating = 0.0;
  String _profilePicture = "";
  String _truckNumber = "";
  String _truckType = "";
  String _truckModel = "";
  String _licenseNumber = "";
  String _licensePhotoUrl = "";
  String _licenseExpiry = "";
  String _state = "";
  String _city = "";
  bool _isNetworkImage = false;

  // Local updates (from edit profile)
  String? _updatedDriverName;
  String? _updatedDriverPhone;
  String? _updatedDriverEmail;
  String? _updatedProfilePicture;
  bool _isUsingLocalImage = false;

  // Getters for display
  String get displayName => _updatedDriverName ?? _driverName;
  String get displayPhone => _updatedDriverPhone ?? _driverPhone;
  String get displayEmail => _updatedDriverEmail ?? _driverEmail;
  String get displayProfilePicture => _updatedProfilePicture ?? _profilePicture;
  String get displayTruckNumber => widget.truckNumber ?? _truckNumber;

  LatLng _currentLocation = const LatLng(20.3490, 85.8077);
  Set<Marker> _markers = {};

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

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _initializeApp();
    _initializeNotifications();
    _checkExistingOnlineStatus();
    BackButtonInterceptor.add(_backButtonInterceptor);
    _startCarouselTimer();
  }

  /// Check if driver was already online
  Future<void> _checkExistingOnlineStatus() async {
    final isOnline = await DriverDataService.getOnlineStatus();
    if (isOnline && mounted) {
      setState(() {
        _isOnline = true;
      });
      _startListeningToBookings();
      _startListeningToAcceptedBooking();
    }
  }

  /// Start listening to available booking requests
  void _startListeningToBookings() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription =
        DriverDataService.getAvailableBookingsStream().listen(
      (bookings) {
        if (mounted) {
          setState(() {
            _pendingBookings = bookings
                .map((data) => model.BookingRequest.fromMap(data['id'], data))
                .toList();
          });

          // Show notification for new bookings
          if (bookings.isNotEmpty && _pendingBookings.length < bookings.length) {
            final newBooking = model.BookingRequest.fromMap(
                bookings.first['id'], bookings.first);
            NotificationService.showNewRideNotification(
              bookingId: newBooking.id,
            );
            _showInAppBookingNotification(newBooking);
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Error listening to bookings: $error');
      },
    );
  }

  /// Start listening to accepted booking
  void _startListeningToAcceptedBooking() {
    _acceptedBookingSubscription?.cancel();
    _acceptedBookingSubscription =
        DriverDataService.getAcceptedBookingStream().listen(
      (snapshot) {
        if (mounted) {
          if (snapshot != null && snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            setState(() {
              _acceptedRequest =
                  model.BookingRequest.fromMap(snapshot.id, data);
              _hasAcceptedBooking = true;
            });
          } else {
            setState(() {
              _acceptedRequest = null;
              _hasAcceptedBooking = false;
            });
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Error listening to accepted booking: $error');
      },
    );
  }

  /// Stop listening to booking streams
  void _stopListeningToBookings() {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = null;
    _acceptedBookingSubscription?.cancel();
    _acceptedBookingSubscription = null;
  }

    Future<void> _loadDriverProfile() async {
    setState(() => _isLoadingProfile = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        debugPrint('⚠️ No current user found');
        setState(() => _isLoadingProfile = false);
        // Redirect to login logic here...
        return;
      }

      final uid = currentUser.uid;
      debugPrint('📱 Loading profile for UID: $uid');

      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'truxoodriver',
      );

      // 1. Try to get driver document with current UID
      DocumentSnapshot doc = await firestore.collection('drivers').doc(uid).get();

      // 2. If not found, try by phone number (Migration Logic)
      if (!doc.exists) {
        String? phoneNumber = currentUser.phoneNumber;
        
        if (phoneNumber != null) {
          debugPrint('🔍 Document not found for UID. Searching by phone: $phoneNumber');
          
          final querySnapshot = await firestore
              .collection('drivers')
              .where('phoneNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            debugPrint('✅ Found old driver profile. Migrating to new UID...');
            final oldDoc = querySnapshot.docs.first;
            final oldData = oldDoc.data();
            
            // 3. Create the new document with the correct UID
            await firestore.collection('drivers').doc(uid).set({
              ...oldData,
              'uid': uid, // Update the stored UID
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            
            // 4. Fetch the newly created document
            doc = await firestore.collection('drivers').doc(uid).get();
            debugPrint('✅ Migration successful!');
          }
        }
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('✅ Driver profile loaded: ${data['name']}');

        if (mounted) {
          setState(() {
            _driverName = data['name'] ?? '';
            _driverPhone = _formatPhoneNumber(data['phoneNumber'] ?? '');
            _driverEmail = data['email'] ?? '';
            _driverRating = (data['rating'] ?? 0.0).toDouble();
            _profilePicture = data['profilePhotoUrl'] ?? '';
            _truckNumber = data['truckNumber'] ?? '';
            _truckType = data['truckType'] ?? '';
            _truckModel = data['truckModel'] ?? '';
            _licenseNumber = data['licenseNumber'] ?? '';
            _licenseExpiry = data['licenseExpiry'] ?? '';
            _licensePhotoUrl = data['licensePhotoUrl'] ?? '';
            _state = data['state'] ?? '';
            _city = data['city'] ?? '';
            _isNetworkImage = _profilePicture.isNotEmpty &&
                (_profilePicture.startsWith('http://') ||
                    _profilePicture.startsWith('https://'));
            _isLoadingProfile = false;
          });
        }
      } else {
        debugPrint('⚠️ No driver profile found (New User?)');
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }
  String _formatPhoneNumber(String phone) {
    if (phone.startsWith('+91')) {
      return phone.substring(3);
    }
    return phone;
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      NotificationService.setContext(context);
      NotificationService.setNotificationTappedCallback((bookingId) {
        debugPrint('Notification tapped for booking: $bookingId');
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
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
              DriverError.showSuccess(
                  context, 'Notifications enabled successfully');
              setState(() {});
            } else {
              DriverError.showError(context,
                  'Notification permission denied. You can enable it in settings.');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
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
                color: NotificationService.hasPermission
                    ? Colors.green
                    : Colors.red,
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
                    DriverError.showInfo(context,
                        'Please disable notifications from phone settings');
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
        Duration(seconds: DriverConstants.carouselAutoScrollInterval), (timer) {
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
    });
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
      preferredSize:
          Size.fromHeight(screenHeight * DriverConstants.appBarHeightRatio),
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
                      color: Colors.grey[300],
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(40),
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

  Widget _buildProfileImage(double size) {
    if (_isLoadingProfile) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final imageUrl = displayProfilePicture;

    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[300],
        child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
      );
    }

    if (_isUsingLocalImage && _updatedProfilePicture != null) {
      return Image.file(
        File(_updatedProfilePicture!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child:
                Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
          );
        },
      );
    }

    if (_isNetworkImage || imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: Colors.grey[300],
            child:
                Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
          );
        },
      );
    }

    return Image.asset(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: Colors.grey[300],
          child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
        );
      },
    );
  }

  Widget _buildDrawer(bool isLargeScreen) {
    return DriverDrawer(
      displayName: displayName.isNotEmpty ? displayName : 'Driver',
      truckNumber: displayTruckNumber,
      displayProfilePicture: displayProfilePicture,
      isUsingLocalImage: _isUsingLocalImage,
      isNetworkImage: _isNetworkImage,
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
      onLogout: _handleLogout,
    );
  }

  void _handleLogout() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Set offline before logout
              if (_isOnline) {
                await DriverDataService.updateOnlineStatus(false);
              }

              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                debugPrint('Error signing out: $e');
              }

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil<void>(
                  MaterialPageRoute(
                      builder: (context) => const OnboardingPage()),
                  (Route<dynamic> route) => false,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      double screenWidth, double screenHeight, bool isLargeScreen) {
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
          // === Button 1: Online/Offline ===
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
                elevation: 2,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isOnline ? 'Go-offline' : 'Go-live',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // === Button 2: Route Type ===
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
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Keep content centered tightly
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isBothWays ? 'Both Ways' : 'Single Way',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Increased spacing slightly
                  Icon(
                    _isBothWays ? Icons.swap_horiz : Icons.arrow_forward,
                    size: 20,
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
      // Going online
      setState(() {
        _isLoadingBookings = true;
      });

      if (!NotificationService.hasPermission) {
        await _requestNotificationPermission();
      }

      // Update Firebase first
      final success = await DriverDataService.updateOnlineStatus(true);

      if (success) {
        setState(() {
          _isOnline = true;
          _isLoadingBookings = false;
        });

        // Start listening to bookings
        _startListeningToBookings();
        _startListeningToAcceptedBooking();

        await NotificationService.showOnlineStatusNotification(isOnline: true);
        DriverError.showSuccess(
            context, 'You are now online and available for bookings');
      } else {
        setState(() {
          _isLoadingBookings = false;
        });
        DriverError.showError(context, 'Failed to go online. Please try again.');
      }
    } else {
      // Going offline
      setState(() {
        _isOnline = false;
        _pendingBookings = [];
      });

      _stopListeningToBookings();

      await DriverDataService.updateOnlineStatus(false);
      await NotificationService.showOnlineStatusNotification(isOnline: false);
      DriverError.showInfo(context, 'You are now offline');
    }
  }

  Widget _buildBookingHeader(bool isLargeScreen) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Row(
        children: [
          Text(
            'Booking',
            style: TextStyle(
              fontSize: isLargeScreen ? 22 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isOnline && _pendingBookings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingBookings.length} pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading bookings...'),
          ],
        ),
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
            const SizedBox(height: 8),
            Text(
              'Tap "Go-live" to start accepting rides',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_hasAcceptedBooking && _acceptedRequest != null) {
      return _buildAcceptedBookingCard();
    }

    if (_pendingBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New booking requests will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
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
            side: const BorderSide(color: Colors.green, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✓ ACCEPTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    // Client Photo
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _acceptedRequest!.clientPhoto.isNotEmpty
                          ? NetworkImage(_acceptedRequest!.clientPhoto)
                          : null,
                      child: _acceptedRequest!.clientPhoto.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _acceptedRequest!.clientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_acceptedRequest!.pickupLocation} → ${_acceptedRequest!.dropLocation}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'download') {
                          await _downloadBookingInfo(_acceptedRequest!.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download, size: 20),
                              SizedBox(width: 8),
                              Text('Download Info'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Details Row
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Date: ${_acceptedRequest!.date}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_acceptedRequest!.estimatedFare != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.currency_rupee,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '₹${_acceptedRequest!.estimatedFare!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_acceptedRequest?.clientPhone != null) {
                            _makePhoneCall(_acceptedRequest!.clientPhone);
                          } else {
                            DriverError.showError(
                                context, 'Client phone number not available');
                          }
                        },
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
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
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _cancelAcceptedBooking,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel Booking'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
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
    final visibleRequests = _pendingBookings.length >
            DriverConstants.maxVisibleRequests
        ? _pendingBookings.sublist(0, DriverConstants.maxVisibleRequests)
        : _pendingBookings;

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

    Widget _buildBookingRequestCard(model.BookingRequest request) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Top Section: Client Info & Locations ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Photo
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: request.clientPhoto.isNotEmpty
                      ? NetworkImage(request.clientPhoto)
                      : null,
                  child: request.clientPhoto.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey, size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                // Names and Locations
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.clientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Pickup
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              request.pickupLocation,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Drop
                      Row(
                        children: [
                          const Icon(Icons.square, size: 10, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              request.dropLocation,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu Option
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) async {
                    if (value == 'download') {
                      await _downloadBookingInfo(request.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 8),
                          Text('Download Info'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // === Middle Section: Date & Fare ===
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      request.date,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Estimated Fare (Fixed Double Symbol)
                if (request.estimatedFare != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.currency_rupee, size: 16, color: Colors.green[800]),
                        // Removed the '₹' from text string here
                        Text(
                          request.estimatedFare!.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // === Bottom Section: Buttons (Full Width to fix Overflow) ===
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _denyBookingRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptBooking(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Accept'),
                  ),
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

  // ==================== BOOKING ACTIONS ====================

  Future<void> _acceptBooking(model.BookingRequest request) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final success = await DriverDataService.acceptBooking(request.id);

    if (mounted) {
      Navigator.pop(context); // Close loading

      if (success) {
        setState(() {
          _acceptedRequest = request;
          _hasAcceptedBooking = true;
          _pendingBookings.remove(request);
        });

        NotificationService.showBookingAcceptedNotification();
        DriverError.showSuccess(context, 'Booking accepted successfully!');
      } else {
        DriverError.showError(
            context, 'Failed to accept booking. It may no longer be available.');
      }
    }
  }

  Future<void> _denyBookingRequest(model.BookingRequest request) async {
    final success = await DriverDataService.denyBooking(request.id);

    if (mounted) {
      if (success) {
        setState(() {
          _pendingBookings.remove(request);
        });
        DriverError.showInfo(context, 'Booking request denied');
      } else {
        DriverError.showError(context, 'Failed to deny booking');
      }
    }
  }

  Future<void> _cancelAcceptedBooking() async {
    if (_acceptedRequest == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text(
            'Are you sure you want to cancel this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final success =
          await DriverDataService.cancelBooking(_acceptedRequest!.id);

      if (mounted) {
        Navigator.pop(context);

        if (success) {
          setState(() {
            _acceptedRequest = null;
            _hasAcceptedBooking = false;
          });
          DriverError.showInfo(context, 'Booking cancelled');
        } else {
          DriverError.showError(context, 'Failed to cancel booking');
        }
      }
    }
  }

  Future<void> _downloadBookingInfo(String bookingId) async {
    setState(() {
      _isDownloadingInfo = true;
    });

    DriverError.showInfo(context, 'Downloading booking info...');

    try {
      final file = await DriverDataService.downloadBookingInfo(bookingId);

      if (mounted) {
        setState(() {
          _isDownloadingInfo = false;
        });

        if (file != null) {
          DriverError.showSuccess(context, 'PDF saved successfully!');

          // Try to open the file
          try {
            await OpenFile.open(file.path);
          } catch (e) {
            debugPrint('Could not open file: $e');
            DriverError.showInfo(
                context, 'File saved at: ${file.path}');
          }
        } else {
          DriverError.showError(context, 'Failed to download booking info');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingInfo = false;
        });
        DriverError.showError(context, 'Error: ${e.toString()}');
      }
    }
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
    final Map<String, dynamic>? result =
        await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MyAccountDriver(
          currentProfileImagePath: displayProfilePicture,
          isLocalImage: _isUsingLocalImage,
          isNetworkImage: _isNetworkImage,
          driverName: displayName,
          driverPhone: displayPhone,
          driverEmail: displayEmail,
          driverRating: _driverRating.toString(),
          truckNumber: displayTruckNumber,
          truckType: _truckType,
          truckCapacity: _truckModel,
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
              'You currently have an ongoing ride. Going offline will cancel this ride. Do you want to continue?'),
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
              onPressed: () async {
                Navigator.of(context).pop();

                if (_acceptedRequest != null) {
                  await DriverDataService.cancelBooking(_acceptedRequest!.id);
                }

                setState(() {
                  _isOnline = false;
                  _hasAcceptedBooking = false;
                  _acceptedRequest = null;
                  _pendingBookings = [];
                });

                _stopListeningToBookings();
                await DriverDataService.updateOnlineStatus(false);
                await NotificationService.showOnlineStatusNotification(
                    isOnline: false);
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
    final Map<String, dynamic>? result =
        await Navigator.push<Map<String, dynamic>>(
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
                ClipOval(
                  child: _buildProfileImage(80),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName.isNotEmpty ? displayName : 'Driver',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileInfoRow('Truck No.-', displayTruckNumber),
                const SizedBox(height: 8),
                _buildProfileInfoRow(
                    'PH No-', displayPhone.isNotEmpty ? displayPhone : 'N/A'),
                const SizedBox(height: 8),
                _buildProfileInfoRow(
                    'Email-', displayEmail.isNotEmpty ? displayEmail : 'N/A'),
                const SizedBox(height: 8),
                _buildProfileInfoRow(
                    'Rating-', '${_driverRating > 0 ? _driverRating : 'N/A'}/5'),
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
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
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
      debugPrint('Error checking location permission: $e');
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

        // Update location in Firebase
        DriverDataService.updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');

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
    _stopListeningToBookings();
    _mapController?.dispose();
    _pageController.dispose();
    _carouselTimer?.cancel();
    NotificationService.cancelAllNotifications();
    super.dispose();
  }

  void _navigateToMap() {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => Maps(
          isDriverOnline: _isOnline,
          hasAcceptedBooking: _hasAcceptedBooking,
          customerName: _acceptedRequest?.clientName ?? "Customer Name",
          pickupLocationName:
              _acceptedRequest?.pickupLocation ?? "Pickup Location",
          destinationLocationName:
              _acceptedRequest?.dropLocation ?? "Destination",
          pickupLocation: LatLng(
            _acceptedRequest?.pickupLat ?? 20.3590,
            _acceptedRequest?.pickupLng ?? 85.8277,
          ),
          destinationLocation: LatLng(
            _acceptedRequest?.dropLat ?? 20.4590,
            _acceptedRequest?.dropLng ?? 85.9077,
          ),
          selectedIndex: 2,
          onCompletion: _handleMapScreenCompletion,
        ),
      ),
    ).then((result) {
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
        if (result != null) {
          _handleMapScreenCompletion(result);
        }
      }
    });
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

  void _showInAppBookingNotification(model.BookingRequest request) {
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
                        color: Colors.grey[700],  // ✅ FIXED - proper syntax
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
      // Entry already removed
    }
  });
}

  void _openLicenseImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LicenseImageScreen(
          imageUrl: _licensePhotoUrl,
        ),
      ),
    );
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
        now.difference(_lastBackPressTime!) >
            DriverConstants.backPressThreshold) {
      _lastBackPressTime = now;
      DriverError.showInfo(context, 'Press back again to exit');
      return true;
    }
    SystemNavigator.pop();
    return true;
  }
}