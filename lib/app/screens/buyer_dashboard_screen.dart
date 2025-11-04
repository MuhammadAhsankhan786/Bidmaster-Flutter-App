import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../widgets/product_card.dart';

class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({super.key});

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Watches',
    'Electronics',
    'Art',
    'Furniture',
    'Fashion',
    'Collectibles',
  ];

  final List<ProductData> _products = [
    ProductData(
      id: '1',
      title: 'Vintage Rolex Submariner 1960s Rare Edition',
      imageUrl:
          'https://images.unsplash.com/photo-1680810897186-372717262131?w=400',
      currentBid: 15000,
      totalBids: 47,
      endTime: DateTime.now().add(const Duration(hours: 5)),
      category: 'Watches',
    ),
    ProductData(
      id: '2',
      title: 'Classic Leica M3 Film Camera with Original Lens',
      imageUrl:
          'https://images.unsplash.com/photo-1495121553079-4c61bcce1894?w=400',
      currentBid: 3200,
      totalBids: 23,
      endTime: DateTime.now().add(const Duration(hours: 12)),
      category: 'Electronics',
    ),
    ProductData(
      id: '3',
      title: 'Limited Edition Nike Air Jordan 1 Retro High OG',
      imageUrl:
          'https://images.unsplash.com/photo-1625622176700-e55445383b85?w=400',
      currentBid: 850,
      totalBids: 89,
      endTime: DateTime.now().add(const Duration(hours: 2)),
      category: 'Fashion',
    ),
    ProductData(
      id: '4',
      title: 'Mid-Century Modern Eames Lounge Chair & Ottoman',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
      currentBid: 4500,
      totalBids: 31,
      endTime: DateTime.now().add(const Duration(hours: 24)),
      category: 'Furniture',
    ),
    ProductData(
      id: '5',
      title: 'Original Abstract Oil Painting by Contemporary Artist',
      imageUrl:
          'https://images.unsplash.com/photo-1562040506-a9b32cb51b94?w=400',
      currentBid: 2200,
      totalBids: 18,
      endTime: DateTime.now().add(const Duration(hours: 48)),
      category: 'Art',
    ),
    ProductData(
      id: '6',
      title: 'Vintage Nintendo Game & Watch Donkey Kong Boxed',
      imageUrl:
          'https://images.unsplash.com/photo-1579304118856-9304f3d090d5?w=400',
      currentBid: 580,
      totalBids: 52,
      endTime: DateTime.now().add(const Duration(hours: 6)),
      category: 'Collectibles',
    ),
  ];

  List<ProductData> get _filteredProducts {
    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch = product.title
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Title and Filter Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discover',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '${_filteredProducts.length} active auctions',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.tune),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              isDark ? AppColors.slate800 : AppColors.slate100,
                          shape: const CircleBorder(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search auctions...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark ? AppColors.backgroundDark : AppColors.slate50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.slate800 : AppColors.slate200,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.slate800 : AppColors.slate200,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Filter
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                              selectedColor: AppColors.blue600,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up,
                            label: 'Trending',
                            value: '125',
                            gradientColors: [AppColors.blue500, AppColors.blue600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.access_time,
                            label: 'Ending Soon',
                            value: '32',
                            gradientColors: [AppColors.yellow500, AppColors.yellow600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.star,
                            label: 'Featured',
                            value: '18',
                            gradientColors: [AppColors.green500, AppColors.green600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Products Grid
                    Text(
                      'Active Auctions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 16),

                    // Product List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ProductCard(
                          id: product.id,
                          title: product.title,
                          imageUrl: product.imageUrl,
                          currentBid: product.currentBid,
                          totalBids: product.totalBids,
                          endTime: product.endTime,
                          category: product.category,
                          onTap: () {
                            context.go('/product-details/${product.id}');
                          },
                        );
                      },
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
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradientColors;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductData {
  final String id;
  final String title;
  final String imageUrl;
  final int currentBid;
  final int totalBids;
  final DateTime endTime;
  final String category;

  ProductData({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.currentBid,
    required this.totalBids,
    required this.endTime,
    required this.category,
  });
}

