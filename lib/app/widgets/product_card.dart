import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/image_url_helper.dart';

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

class _ProductCardState extends State<ProductCard> {
  bool _isFavorite = false;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  // BestBid Color Palette
  static const Color _cardBackground = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF222222);
  static const Color _textLight = Color(0xFF666666);
  static const Color _primary = Color(0xFF0A3069);
  static const Color _imagePlaceholder = Color(0xFFF1F3F5);
  static const Color _timerBg = Color(0xFFFF5555);
  static const Color _timerText = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Image Container with Timer Badge INSIDE (top-right)
            Stack(
              children: [
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
                                color: _imagePlaceholder,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: _primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: _imagePlaceholder,
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 32,
                                    color: _textLight,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: _imagePlaceholder,
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                size: 32,
                                color: _textLight,
                              ),
                            ),
                          ),
                  ),
                ),
                // Timer Badge - INSIDE image (top-right) - BestBid style
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _timerBg,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _formatTimer(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _timerText,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Container - Title, Price, Heart, Auction end text
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title - Bold, Max 2 lines, #222
                    Flexible(
                      flex: 1,
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Price Row - Price (left) + Heart icon (right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price - Bold, #0A3069 - BestBid format
                        Flexible(
                          child: Text(
                            '\$${_formatCurrency(widget.currentBid)} USD',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Heart icon
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isFavorite = !_isFavorite;
                            });
                          },
                          child: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: _isFavorite ? _timerBg : _textLight,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    // Timer display - Compact format
                    Text(
                      _formatTimer(),
                      style: const TextStyle(
                        fontSize: 8,
                        color: _textLight,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }
}
