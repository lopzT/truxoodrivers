import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';

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
  final List<String> _timeFrames = ['Last 4 Months', 'Last 6 Months', 'Last Year'];

   @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context, {'selectedIndex': 0});
    return true;
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return Scaffold(
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
          }
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Card(
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
                              items: _timeFrames.map<DropdownMenuItem<String>>((String value) {
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTotalEarningsWidget(isLargeScreen),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _buildSimpleEarningsChart(isLargeScreen),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildTotalEarningsWidget(isLargeScreen),
                                  const SizedBox(height: 24),
                                  _buildSimpleEarningsChart(isLargeScreen),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: isLargeScreen ? 24 : 16),
                
                
                Card(
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
                              'Recent Rides',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 20 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                
                              },
                              icon: const Icon(Icons.history),
                              label: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
        crossAxisAlignment: isLargeScreen ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
  
Widget _buildSimpleEarningsChart(bool isLargeScreen) {
  double maxAmount = 0;
  for (var earning in widget.monthlyEarnings) {
    if (earning.amount > maxAmount) {
      maxAmount = earning.amount;
    }
  }
  
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
              final double maxBarHeight = constraints.maxHeight - 40; 
              
              return Column(
                children: [
                  SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widget.monthlyEarnings.map((earning) {
                        return SizedBox(
                          width: (constraints.maxWidth / widget.monthlyEarnings.length),
                          child: Center(
                            child: Text(
                              NumberFormat.compact().format(earning.amount),
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end, 
                        children: widget.monthlyEarnings.map((earning) {
                          double heightPercentage = earning.amount / maxAmount;
                          double barHeight = heightPercentage * maxBarHeight;
                          double barWidth = (constraints.maxWidth / widget.monthlyEarnings.length) - 10;
                          
                          return Container(
                            width: barWidth,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  
                 
                  SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widget.monthlyEarnings.map((earning) {
                        return SizedBox(
                          width: (constraints.maxWidth / widget.monthlyEarnings.length),
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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.rideHistory.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final ride = widget.rideHistory[index];
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
          onTap: () {
            _showRideDetailsDialog(context, ride, isLargeScreen);
          },
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
  
  void _showRideDetailsDialog(BuildContext context, RideHistory ride, bool isLargeScreen) {
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
                _buildDetailRow('Amount', '₹ ${ride.amount.toStringAsFixed(2)}', isLargeScreen),
                _buildDetailRow('Status', ride.status, isLargeScreen),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Download invoice functionality
                        Navigator.of(context).pop();
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
                        // Share ride details functionality
                        Navigator.of(context).pop();
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