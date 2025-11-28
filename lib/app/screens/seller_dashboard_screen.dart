import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../widgets/countdown_timer.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/product_model.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedStatus = 'all'; // all, pending, approved, sold

  List<StatData> get _stats {
    final activeProducts = _products.where((p) => p.status == 'approved').length;
    final pendingProducts = _products.where((p) => p.status == 'pending').length;
    final totalBids = _products.fold<int>(0, (sum, p) => sum + (p.totalBids ?? 0));
    final totalEarnings = _products
        .where((p) => p.status == 'sold')
        .fold<double>(0, (sum, p) => sum + (p.currentBid ?? p.startingPrice));

    return [
      StatData(
        label: 'Total Earnings',
        value: '\$${_formatCurrency(totalEarnings.toInt())}',
        change: pendingProducts > 0 ? '$pendingProducts pending' : 'All approved',
        icon: Icons.attach_money,
        gradientColors: [AppColors.green500, AppColors.green600],
      ),
      StatData(
        label: 'Active Listings',
        value: '$activeProducts',
        change: pendingProducts > 0 ? '$pendingProducts pending' : 'All active',
        icon: Icons.inventory_2,
        gradientColors: [AppColors.blue500, AppColors.blue600],
      ),
      StatData(
        label: 'Total Bids',
        value: '$totalBids',
        change: 'Across all listings',
        icon: Icons.trending_up,
        gradientColors: [AppColors.yellow500, AppColors.yellow600],
      ),
    ];
  }

  List<ProductModel> get _filteredListings {
    if (_selectedStatus == 'all') return _products;
    return _products.where((p) => p.status == _selectedStatus).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Debug: Check logged-in user
      final userId = await StorageService.getUserId();
      final userRole = await StorageService.getUserRole();
      final userPhone = await StorageService.getUserPhone();
      print('🔍 Debug - Current User:');
      print('   User ID: $userId');
      print('   Role: $userRole');
      print('   Phone: $userPhone');
      
      final products = await apiService.getMyProducts();
      print('📦 Products received: ${products.length}');
      
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading products: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  Widget _buildStatusFilter(String status, String label) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue600 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.blue600 : AppColors.slate300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : AppColors.slate600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          context.push('/profile');
                        },
                        icon: const Icon(Icons.person),
                        tooltip: 'Profile',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          context.push('/seller/earnings');
                        },
                        icon: const Icon(Icons.account_balance_wallet),
                        tooltip: 'View Earnings',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        onPressed: () {
                          print('🔘 Add New Listing FAB clicked');
                          context.push('/product-create').then((result) {
                            print('🔘 Product creation result: $result');
                            if (result == true) {
                              // Reload products after successful creation
                              _loadProducts();
                            }
                          });
                        },
                        backgroundColor: AppColors.blue600,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Stats Cards
                    if (_isLoading && _products.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_errorMessage != null && _products.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.error),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load listings',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadProducts,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
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
                          // Status Filter
                          Row(
                            children: [
                              _buildStatusFilter('all', 'All'),
                              const SizedBox(width: 8),
                              _buildStatusFilter('pending', 'Pending'),
                              const SizedBox(width: 8),
                              _buildStatusFilter('approved', 'Active'),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Listings
                      if (_filteredListings.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: AppColors.slate400),
                                const SizedBox(height: 16),
                                Text(
                                  'No listings found',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first listing to get started',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredListings.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final product = _filteredListings[index];
                            final imageUrls = product.imageUrls;
                            final imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
                            
                            return _ListingCard(
                              product: product,
                              imageUrl: imageUrl ?? '',
                              onTap: product.status == 'approved'
                                  ? () {
                                      context.go('/product-details/${product.id}');
                                    }
                                  : null,
                              onEdit: () async {
                                // Navigate to edit screen (reuse create screen with product data)
                                final result = await context.push(
                                  '/product-create',
                                  extra: product, // Pass product for editing
                                );
                                if (result == true) {
                                  _loadProducts();
                                }
                              },
                              onDelete: () async {
                                // Show confirmation dialog
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Product'),
                                    content: Text('Are you sure you want to delete "${product.title}"? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.red600,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirmed == true) {
                                  try {
                                    await apiService.deleteProduct(product.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Product deleted successfully'),
                                          backgroundColor: AppColors.green600,
                                        ),
                                      );
                                      _loadProducts();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to delete product: ${e.toString()}'),
                                          backgroundColor: AppColors.red600,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            );
                          },
                        ),
                    ],

                    const SizedBox(height: 16),

                    // Add New Listing Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          print('🔘 Add New Listing button clicked');
                          context.push('/product-create').then((result) {
                            print('🔘 Product creation result: $result');
                            if (result == true) {
                              // Reload products after successful creation
                              _loadProducts();
                            }
                          });
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
  final ProductModel product;
  final String imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ListingCard({
    required this.product,
    required this.imageUrl,
    this.onTap,
    this.onEdit,
    this.onDelete,
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
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image, size: 32);
                        },
                      )
                    : const Icon(Icons.image, size: 32),
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
                          product.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.status == 'pending')
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
                  if (product.status == 'approved')
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
                              '\$${_formatCurrency((product.currentBid ?? product.startingBid ?? product.startingPrice).toInt())}',
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
                                  '${product.totalBids ?? 0}',
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
                            if (product.auctionEndTime != null)
                              CountdownTimer(
                                endTime: product.auctionEndTime!,
                                size: CountdownSize.small,
                              ),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(
                      product.status == 'pending'
                          ? 'Awaiting admin approval'
                          : 'Status: ${product.status}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    ),
                  // View Winner button for sold products
                  if (product.status == 'sold')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.go('/seller/winner/${product.id}');
                          },
                          icon: const Icon(Icons.emoji_events, size: 16),
                          label: const Text('View Winner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                  // Edit/Delete buttons (only for seller's own products)
                  if (onEdit != null || onDelete != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onEdit != null)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: AppColors.blue600,
                              onPressed: () {
                                // Stop tap propagation
                                if (onTap != null) {
                                  // Don't navigate to details
                                }
                                onEdit?.call();
                              },
                              tooltip: 'Edit',
                            ),
                          if (onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: AppColors.red600,
                              onPressed: () {
                                // Stop tap propagation
                                if (onTap != null) {
                                  // Don't navigate to details
                                }
                                onDelete?.call();
                              },
                              tooltip: 'Delete',
                            ),
                        ],
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

// ListingData class removed - using ProductModel instead

