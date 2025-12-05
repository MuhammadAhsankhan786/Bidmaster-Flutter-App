import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import '../widgets/home_header.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/category_chips.dart';
import '../widgets/product_card.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import '../models/product_model.dart';

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
    _loadCategories();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
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

  void _onSearchChanged() {
    // Debounce search - reload after user stops typing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == _searchController.text) {
        _loadProducts(reset: true);
      }
    });
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
      final result = await apiService.getAllProducts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        page: _currentPage,
        limit: 20,
      );

      final newProducts = result['products'] as List<ProductModel>;
      final pagination = result['pagination'] as Map<String, dynamic>;

      setState(() {
        if (reset) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }
        _currentPage = pagination['page'] as int;
        _hasMore = _currentPage < (pagination['pages'] as int);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<ProductModel> get _filteredProducts {
    // Backend already filters by category and search, but we can do client-side filtering if needed
    return _products;
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
                color: isDark ? Colors.grey[700] : Colors.grey[300],
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
                    'Select Category',
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
                      category == 'All' ? 'All Products' : category,
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
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header - BestBid Mobile App Style
            HomeHeader(
              searchController: _searchController,
              onSearchSubmitted: () => _loadProducts(reset: true),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Carousel
                    const BannerCarousel(),

                    // Category Filter Chips
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
                                      'Failed to load products',
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
                                      child: const Text('Retry'),
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
                                    Icon(Icons.inbox_outlined, size: 48, color: colorScheme.onSurface.withOpacity(0.6)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No products found',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search or filters',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
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
                                  childAspectRatio: 0.98, // Increased to prevent overflow on all devices
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
                                  
                                  return RepaintBoundary(
                                    child: ProductCard(
                                      id: product.id.toString(),
                                      title: product.title,
                                      imageUrl: imageUrl ?? '',
                                      currentBid: (product.currentBid ?? product.startingBid ?? product.startingPrice).toInt(),
                                      totalBids: product.totalBids ?? 0,
                                      endTime: product.auctionEndTime ?? DateTime.now().add(const Duration(days: 7)),
                                      category: product.categoryName,
                                      onTap: () {
                                        context.go('/product-details/${product.id}');
                                      },
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
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home,
                label: 'Home',
                isActive: currentRoute == '/home',
                onTap: () {
                  context.go('/home');
                },
              ),
              _BottomNavItem(
                icon: Icons.category,
                label: 'Categories',
                isActive: false, // Categories doesn't have a dedicated route
                onTap: () {
                  // Show category selection modal
                  onCategoryTap(context);
                },
              ),
              _BottomNavItem(
                icon: Icons.gavel,
                label: 'My Bids',
                isActive: currentRoute == '/buyer-bidding-history' || 
                         currentRoute == '/buyer/bidding-history',
                onTap: () {
                  context.push('/buyer-bidding-history');
                },
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                isActive: currentRoute == '/profile',
                onTap: () {
                  context.push('/profile');
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
