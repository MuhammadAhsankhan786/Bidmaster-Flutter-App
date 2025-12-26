import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:go_router/go_router.dart';
import '../widgets/home_header.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/category_chips.dart';
import '../widgets/product_card.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import '../models/product_model.dart';
import '../services/app_localizations.dart';
import '../services/storage_service.dart';
import '../theme/colors.dart';
import '../utils/rtl_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _categoryKey = GlobalKey();
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _currentUserRole; // Track current user role

  // Categories loaded from API
  List<String> _categories = ['All']; // 'All' is always available, rest loaded from API
  bool _categoriesLoaded = false; // Prevent multiple loads
  bool _isLoadingMore = false; // Prevent multiple load-more calls
  bool _loadMoreScheduled = false; // Prevent scheduling multiple load-more calls during build

  // Timer color (red for urgency)
  static const Color _timer = Color(0xFFFF5555);

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadCategories();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService.getUserRole();
    setState(() {
      _currentUserRole = role;
    });
  }

  Future<void> _loadCategories() async {
    if (_categoriesLoaded) return; // Prevent multiple loads
    
    try {
      final categories = await apiService.getAllCategories();
      // Extract unique category names and remove duplicates
      final categoryNames = categories
          .map((cat) => cat['name'] as String)
          .where((name) => name.isNotEmpty)
          .toSet() // Remove duplicates using Set
          .toList();
      
      setState(() {
        _categories = ['All', ...categoryNames];
        _categoriesLoaded = true;
      });
    } catch (e) {
      // Error loading categories - keep 'All' as default
      debugPrint('Error loading categories: $e');
      // Keep 'All' as default
    }
  }

  String _lastSearchQuery = '';
  
  void _onSearchChanged() {
    final currentQuery = _searchController.text.trim();
    // Only reload if search query actually changed
    if (currentQuery != _lastSearchQuery) {
      _lastSearchQuery = currentQuery;
      // Debounce search - reload after user stops typing
      Future.delayed(const Duration(milliseconds: 500), () {
        // Check if query hasn't changed during debounce delay
        final finalQuery = _searchController.text.trim();
        if (finalQuery == currentQuery) {
          // Update last search query to prevent duplicate calls
          _lastSearchQuery = finalQuery;
          _loadProducts(reset: true);
        }
      });
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _products = [];
        _hasMore = true;
      });
    }

    if (!_hasMore && !reset) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check user role to determine which products to load
      final userRole = await StorageService.getUserRole();
      
      // Update current role state
      setState(() {
        _currentUserRole = userRole;
      });
      
      if (userRole == 'seller_products') {
        // Seller role: Redirect to seller dashboard instead of showing products here
        if (mounted && context.mounted) {
          context.go('/seller-dashboard');
        }
        setState(() {
          _isLoading = false;
        });
        return; // Don't load products on home screen for sellers
      } else {
        // Company/Buyer role: Show all products (getAllProducts)
        // If search query exists, search in products; otherwise use category filter
        final searchQuery = _searchController.text.trim();
        final result = await apiService.getAllProducts(
          category: _selectedCategory == 'All' ? null : _selectedCategory,
          search: searchQuery.isEmpty ? null : searchQuery,
          page: _currentPage,
          limit: 20,
        );

        final newProducts = result['products'] as List<ProductModel>;
        final pagination = result['pagination'] as Map<String, dynamic>;
        
        // Get current user ID to filter out their own seller products when viewing as company_products
        final currentUserId = await StorageService.getUserId();

        setState(() {
          List<ProductModel> filteredProducts = newProducts;
          
          // Apply strict client-side search filter - ONLY show products where TITLE matches search query
          if (searchQuery.isNotEmpty) {
            final searchLower = searchQuery.toLowerCase().trim();
            filteredProducts = filteredProducts.where((product) {
              // Search ONLY in title (case-insensitive) - most relevant for user
              final titleMatch = product.title.toLowerCase().contains(searchLower);
              
              // Only return products where title matches
              return titleMatch;
            }).toList();
          }
          
          // Filter: When viewing as company_products, exclude ALL seller products
          // Company products should only show products without sellerId (company products)
          if (userRole == 'company_products') {
            final beforeCount = filteredProducts.length;
            filteredProducts = filteredProducts.where((product) {
              // Only show products that don't have a sellerId (company products)
              // Strict check: sellerId must be null or undefined (not 0, not any number)
              final isCompanyProduct = product.sellerId == null;
              if (!isCompanyProduct) {
                // Debug: Log products being filtered out
                if (kDebugMode) {
                  print('🚫 [Company Products Filter] Filtering out seller product: ${product.id} - ${product.title} (sellerId: ${product.sellerId})');
                }
              }
              return isCompanyProduct;
            }).toList();
            if (kDebugMode) {
              print('📊 [Company Products Filter] Filtered ${beforeCount} products to ${filteredProducts.length} (removed ${beforeCount - filteredProducts.length} seller products)');
            }
          } else {
            // For other roles, exclude only current user's own seller products
            filteredProducts = filteredProducts.where((product) {
              if (currentUserId != null && product.sellerId != null && product.sellerId == currentUserId) {
                return false; // Don't show seller's own products
              }
              return true;
            }).toList();
          }
          
          if (reset || searchQuery.isNotEmpty) {
            // When resetting or when search is active, replace all products
            // This ensures only matching products are shown
            _products = filteredProducts;
          } else {
            // Only add products when not searching (for pagination)
            _products.addAll(filteredProducts);
          }
          _currentPage = pagination['page'] as int;
          _hasMore = _currentPage < (pagination['pages'] as int);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    final now = DateTime.now();
    final searchQuery = _searchController.text.trim().toLowerCase();
    
    // First filter by search query if active - ONLY match in title
    var filtered = _products;
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        // Search ONLY in title (case-insensitive) - most relevant for user
        final titleMatch = product.title.toLowerCase().contains(searchQuery);
        
        // Only return products where title matches
        return titleMatch;
      }).toList();
    }
    
    // Filter by role: When viewing Company Product, exclude ALL seller products
    if (_currentUserRole == 'company_products') {
      final beforeCount = filtered.length;
      filtered = filtered.where((product) {
        // Only show company products (no sellerId)
        // Strict check: sellerId must be null or undefined
        final isCompanyProduct = product.sellerId == null;
        if (!isCompanyProduct && kDebugMode) {
          print('🚫 [Company Products Display Filter] Filtering out seller product: ${product.id} - ${product.title} (sellerId: ${product.sellerId})');
        }
        return isCompanyProduct;
      }).toList();
      if (kDebugMode && beforeCount != filtered.length) {
        print('📊 [Company Products Display Filter] Filtered ${beforeCount} products to ${filtered.length} (removed ${beforeCount - filtered.length} seller products)');
      }
    }
    
    // CRITICAL FIX: Filter out pending products - only show approved products
    // Then filter out products where bidding has ended (auctionEndTime < now)
    return filtered.where((product) {
      // FIX: Only show approved products (pending products should not appear)
      if (product.status != 'approved') {
        return false; // Hide pending/rejected products
      }
      
      // FIX: If no end time, hide the product (should not happen for approved products)
      // But if it does, hide it to prevent timer issues
      if (product.auctionEndTime == null) {
        return false; // Hide products without auction end time
      }
      
      // Only show products where auction hasn't ended yet
      return product.auctionEndTime!.isAfter(now);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
      });
      _loadProducts(reset: true);
    }
  }

  void _showCategoryModal(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // Show category selection modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.selectCategory ?? 'Select Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, color: colorScheme.onSurface.withOpacity(0.2)),
            
            // Category list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  
                  return ListTile(
                    title: Text(
                      category == 'All' 
                          ? (AppLocalizations.of(context)?.allProducts ?? 'All Products')
                          : category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colorScheme.primary, size: 20)
                        : null,
                    onTap: () {
                      _onCategorySelected(category);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        // Show confirmation dialog before exiting
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: RTLHelper.getTextDirection(context),
            child: AlertDialog(
              title: Text(AppLocalizations.of(context)?.exitApp ?? 'Exit App'),
              content: Text(AppLocalizations.of(context)?.exitAppMessage ?? 'Do you want to exit the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(AppLocalizations.of(context)?.exit ?? 'Exit'),
                ),
              ],
            ),
          ),
        );
        
        if (shouldExit == true && context.mounted) {
          // Exit the app
          SystemNavigator.pop();
        }
      },
      child: Directionality(
        textDirection: RTLHelper.getTextDirection(context),
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          // For RTL languages, drawer should open from right side
          drawer: RTLHelper.isRTL(context) ? null : const AppDrawer(),
          endDrawer: RTLHelper.isRTL(context) ? const AppDrawer() : null,
          drawerEdgeDragWidth: MediaQuery.of(context).size.width, // Allow drawer from both sides
      // Floating button removed - now in AppBar for sellers
      body: SafeArea(
        child: Column(
          children: [
            // Top Header - BestBid Mobile App Style
            HomeHeader(
              searchController: _searchController,
              onSearchSubmitted: () => _loadProducts(reset: true),
              onRoleChanged: () async {
                // Refresh role first, then reload products with new role
                await _loadUserRole();
                // Clear current products to force reload
                setState(() {
                  _products = [];
                  _currentPage = 1;
                  _hasMore = true;
                });
                await _loadProducts(reset: true);
              },
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Carousel (only for buyer/company role)
                    if (_currentUserRole != 'seller_products')
                      const BannerCarousel(),

                    // Category Filter Chips (only for buyer/company role)
                    if (_currentUserRole != 'seller_products')
                      CategoryChips(
                        key: _categoryKey,
                        categories: _categories,
                        selectedCategory: _selectedCategory,
                        onCategorySelected: _onCategorySelected,
                      ),

                    const SizedBox(height: 16),

                    // Products Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Grid - 2 columns like BestBid
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
                                    Icon(Icons.error_outline, size: 48, color: _timer),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(context)?.failedToLoadProducts ?? 'Failed to load products',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => _loadProducts(reset: true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                      ),
                                      child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (_filteredProducts.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      _currentUserRole == 'seller_products' 
                                          ? Icons.inventory_2_outlined 
                                          : Icons.inbox_outlined,
                                      size: 48,
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _currentUserRole == 'seller_products'
                                          ? (AppLocalizations.of(context)?.noProductsYet ?? 'No products yet')
                                          : (AppLocalizations.of(context)?.noProductsFound ?? 'No products found'),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _currentUserRole == 'seller_products'
                                          ? (AppLocalizations.of(context)?.createFirstProduct ?? 'Create your first product to start selling')
                                          : (AppLocalizations.of(context)?.tryAdjustingSearch ?? 'Try adjusting your search or filters'),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_currentUserRole == 'seller_products') ...[
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          context.push('/product-create');
                                        },
                                        icon: const Icon(Icons.add_rounded),
                                        label: Text(AppLocalizations.of(context)?.createProduct ?? 'Create Product'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          else
                            NotificationListener<ScrollNotification>(
                              onNotification: (ScrollNotification scrollInfo) {
                                if (!_isLoadingMore &&
                                    scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                                    _hasMore &&
                                    !_loadMoreScheduled) {
                                  _loadMoreScheduled = true;
                                  SchedulerBinding.instance.addPostFrameCallback((_) {
                                    _loadMoreScheduled = false;
                                    if (mounted && !_isLoading && !_isLoadingMore && _hasMore) {
                                      setState(() {
                                        _isLoadingMore = true;
                                      });
                                      _loadProducts().then((_) {
                                        if (mounted) {
                                          setState(() {
                                            _isLoadingMore = false;
                                          });
                                        }
                                      }).catchError((_) {
                                        if (mounted) {
                                          setState(() {
                                            _isLoadingMore = false;
                                          });
                                        }
                                      });
                                    }
                                  });
                                }
                                return false;
                              },
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.70, // Adjusted for timer/price below image
                                ),
                                itemCount: _filteredProducts.length + (_hasMore && _isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _filteredProducts.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                
                                  final product = _filteredProducts[index];
                                  // Get first image URL or use placeholder
                                  final imageUrls = product.imageUrls;
                                  final imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
                                  
                                  // Determine if this is a seller product (has sellerId) vs company product
                                  final isSellerProduct = product.sellerId != null;
                                  
                                  return RepaintBoundary(
                                    child: Stack(
                                      children: [
                                        ProductCard(
                                          id: product.id.toString(),
                                          title: product.title,
                                          imageUrl: imageUrl ?? '',
                                          currentBid: (product.currentBid ?? product.startingBid ?? product.startingPrice).toInt(),
                                          totalBids: product.totalBids ?? 0,
                                          // FIX: Only show timer if auctionEndTime exists (approved products only)
                                          // Pending products will be filtered out above, so this should never be null
                                          endTime: product.auctionEndTime ?? DateTime.now().add(const Duration(days: 1)),
                                          category: product.categoryName,
                                          onTap: () {
                                            context.go('/product-details/${product.id}');
                                          },
                                        ),
                                        // Badge to distinguish product source
                                        // Note: In company_products view, only company products should show
                                        // So this badge should only show "Company" if it appears
                                        // But since we filter out seller products, this badge is mainly for edge cases
                                        if (_currentUserRole == 'company_products' && !isSellerProduct)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.blue600.withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                AppLocalizations.of(context)?.company ?? 'Company',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          // Bottom Navigation Bar - IQ BidMaster Mobile App Style
          bottomNavigationBar: _BottomNavBar(
            onCategoryTap: _showCategoryModal,
          ),
        ),
      ),
    );
  }
}

// Bottom Navigation Bar Widget - IQ BidMaster Style
class _BottomNavBar extends StatelessWidget {
  final Function(BuildContext) onCategoryTap;
  
  const _BottomNavBar({
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currentRoute = GoRouterState.of(context).uri.path;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 65, // Slightly increased height
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home,
                label: AppLocalizations.of(context)?.home ?? 'Home',
                isActive: currentRoute == '/home',
                onTap: () {
                  context.go('/home');
                },
              ),
              _BottomNavItem(
                icon: Icons.gavel,
                label: AppLocalizations.of(context)?.myBids ?? 'Bids',
                isActive: currentRoute == '/buyer-bidding-history' || 
                         currentRoute == '/buyer/bidding-history',
                onTap: () {
                  context.push('/buyer-bidding-history');
                },
              ),
              _BottomNavItem(
                icon: Icons.favorite_border,
                label: AppLocalizations.of(context)?.wishlist ?? 'Wishlist',
                isActive: currentRoute == '/wishlist',
                onTap: () {
                  context.push('/wishlist');
                },
              ),
              _BottomNavItem(
                icon: Icons.check_circle_outline,
                label: AppLocalizations.of(context)?.wins ?? 'Wins',
                isActive: currentRoute == '/wins',
                onTap: () {
                  context.push('/wins');
                },
              ),
              _BottomNavItem(
                icon: Icons.notifications_outlined,
                label: AppLocalizations.of(context)?.notification ?? 'Notification',
                isActive: currentRoute == '/notifications',
                onTap: () {
                  context.push('/notifications');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom Navigation Item Widget
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive 
                  ? AppColors.primaryBlue 
                  : (Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.textSecondaryDark 
                      : AppColors.textSecondaryLight),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive 
                    ? AppColors.primaryBlue 
                    : (Theme.of(context).brightness == Brightness.dark 
                        ? AppColors.textSecondaryDark 
                        : AppColors.textSecondaryLight),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
