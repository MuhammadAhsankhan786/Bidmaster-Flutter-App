import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/image_url_helper.dart';
import '../theme/colors.dart';

class ProductCard extends StatefulWidget {
  final String id;
  final String title;
  final String imageUrl;
  final int currentBid;
  final int totalBids;
  final DateTime endTime;
  final String? category;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.currentBid,
    required this.totalBids,
    required this.endTime,
    this.category,
    required this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Theme-based colors - will adapt to light/dark mode
  static Color _cardBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  }
  
  static Color _textDark(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  }
  
  static Color _textLight(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  }
  
  static Color _primary(BuildContext context) {
    return AppColors.primaryBlue;
  }
  
  static Color _imagePlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.slate800 : AppColors.slate100;
  }
  
  // Green timer button (consistent across themes)
  static const Color _timerBg = Color(0xFF4CAF50);
  static const Color _timerText = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _updateTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _updateTimer() {
    final now = DateTime.now();
    final difference = widget.endTime.difference(now);

    if (difference.isNegative) {
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
      _timer?.cancel();
    } else {
      if (mounted) {
        setState(() {
          _remaining = difference;
        });
      }
    }
  }

  String _formatTimer() {
    if (_remaining.isNegative || _remaining.inSeconds <= 0) {
      return '0 Sec';
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    // Compact format to prevent overflow
    if (days > 0) {
      return '$days ${days == 1 ? 'Day' : 'Days'}';
    } else if (hours > 0) {
      return '$hours ${hours == 1 ? 'Hr' : 'Hrs'}';
    } else if (minutes > 0) {
      return '$minutes ${minutes == 1 ? 'Min' : 'Mins'}';
    } else {
      return '$seconds ${seconds == 1 ? 'Sec' : 'Secs'}';
    }
  }

  String _formatDigitalTimer() {
    if (_remaining.isNegative || _remaining.inSeconds <= 0) {
      return '00h 00m 00s';
    }

    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    // Digital format: 02h 52m 15s (matches screenshot exactly - hours, minutes, seconds)
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
        _animationController.forward();
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        _animationController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.5)
                              : Colors.black.withOpacity(0.15))
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.08)),
                      blurRadius: _isHovered ? 16 : 12,
                      offset: _isHovered ? const Offset(0, 4) : const Offset(0, 2),
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: child!,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Container - Clean image without overlays
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(
                          ImageUrlHelper.fixImageUrl(widget.imageUrl),
                          // Ensure proper headers for HTTPS
                          headers: const {'Accept': 'image/*'},
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: _imagePlaceholder(context),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: _primary(context),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: _imagePlaceholder(context),
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  size: 32,
                                  color: _textLight(context),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: _imagePlaceholder(context),
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 32,
                              color: _textLight(context),
                            ),
                          ),
                        ),
                ),
              ),
              
              // Title - Below image
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textDark(context),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Category display
                    if (widget.category != null && widget.category!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.category_rounded,
                            size: 11,
                            color: _textLight(context),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              widget.category!,
                              style: TextStyle(
                                fontSize: 9,
                                color: _textLight(context),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Timer and Price Badges - Below title
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Timer Badge - Green style
                    Container(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: _timerBg, // Green color
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDigitalTimer(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _timerText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    // Price Badge - Grey style
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.currentBid} \$',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    // Simple format - just return the number (matches screenshot style)
    return amount.toString();
  }
}
