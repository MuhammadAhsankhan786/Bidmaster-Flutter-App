import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/image_url_helper.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<String> _bannerImages = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Fallback banners - Used when API fails or returns no banners
  // These are local assets or reliable external URLs
  final List<String> _fallbackBanners = [
    'https://images.unsplash.com/photo-1606761568499-6d45d7a523c5?w=1920&h=600&fit=crop&q=100&auto=format',
    'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=1920&h=600&fit=crop&q=100&auto=format',
    'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=1920&h=600&fit=crop&q=100&auto=format',
  ];

  @override
  void initState() {
    super.initState();
    // Load banners from API (Production-ready)
    _loadBanners();
    // Auto-scroll slider will start after banners load
  }

  /// Load banners from backend API with fallback
  Future<void> _loadBanners() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Fetch banners from API
      final banners = await apiService.getBanners();
      
      if (banners.isNotEmpty) {
        // Extract image URLs from API response (Cloudinary URLs)
        final imageUrls = banners
            .map((banner) => banner['imageUrl'] ?? banner['image_url'] ?? '')
            .where((url) => url.toString().isNotEmpty)
            .map((url) => ImageUrlHelper.fixImageUrl(url.toString())) // Fix URLs (handles Cloudinary & relative URLs)
            .where((url) => url.isNotEmpty)
            .toList();
        
        if (imageUrls.isNotEmpty) {
          setState(() {
            _bannerImages = imageUrls;
            _isLoading = false;
            _hasError = false;
          });
          _startAutoScroll();
          return;
        }
      }
      
      // If API returns empty or no images, use fallback
      setState(() {
        _bannerImages = _fallbackBanners;
        _isLoading = false;
        _hasError = false;
      });
      _startAutoScroll();
    } catch (e) {
      // On error, use fallback banners
      setState(() {
        _bannerImages = _fallbackBanners;
        _isLoading = false;
        _hasError = true;
      });
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _pageController.hasClients) {
        if (_currentPage < _bannerImages.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while fetching banners
    if (_isLoading) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0A3069),
          ),
        ),
      );
    }

    // Show empty state if no banners available
    if (_bannerImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200, // Increased height for better HD image display (BestBid.tech style)
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        children: [
          // Image Carousel
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _bannerImages.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image - Production-ready with caching (Cloudinary support)
                      CachedNetworkImage(
                        imageUrl: ImageUrlHelper.fixImageUrl(_bannerImages[index]), // Ensure URL is properly formatted
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        filterQuality: FilterQuality.high,
                        memCacheWidth: 1920, // Cache at HD resolution for performance
                        httpHeaders: const {'Accept': 'image/*'},
                        placeholder: (context, url) => Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: const Color(0xFFF1F3F5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0A3069),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: const Color(0xFFF1F3F5),
                          child: const Center(
                            child: Icon(
                              Icons.image,
                              size: 48,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                      // Gradient Overlay - App Theme Colors
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0A3069).withOpacity(0.3), // Dark Blue
                              const Color(0xFF2BA8E0).withOpacity(0.2), // Light Blue
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Previous Button (Left)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_pageController.hasClients) {
                      final previousPage = _currentPage > 0
                          ? _currentPage - 1
                          : _bannerImages.length - 1;
                      _pageController.animateToPage(
                        previousPage,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF222222),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Next Button (Right)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_pageController.hasClients) {
                      final nextPage = _currentPage < _bannerImages.length - 1
                          ? _currentPage + 1
                          : 0;
                      _pageController.animateToPage(
                        nextPage,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF222222),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Page Indicators (dots below)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _bannerImages.length,
                (index) => Container(
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}





