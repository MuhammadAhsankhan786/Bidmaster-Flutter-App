import 'package:flutter/material.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Premium HD banner images - BestBid.tech style auction/bidding theme
  // High-resolution images matching bid app colors and auction theme
  final List<String> _bannerImages = [
    // Banner 1: Auction gavel with laptop showing bidding interface (HD)
    'https://images.unsplash.com/photo-1606761568499-6d45d7a523c5?w=1920&h=600&fit=crop&q=100&auto=format',
    // Banner 2: Smartphone showing "YOU WON!" with luxury watch (HD)
    'https://images.unsplash.com/photo-1556656793-08538906a9f8?w=1920&h=600&fit=crop&q=100&auto=format',
    // Banner 3: Luxury handbag auction showcase (HD)
    'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=1920&h=600&fit=crop&q=100&auto=format',
    // Banner 4: Payment successful on smartphone (HD)
    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=1920&h=600&fit=crop&q=100&auto=format',
    // Banner 5: Premium luxury handbag display (HD)
    'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=1920&h=600&fit=crop&q=100&auto=format',
    // Banner 6: Apple products showcase (MacBook, iPhone, Watch) (HD)
    'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=1920&h=600&fit=crop&q=100&auto=format',
    // Banner 7: Delivery scene with package (HD)
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1920&h=600&fit=crop&q=100&auto=format',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-scroll slider
    _startAutoScroll();
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
                      // Background Image - Ultra HD Quality
                      Image.network(
                        _bannerImages[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        filterQuality: FilterQuality.high, // High quality rendering (no pixelation)
                        cacheWidth: 1920, // Cache at ultra HD resolution
                        headers: const {'Accept': 'image/*'},
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: const Color(0xFFF1F3F5),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: const Color(0xFF0A3069),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
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
                          );
                        },
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





