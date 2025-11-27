// lib/license_image_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class LicenseImageScreen extends StatefulWidget {
  final String? imageUrl;
  final File? localImageFile;

  const LicenseImageScreen({
    super.key,
    this.imageUrl,
    this.localImageFile,
  });

  @override
  State<LicenseImageScreen> createState() => _LicenseImageScreenState();
}

class _LicenseImageScreenState extends State<LicenseImageScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  void _checkImage() {
    final hasLocalImage = widget.localImageFile != null && 
                          widget.localImageFile!.existsSync();
    final hasNetworkUrl = widget.imageUrl != null && 
                          widget.imageUrl!.isNotEmpty &&
                          (widget.imageUrl!.startsWith('http://') || 
                           widget.imageUrl!.startsWith('https://'));

    if (!hasLocalImage && !hasNetworkUrl) {
      setState(() {
        _isLoading = false;
        _hasError = false; // No error, just no image
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = widget.localImageFile != null && 
                          widget.localImageFile!.existsSync();
    final hasNetworkUrl = widget.imageUrl != null && 
                          widget.imageUrl!.isNotEmpty &&
                          (widget.imageUrl!.startsWith('http://') || 
                           widget.imageUrl!.startsWith('https://'));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Driving License',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (hasNetworkUrl || hasLocalImage)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadImage,
              tooltip: 'Download',
            ),
        ],
      ),
      body: Center(
        child: _buildImageViewer(
          hasLocalImage: hasLocalImage,
          hasNetworkUrl: hasNetworkUrl,
        ),
      ),
    );
  }

  Widget _buildImageViewer({
    required bool hasLocalImage,
    required bool hasNetworkUrl,
  }) {
    if (hasLocalImage) {
      return _buildLocalImageViewer();
    } else if (hasNetworkUrl) {
      return _buildNetworkImageViewer();
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildLocalImageViewer() {
    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            widget.localImageFile!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget('Failed to load license image');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImageViewer() {
    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.imageUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Image loaded successfully
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _isLoading) {
                    setState(() => _isLoading = false);
                  }
                });
                return child;
              }
              
              // Still loading
              final progress = loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null;
              
              return _buildLoadingWidget(progress);
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ Error loading license image: $error');
              return _buildErrorWidget('Failed to load license image');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget(double? progress) {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            progress != null 
                ? 'Loading... ${(progress * 100).toStringAsFixed(0)}%'
                : 'Loading...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.credit_card,
              size: 60,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No License Image Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your driving license image will appear here\nonce it is uploaded to your profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              // Navigate to edit profile or show upload option
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please update your profile to add license image'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Upload License'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[600]!),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[900]!, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[900]!.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[300],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please check your internet connection\nor try again later',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadImage() {
    // Implement download functionality if needed
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}