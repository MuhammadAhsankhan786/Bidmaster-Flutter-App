import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import '../widgets/countdown_timer.dart';
import 'place_bid_modal.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/product_model.dart';
import '../models/bid_model.dart';
import '../utils/image_url_helper.dart';
import '../theme/colors.dart';

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
  ProductModel? _product;
  List<BidModel> _bids = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadProductData();
  }

  Future<void> _loadUserInfo() async {
    final role = await StorageService.getUserRole();
    final userId = await StorageService.getUserId();
    setState(() {
      _userRole = role;
      _userId = userId;
    });
  }

  // Check if current user can edit/delete this product
  bool get _canEditProduct {
    if (_product == null || _userRole == null) return false;
    
    final role = _userRole!.toLowerCase();
    
    // Superadmin can edit/delete any product
    if (role == 'superadmin' || role == 'admin') {
      return true;
    }
    
    // Seller can only edit/delete their own products
    if (role == 'seller_products' && _userId != null) {
      return _product!.sellerId == _userId;
    }
    
    return false;
  }

  // Check if current user is the seller of this product
  bool _isSellerOfProduct() {
    if (_product == null || _userId == null) return false;
    return _product!.sellerId == _userId;
  }

  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productId = int.tryParse(widget.productId);
      if (productId == null) {
        throw Exception('Invalid product ID');
      }

      // Load product, bids, and wishlist status in parallel
      final results = await Future.wait([
        apiService.getProductById(productId),
        apiService.getBidsByProduct(productId),
        StorageService.isInWishlist(productId),
      ]);

      setState(() {
        _product = results[0] as ProductModel;
        _bids = results[1] as List<BidModel>;
        _isLiked = results[2] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<String> get _images {
    if (_product == null) return [];
    return _product!.imageUrls;
  }

  Future<void> _refreshData() async {
    await _loadProductData();
  }

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
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      // Check if we can pop, otherwise navigate to home
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        // If nothing to pop, navigate to home dashboard
                        context.go('/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                      shape: const CircleBorder(),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      if (_product == null) return;
                      final productId = _product!.id;
                      final isInWishlist = await StorageService.isInWishlist(productId);
                      
                      if (isInWishlist) {
                        await StorageService.removeFromWishlist(productId);
                      } else {
                        await StorageService.addToWishlist(productId);
                      }
                      
                      setState(() {
                        _isLiked = !_isLiked;
                      });
                    },
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? AppColors.red600 : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                      shape: const CircleBorder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                      shape: const CircleBorder(),
                    ),
                  ),
                  // Edit/Delete buttons for seller/superadmin
                  if (_canEditProduct) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final productId = int.tryParse(widget.productId);
                          if (productId != null) {
                            context.push('/product-creation?productId=$productId');
                          }
                        } else if (value == 'delete') {
                          await _showDeleteConfirmation();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20, color: AppColors.primaryBlue),
                              const SizedBox(width: 12),
                              const Text('Edit Product'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: AppColors.red600),
                              const SizedBox(width: 12),
                              Text('Delete Product', style: TextStyle(color: AppColors.red600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.error),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load product',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refreshData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: AppColors.cardWhite,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _product == null
                          ? const Center(child: Text('Product not found'))
                          : SingleChildScrollView(
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
                            ImageUrlHelper.fixImageUrl(_images[index]),
                            fit: BoxFit.cover,
                            headers: const {'Accept': 'image/*'},
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                child: Icon(Icons.image, size: 64, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                                  ? AppColors.primaryBlue
                                  : (isDark ? AppColors.slate700 : AppColors.slate300),
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
                            _product!.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_product!.categoryName != null)
                                _CategoryTag(
                                  label: _product!.categoryName!,
                                  color: AppColors.primaryBlue,
                                ),
                              if (_product!.categoryName != null)
                                const SizedBox(width: 8),
                              _CategoryTag(
                                label: _product!.status == 'approved' ? 'Live' : _product!.status,
                                color: AppColors.green600,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Bid Info Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            fontWeight: FontWeight.w400,
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
                                                color: AppColors.primaryBlue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _formatCurrency(
                                                  (_product!.currentBid ?? _product!.startingBid ?? _product!.startingPrice).toInt()),
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryBlue,
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (_product!.auctionEndTime != null)
                                          CountdownTimer(
                                            endTime: _product!.auctionEndTime!,
                                            size: CountdownSize.medium,
                                          )
                                        else
                                          Text(
                                            'Auction ended',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
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
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_product!.totalBids ?? 0} bids',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Starting: \$${_formatCurrency((_product!.startingBid ?? _product!.startingPrice).toInt())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.w400,
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
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
                                  child: Text(
                                    _product!.sellerName?.substring(0, 1).toUpperCase() ?? 'S',
                                    style: TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                            _product!.sellerName ?? 'Seller',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (_product!.sellerEmail != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email,
                                              size: 12,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _product!.sellerEmail!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (_product!.sellerPhone != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 12,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _product!.sellerPhone!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.person_outline),
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
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
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _product!.description ?? 'No description provided',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Bid History
                          Text(
                            'Bid History',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (_bids.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No bids yet. Be the first to bid!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            RepaintBoundary(
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _bids.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final bid = _bids[index];
                                  final timeAgo = _formatTimeAgo(bid.createdAt);
                                  return RepaintBoundary(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 16,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isDark ? AppColors.slate800 : AppColors.slate100,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                bid.bidderName?.substring(0, 1).toUpperCase() ?? 'B',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryBlue,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  bid.bidderName ?? 'Anonymous',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                                  ),
                                                ),
                                                Text(
                                                  timeAgo,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '\$${_formatCurrency(bid.amount.toInt())}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

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
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                // Check if user is logged in
                final isLoggedIn = await StorageService.isLoggedIn();
                if (!isLoggedIn) {
                  // Show login prompt
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Login Required'),
                        content: const Text('Please login first'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.go('/auth');
                            },
                            child: const Text('Login'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }
                
                // Check if product is pending (not approved)
                if (_product?.status == 'pending') {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This product is pending admin approval. Bidding will be available once approved.'),
                        backgroundColor: AppColors.error,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
                
                // Check if user is the seller of this product
                if (_isSellerOfProduct()) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot bid on your own product.'),
                        backgroundColor: AppColors.error,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
                
                final result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    final productId = int.tryParse(widget.productId);
                    final currentBid = _product?.currentBid?.toInt() ?? 
                                     _product?.startingBid?.toInt() ?? 
                                     _product?.startingPrice.toInt() ?? 
                                     0;
                    final productTitle = _product?.title ?? 'Product';
                    
                    return PlaceBidModal(
                      currentBid: currentBid,
                      productTitle: productTitle,
                      productId: productId ?? 0,
                    );
                  },
                );
                
                // Refresh product data if bid was successful
                // Delay refresh to ensure modal is fully closed and Navigator is stable
                if (result == true && mounted) {
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      // Add a small delay to ensure Navigator is fully stable
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          _refreshData();
                        }
                      });
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.cardWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${_product?.title ?? 'this product'}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red600,
              foregroundColor: AppColors.cardWhite,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _product != null) {
      await _deleteProduct();
    }
  }

  Future<void> _deleteProduct() async {
    try {
      final productId = int.tryParse(widget.productId);
      if (productId == null) return;

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      await apiService.deleteProduct(productId);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Product deleted successfully'),
            backgroundColor: AppColors.green600,
          ),
        );

        // Navigate back
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: ${e.toString()}'),
            backgroundColor: AppColors.red600,
          ),
        );
      }
    }
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
        color: isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(10),
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

