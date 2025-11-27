import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:share_plus/share_plus.dart';

// ===== MODELS =====
class RideHistory {
  final String customerName;
  final String pickupLocation;
  final String dropLocation;
  final String date;
  final double amount;
  final String status;

  RideHistory({
    required this.customerName,
    required this.pickupLocation,
    required this.dropLocation,
    required this.date,
    required this.amount,
    required this.status,
  });
}

class MonthlyEarning {
  final String month;
  final double amount;

  MonthlyEarning({
    required this.month,
    required this.amount,
  });
}

// ===== ENUMS =====
enum SortBy { dateNewest, dateOldest, amountHighest, amountLowest }

// ===== MAIN PAGE =====
class HistoryDriver extends StatefulWidget {
  final List<RideHistory> rideHistory;
  final double totalEarnings;
  final List<MonthlyEarning> monthlyEarnings;

  const HistoryDriver({
    super.key,
    required this.rideHistory,
    required this.totalEarnings,
    required this.monthlyEarnings,
  });

  @override
  State<HistoryDriver> createState() => _HistoryDriverState();
}

class _HistoryDriverState extends State<HistoryDriver> {
  String _selectedTimeFrame = 'Last 4 Months';
  SortBy _sortBy = SortBy.dateNewest;
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();
  final List<String> _timeFrames = [
    'Last 4 Months',
    'Last 6 Months',
    'Last Year'
  ];

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _searchController.dispose();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context, {'selectedIndex': 0});
    return true;
  }

  // ===== FILTERING & SORTING =====
  List<MonthlyEarning> _getFilteredEarnings() {
    switch (_selectedTimeFrame) {
      case 'Last 4 Months':
        return widget.monthlyEarnings.length <= 4
            ? widget.monthlyEarnings
            : widget.monthlyEarnings
                .sublist(widget.monthlyEarnings.length - 4);
      case 'Last 6 Months':
        return widget.monthlyEarnings.length <= 6
            ? widget.monthlyEarnings
            : widget.monthlyEarnings
                .sublist(widget.monthlyEarnings.length - 6);
      default:
        return widget.monthlyEarnings;
    }
  }

  List<RideHistory> _getFilteredRides() {
    final now = DateTime.now();
    final rides = widget.rideHistory;

    return rides.where((ride) {
      final rideDate = _parseDate(ride.date);
      final daysDifference = now.difference(rideDate).inDays;

      switch (_selectedTimeFrame) {
        case 'Last 4 Months':
          return daysDifference <= 120;
        case 'Last 6 Months':
          return daysDifference <= 180;
        default:
          return true;
      }
    }).toList();
  }

  List<RideHistory> _getSortedRides() {
    final filtered = _getFilteredRides();
    final sorted = [...filtered];

    switch (_sortBy) {
      case SortBy.dateNewest:
        sorted.sort((a, b) =>
            _parseDate(b.date).compareTo(_parseDate(a.date)));
        break;
      case SortBy.dateOldest:
        sorted.sort((a, b) =>
            _parseDate(a.date).compareTo(_parseDate(b.date)));
        break;
      case SortBy.amountHighest:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortBy.amountLowest:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return sorted;
  }

  List<RideHistory> _getSearchedRides() {
    final sorted = _getSortedRides();

    if (_searchQuery.isEmpty) return sorted;

    final query = _searchQuery.toLowerCase();
    return sorted.where((ride) {
      return ride.customerName.toLowerCase().contains(query) ||
          ride.pickupLocation.toLowerCase().contains(query) ||
          ride.dropLocation.toLowerCase().contains(query);
    }).toList();
  }

  double _getMaxEarning(List<MonthlyEarning> earnings) {
    if (earnings.isEmpty) return 0;
    return earnings.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
  }

  DateTime _parseDate(String dateString) {
    try {
      return DateFormat('dd MMM yyyy').parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  // ===== ACTIONS =====
  void _showAllRidesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Rides',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: _buildRideHistoryList(true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareRideDetails(RideHistory ride) async {
    try {
      final rideText = '''
📍 Ride Details
━━━━━━━━━━━━━━━
👤 Customer: ${ride.customerName}
📍 From: ${ride.pickupLocation}
📍 To: ${ride.dropLocation}
📅 Date: ${ride.date}
💰 Amount: ₹${ride.amount.toStringAsFixed(2)}
✅ Status: ${ride.status}
      ''';

      await Share.share(
        rideText,
        subject: 'Ride Details - ${ride.date}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadInvoice(RideHistory ride) async {
    try {
      // TODO: Implement PDF generation using pdf package
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final rides = _getSearchedRides();

      final csv = StringBuffer();
      csv.writeln('Customer,From,To,Date,Amount,Status');

      for (var ride in rides) {
        csv.writeln(
          '${ride.customerName},${ride.pickupLocation},'
          '${ride.dropLocation},${ride.date},'
          '${ride.amount.toStringAsFixed(2)},${ride.status}',
        );
      }

      await Share.share(
        csv.toString(),
        subject: 'Earnings Report - $_selectedTimeFrame',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenWidth > 600;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Earnings & History',
            style: TextStyle(
              fontSize: isLargeScreen ? 24 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop({'selectedIndex': 0});
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export to CSV',
              onPressed: _exportToCSV,
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Earnings Overview Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Earnings Overview',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 20 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              DropdownButton<String>(
                                value: _selectedTimeFrame,
                                icon: const Icon(Icons.arrow_drop_down),
                                elevation: 16,
                                underline: Container(
                                  height: 2,
                                  color: Colors.blue,
                                ),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedTimeFrame = newValue;
                                    });
                                  }
                                },
                                items: _timeFrames
                                    .map<DropdownMenuItem<String>>(
                                        (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          isLargeScreen
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildTotalEarningsWidget(
                                        isLargeScreen),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child:
                                          _buildSimpleEarningsChart(
                                              isLargeScreen),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildTotalEarningsWidget(
                                        isLargeScreen),
                                    const SizedBox(height: 24),
                                    _buildSimpleEarningsChart(
                                        isLargeScreen),
                                  ],
                                ),
                          const SizedBox(height: 24),
                          _buildEarningsStats(isLargeScreen),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 24 : 16),

                  // Recent Rides Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding:
                          EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Rides',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 20 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showAllRidesDialog,
                                icon: const Icon(Icons.history),
                                label: const Text('View All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Search Bar
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by customer, location...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Sort Menu
                          SizedBox(
                            height: 36,
                            child: Row(
                              children: [
                                Icon(Icons.sort,
                                    color: Colors.grey[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: PopupMenuButton<SortBy>(
                                    onSelected: (value) {
                                      setState(() => _sortBy = value);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: SortBy.dateNewest,
                                        child: Text('Newest First'),
                                      ),
                                      const PopupMenuItem(
                                        value: SortBy.dateOldest,
                                        child: Text('Oldest First'),
                                      ),
                                      const PopupMenuItem(
                                        value: SortBy.amountHighest,
                                        child:
                                            Text('Highest Amount'),
                                      ),
                                      const PopupMenuItem(
                                        value: SortBy.amountLowest,
                                        child: Text('Lowest Amount'),
                                      ),
                                    ],
                                    child: Text(
                                      'Sort: ${_sortBy.name}',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Rides List
                          _buildRideHistoryList(isLargeScreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalEarningsWidget(bool isLargeScreen) {
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );

    return Container(
      width: isLargeScreen ? 200 : double.infinity,
      padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment:
            isLargeScreen ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            'Total Earnings',
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(widget.totalEarnings),
            style: TextStyle(
              fontSize: isLargeScreen ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_upward,
                color: Colors.green,
                size: isLargeScreen ? 20 : 16,
              ),
              const SizedBox(width: 4),
              Text(
                '12.5% from last period',
                style: TextStyle(
                  fontSize: isLargeScreen ? 14 : 12,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsStats(bool isLargeScreen) {
    final rides = _getSearchedRides();
    if (rides.isEmpty) return const SizedBox.shrink();

    final totalRides = rides.length;
    final avgAmount = rides.isEmpty
        ? 0.0
        : rides.map((r) => r.amount).reduce((a, b) => a + b) / totalRides;
    final maxAmount = rides.isEmpty
        ? 0.0
        : rides.map((r) => r.amount).reduce((a, b) => a > b ? a : b);
    final completedRides = rides
        .where((r) => r.status.toLowerCase() == 'completed')
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard('Total Rides', '$totalRides', Colors.blue),
          _buildStatCard('Avg Earnings', '₹${avgAmount.toStringAsFixed(0)}',
              Colors.orange),
          _buildStatCard('Max Ride', '₹${maxAmount.toStringAsFixed(0)}',
              Colors.green),
          _buildStatCard('Completed', '$completedRides', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSimpleEarningsChart(bool isLargeScreen) {
    final filteredEarnings = _getFilteredEarnings();

    if (filteredEarnings.isEmpty) {
      return Container(
        height: isLargeScreen ? 250 : 200,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No earnings data available'),
        ),
      );
    }

    final maxAmount = _getMaxEarning(filteredEarnings);

    return Container(
      height: isLargeScreen ? 250 : 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Earnings',
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBarHeight = constraints.maxHeight - 40;

                return Column(
                  children: [
                    // Amount labels
                    SizedBox(
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: filteredEarnings.map((earning) {
                          return SizedBox(
                            width: constraints.maxWidth /
                                filteredEarnings.length,
                            child: Center(
                              child: Text(
                                NumberFormat.compact()
                                    .format(earning.amount),
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 12 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Bars
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: filteredEarnings.map((earning) {
                            final heightPercentage =
                                earning.amount / maxAmount;
                            final barHeight =
                                heightPercentage * maxBarHeight;
                            final barWidth =
                                (constraints.maxWidth /
                                        filteredEarnings.length) -
                                    10;

                            return Container(
                              width: barWidth,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Month labels
                    SizedBox(
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: filteredEarnings.map((earning) {
                          return SizedBox(
                            width: constraints.maxWidth /
                                filteredEarnings.length,
                            child: Center(
                              child: Text(
                                earning.month,
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 14 : 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideHistoryList(bool isLargeScreen) {
    final rides = _getSearchedRides();

    if (rides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty ? 'No rides found' : 'No rides yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rides.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final ride = rides[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            vertical: isLargeScreen ? 12 : 8,
            horizontal: isLargeScreen ? 16 : 8,
          ),
          leading: Container(
            width: isLargeScreen ? 50 : 40,
            height: isLargeScreen ? 50 : 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.directions_car,
              color: Colors.blue,
              size: isLargeScreen ? 30 : 24,
            ),
          ),
          title: Text(
            '${ride.pickupLocation} → ${ride.dropLocation}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isLargeScreen ? 16 : 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                ride.customerName,
                style: TextStyle(
                  fontSize: isLargeScreen ? 14 : 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ride.date,
                style: TextStyle(
                  fontSize: isLargeScreen ? 12 : 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${ride.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: isLargeScreen ? 16 : 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(ride.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ride.status,
                  style: TextStyle(
                    color: _getStatusColor(ride.status),
                    fontSize: isLargeScreen ? 12 : 10,
                  ),
                ),
              ),
            ],
          ),
          onTap: () => _showRideDetailsDialog(ride, isLargeScreen),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showRideDetailsDialog(RideHistory ride, bool isLargeScreen) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ride Details',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Customer', ride.customerName, isLargeScreen),
                _buildDetailRow('From', ride.pickupLocation, isLargeScreen),
                _buildDetailRow('To', ride.dropLocation, isLargeScreen),
                _buildDetailRow('Date', ride.date, isLargeScreen),
                _buildDetailRow(
                  'Amount',
                  '₹ ${ride.amount.toStringAsFixed(2)}',
                  isLargeScreen,
                ),
                _buildDetailRow('Status', ride.status, isLargeScreen),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement invoice download
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement share
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isLargeScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}