import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../widgets/countdown_timer.dart';
import 'place_bid_modal.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  bool _isLiked = false;

  final List<String> _images = [
    'https://images.unsplash.com/photo-1680810897186-372717262131?w=800',
    'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?w=800',
    'https://images.unsplash.com/photo-1587836374608-b1b8bf8c1e5f?w=800',
  ];

  final Map<String, dynamic> _productData = {
    'title': 'Vintage Rolex Submariner 1960s Rare Edition',
    'description':
        'An exceptional vintage Rolex Submariner from the 1960s. This rare timepiece features the original gilt dial, matching patina, and comes with its original box and papers. The watch has been professionally serviced and is in excellent working condition.',
    'currentBid': 15000,
    'startingBid': 12000,
    'totalBids': 47,
    'endTime': DateTime.now().add(const Duration(hours: 5)),
    'category': 'Watches',
    'condition': 'Excellent',
    'seller': {
      'name': 'LuxuryTimepieces',
      'rating': 4.9,
      'totalSales': 234,
      'avatar': 'https://api.dicebear.com/7.x/initials/svg?seed=LT',
      'location': 'New York, USA',
    },
    'bidHistory': [
      {'bidder': 'user_432', 'amount': 15000, 'time': '2 mins ago'},
      {'bidder': 'collector_89', 'amount': 14800, 'time': '15 mins ago'},
      {'bidder': 'watch_lover', 'amount': 14500, 'time': '1 hour ago'},
      {'bidder': 'vintage_fan', 'amount': 14000, 'time': '2 hours ago'},
      {'bidder': 'premium_bid', 'amount': 13500, 'time': '3 hours ago'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Sticky Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                    .withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.slate800 : AppColors.slate100,
                      shape: const CircleBorder(),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isLiked = !_isLiked;
                      });
                    },
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? AppColors.red500 : null,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.slate800 : AppColors.slate100,
                      shape: const CircleBorder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppColors.slate800 : AppColors.slate100,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Carousel
                    SizedBox(
                      height: 400,
                      child: PageView.builder(
                        itemCount: _images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Image.network(
                            _images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: AppColors.slate900,
                                child: const Icon(Icons.image, size: 64),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Image Indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _images.length,
                          (index) => Container(
                            width: index == _currentImageIndex ? 32 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _currentImageIndex
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Product Info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and Tags
                          Text(
                            _productData['title'],
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _CategoryTag(
                                label: _productData['category'],
                                color: AppColors.blue600,
                              ),
                              const SizedBox(width: 8),
                              _CategoryTag(
                                label: _productData['condition'],
                                color: AppColors.green600,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Bid Info Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.blue50,
                                  AppColors.blue100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Bid',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.blue600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '\$',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.blue600,
                                              ),
                                            ),
                                            Text(
                                              _formatCurrency(
                                                  _productData['currentBid']),
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.blue600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Time Left',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.blue600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        CountdownTimer(
                                          endTime: _productData['endTime'],
                                          size: CountdownSize.medium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 16,
                                      color: AppColors.blue600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_productData['totalBids']} bids',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.blue600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: AppColors.blue600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Starting: \$${_formatCurrency(_productData['startingBid'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.blue600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Seller Information
                          Text(
                            'Seller Information',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.slate800
                                  : AppColors.slate50,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(
                                    _productData['seller']['avatar'],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _productData['seller']['name'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                size: 14,
                                                color: AppColors.yellow500,
                                              ),
                                              Text(
                                                _productData['seller']['rating']
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.yellow600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${_productData['seller']['totalSales']} sales',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.location_on,
                                            size: 12,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _productData['seller']['location'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.person_outline),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        isDark ? AppColors.slate700 : Colors.white,
                                    shape: const CircleBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Description
                          Text(
                            'Description',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _productData['description'],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.6,
                                ),
                          ),

                          const SizedBox(height: 24),

                          // Bid History
                          Text(
                            'Bid History',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...(_productData['bidHistory'] as List).map((bid) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.blue100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: AppColors.blue600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bid['bidder'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          bid['time'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isDark
                                                    ? AppColors.textSecondaryDark
                                                    : AppColors.textSecondaryLight,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${_formatCurrency(bid['amount'])}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.blue600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

                          const SizedBox(height: 100), // Space for bottom button
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.slate800 : AppColors.slate200,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => PlaceBidModal(
                    currentBid: _productData['currentBid'],
                    productTitle: _productData['title'],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Place Bid',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? color.withOpacity(0.2)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

