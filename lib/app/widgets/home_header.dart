import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';

class HomeHeader extends StatefulWidget {
  final TextEditingController? searchController;
  final VoidCallback? onSearchSubmitted;
  final VoidCallback? onRoleChanged;

  const HomeHeader({
    super.key,
    this.searchController,
    this.onSearchSubmitted,
    this.onRoleChanged,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  String? _currentRole;
  bool _isLoadingRole = true;
  bool _isSwitchingRole = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRole();
  }

  Future<void> _loadCurrentRole() async {
    final role = await StorageService.getUserRole();
    setState(() {
      _currentRole = role;
      _isLoadingRole = false;
    });
  }

  Future<void> _switchRole(String newRole) async {
    if (_isSwitchingRole || _currentRole == newRole) return;

    setState(() {
      _isSwitchingRole = true;
    });

    try {
      // Check token before role switch
      final token = await StorageService.getAccessToken();
      if (kDebugMode) {
        print('🔄 Role switch: Checking token before update');
        print('   Has token: ${token != null}');
        print('   Current role: $_currentRole');
        print('   New role: $newRole');
      }
      
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.go('/auth');
            }
          });
        }
        setState(() {
          _isSwitchingRole = false;
        });
        return;
      }
      
      await apiService.updateProfile(role: newRole);
      
      // Reload role from storage after update (in case it was updated by API)
      final updatedRole = await StorageService.getUserRole();
      
      setState(() {
        _currentRole = updatedRole ?? newRole;
        _isSwitchingRole = false;
      });

      // Notify parent to refresh products
      widget.onRoleChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role switched to ${newRole == 'seller_products' ? 'Seller Products' : 'Company Products'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSwitchingRole = false;
      });

      if (mounted) {
        // Check if error is due to authentication failure
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('401') || 
            errorMessage.contains('unauthorized') || 
            errorMessage.contains('token') ||
            errorMessage.contains('login') ||
            errorMessage.contains('session expired') ||
            errorMessage.contains('no access token')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.go('/auth');
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to switch role: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Hamburger Menu + Logo + Profile Icon (Mobile App Style)
          Row(
            children: [
              // Hamburger Menu Icon
              Builder(
                builder: (context) => IconButton(
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  icon: Icon(
                    Icons.menu,
                    color: colorScheme.onSurface,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Logo (Iraqi Bid text + icon)
              GestureDetector(
                onTap: () {
                  context.go('/home');
                },
                child: Row(
                  children: [
                    // Logo image - Clean and professional
                    Image.asset(
                      'assets/images/bid-logo.jpeg',
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image not found
                        if (kDebugMode) {
                          print('❌ Logo not found: assets/images/bid-logo.jpeg');
                          print('   Error: $error');
                        }
                        return Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.gavel,
                            color: colorScheme.onPrimary,
                            size: 26,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'IRAQI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'BID',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.0,
                              shadows: [
                                Shadow(
                                  color: colorScheme.primary.withOpacity(0.3),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
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
              
              const Spacer(),
              
              // Notifications icon
              IconButton(
                onPressed: () {
                  context.push('/notifications');
                },
                icon: Icon(
                  Icons.notifications_outlined,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              
              const SizedBox(width: 8),
              
              // Profile icon
              IconButton(
                onPressed: () {
                  context.push('/profile');
                },
                icon: Icon(
                  Icons.person_outline,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          // Role Buttons Row (above Search Box)
          if (!_isLoadingRole) ...[
            const SizedBox(height: 12),
            _RoleButtons(
              currentRole: _currentRole,
              isSwitching: _isSwitchingRole,
              onRoleSelected: _switchRole,
            ),
          ],
          
          // Bottom Row: Search Box
          const SizedBox(height: 12),
          _SearchBox(
            controller: widget.searchController,
            onSearchSubmitted: widget.onSearchSubmitted,
          ),
        ],
      ),
    );
  }
}

// Role Buttons Widget
class _RoleButtons extends StatelessWidget {
  final String? currentRole;
  final bool isSwitching;
  final Function(String) onRoleSelected;

  const _RoleButtons({
    required this.currentRole,
    required this.isSwitching,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final isCompanyActive = currentRole == 'company_products';
    final isSellerActive = currentRole == 'seller_products';
    
    return Row(
      children: [
        // Company Product Button
        Expanded(
          child: _RoleButton(
            label: 'Company Product',
            isActive: isCompanyActive,
            isLoading: isSwitching && !isCompanyActive,
            onTap: () => onRoleSelected('company_products'),
          ),
        ),
        const SizedBox(width: 12),
        // Seller Product Button
        Expanded(
          child: _RoleButton(
            label: 'Seller Product',
            isActive: isSellerActive,
            isLoading: isSwitching && !isSellerActive,
            onTap: () => onRoleSelected('seller_products'),
          ),
        ),
      ],
    );
  }
}

// Individual Role Button
class _RoleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary
              : (isDark
                  ? colorScheme.surfaceVariant
                  : colorScheme.surface.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isActive
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }
}

// Search Box Widget
class _SearchBox extends StatefulWidget {
  final TextEditingController? controller;
  final VoidCallback? onSearchSubmitted;

  const _SearchBox({
    this.controller,
    this.onSearchSubmitted,
  });

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    widget.controller?.clear();
                    widget.onSearchSubmitted?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface,
        ),
        onSubmitted: (value) {
          widget.onSearchSubmitted?.call();
        },
      ),
    );
  }
}

