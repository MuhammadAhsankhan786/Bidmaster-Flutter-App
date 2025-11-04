import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../widgets/countdown_timer.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final List<StatData> _stats = [
    StatData(
      label: 'Total Earnings',
      value: '\$24,850',
      change: '+12.5%',
      icon: Icons.attach_money,
      gradientColors: [AppColors.green500, AppColors.green600],
    ),
    StatData(
      label: 'Active Listings',
      value: '8',
      change: '2 ending soon',
      icon: Icons.inventory_2,
      gradientColors: [AppColors.blue500, AppColors.blue600],
    ),
    StatData(
      label: 'Total Bids',
      value: '347',
      change: '+23 today',
      icon: Icons.trending_up,
      gradientColors: [AppColors.yellow500, AppColors.yellow600],
    ),
  ];

  final List<ListingData> _listings = [
    ListingData(
      id: '1',
      title: 'Vintage Rolex Submariner 1960s',
      imageUrl:
          'https://images.unsplash.com/photo-1680810897186-372717262131?w=400',
      currentBid: 15000,
      totalBids: 47,
      views: 1234,
      endTime: DateTime.now().add(const Duration(hours: 5)),
      status: 'active',
    ),
    ListingData(
      id: '2',
      title: 'Classic Leica M3 Film Camera',
      imageUrl:
          'https://images.unsplash.com/photo-1495121553079-4c61bcce1894?w=400',
      currentBid: 3200,
      totalBids: 23,
      views: 856,
      endTime: DateTime.now().add(const Duration(hours: 12)),
      status: 'active',
    ),
    ListingData(
      id: '3',
      title: 'Mid-Century Modern Eames Chair',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400',
      currentBid: 0,
      totalBids: 0,
      views: 0,
      endTime: DateTime.now(),
      status: 'pending',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seller Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Manage your listings',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                      ),
                    ],
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      // Navigate to add product screen
                    },
                    backgroundColor: AppColors.blue600,
                    child: const Icon(Icons.add, color: Colors.white),
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
                    // Stats Cards
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _stats.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final stat = _stats[index];
                        return _StatCard(stat: stat);
                      },
                    ),

                    const SizedBox(height: 24),

                    // My Listings Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Listings',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: TextStyle(color: AppColors.blue600),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Listings
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _listings.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final listing = _listings[index];
                        return _ListingCard(
                          listing: listing,
                          onTap: listing.status == 'active'
                              ? () {
                                  // Navigate to active auction
                                }
                              : null,
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Add New Listing Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to add product screen
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Listing'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? AppColors.slate700 : AppColors.slate300,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
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
  final StatData stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.change,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.green600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: stat.gradientColors,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, size: 24, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final ListingData listing;
  final VoidCallback? onTap;

  const _ListingCard({
    required this.listing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.slate700 : AppColors.slate200,
          ),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.slate900 : AppColors.slate100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  listing.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image, size: 32);
                  },
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (listing.status == 'pending')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellow100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.yellow700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (listing.status == 'active')
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Bid',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                            ),
                            Text(
                              '\$${_formatCurrency(listing.currentBid)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.blue600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${listing.totalBids}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${listing.views}',
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
                            CountdownTimer(
                              endTime: listing.endTime,
                              size: CountdownSize.small,
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(
                      'Awaiting admin approval',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    ),
                ],
              ),
            ),
          ],
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

class StatData {
  final String label;
  final String value;
  final String change;
  final IconData icon;
  final List<Color> gradientColors;

  StatData({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    required this.gradientColors,
  });
}

class ListingData {
  final String id;
  final String title;
  final String imageUrl;
  final int currentBid;
  final int totalBids;
  final int views;
  final DateTime endTime;
  final String status;

  ListingData({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.currentBid,
    required this.totalBids,
    required this.views,
    required this.endTime,
    required this.status,
  });
}

