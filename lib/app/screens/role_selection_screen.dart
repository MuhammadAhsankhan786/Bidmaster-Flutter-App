import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../utils/jwt_utils.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;
  bool _isNavigating = false;

  final List<RoleOption> _roles = [
    RoleOption(
      id: 'buyer',
      title: 'I want to Buy',
      description: 'Browse and bid on amazing items from sellers worldwide',
      icon: Icons.shopping_bag,
      gradientColors: [AppColors.blue500, AppColors.blue600],
    ),
    RoleOption(
      id: 'seller',
      title: 'I want to Sell',
      description: 'List your items and reach thousands of potential buyers',
      icon: Icons.store,
      gradientColors: [AppColors.yellow500, AppColors.yellow600],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Header
              Text(
                'How will you use BidMaster?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select your primary role to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Role Options
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _roles.map((role) {
                      final isSelected = _selectedRole == role.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _RoleCard(
                          role: role,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedRole = role.id;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedRole == null || _isNavigating
                      ? null
                      : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.blue600.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isNavigating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Continue'),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Footer Text
              Text(
                'You can switch roles anytime in your profile settings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_selectedRole == null || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    print('🔄 Role selection: $_selectedRole');
    print('   Updating role in database via updateProfile API...');

    try {
      // 🔧 FIX: Update role in database via updateProfile API
      // This will update the database, generate new tokens with the updated role,
      // and save them to SharedPreferences
      var userId = await StorageService.getUserId();
      var phone = await StorageService.getUserPhone();
      
      // 🔧 FIX: If user data is missing, try to fetch from profile endpoint
      if (userId == null || phone == null) {
        print('⚠️ Warning: userId or phone is null, attempting to fetch from profile...');
        try {
          final profile = await apiService.getProfile();
          userId = profile.id;
          phone = profile.phone;
          
          // Save the fetched user data
          await StorageService.saveUserData(
            userId: profile.id,
            role: profile.role,
            phone: profile.phone,
            name: profile.name,
            email: profile.email,
          );
          print('✅ User data fetched and saved from profile endpoint');
        } catch (e) {
          print('❌ Failed to fetch user profile: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User data not found. Please login again.'),
                backgroundColor: Colors.red,
              ),
            );
            context.go('/auth');
          }
          setState(() {
            _isNavigating = false;
          });
          return;
        }
      }
      
      // Final check - if still null after fetch attempt, redirect to login
      if (userId == null || phone == null) {
        print('❌ Error: userId or phone is still null after fetch attempt');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User data not found. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          context.go('/auth');
        }
        setState(() {
          _isNavigating = false;
        });
        return;
      }

      // Call updateProfile API to update role in database and get new tokens
      await apiService.updateProfile(role: _selectedRole!);
      print('✅ Role updated in database via API');
      print('✅ New tokens received and saved with role: $_selectedRole');

      // Verify role was saved correctly
      final savedRole = await StorageService.getUserRole();
      final token = await StorageService.getAccessToken();
      final tokenRole = token != null ? JwtUtils.getRoleFromToken(token) : null;
      
      print('   Verified saved role: $savedRole');
      print('   Verified token role: $tokenRole');
      
      if (savedRole != _selectedRole) {
        print('⚠️ Warning: Saved role mismatch - retrying...');
        // Role should have been updated by updateProfile, but verify
        await StorageService.saveUserData(
          userId: userId,
          role: _selectedRole!,
          phone: phone,
          name: await StorageService.getUserName(),
          email: await StorageService.getUserEmail(),
        );
      }

      // Small delay for smooth visual feedback before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        print('   Navigating to /profile-setup with role: $_selectedRole');
        try {
          context.go(
            '/profile-setup',
            extra: {'role': _selectedRole},
          );
          print('✅ Navigation successful');
        } catch (e) {
          print('❌ Navigation error: $e');
          setState(() {
            _isNavigating = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error updating role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }
}

class _RoleCard extends StatefulWidget {
  final RoleOption role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_RoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? (isDark ? AppColors.blue950 : AppColors.blue50)
                    : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.blue600
                      : (isDark ? AppColors.slate800 : AppColors.slate200),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  // Icon Container
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 1.0,
                      end: widget.isSelected ? 1.1 : 1.0,
                    ),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: widget.isSelected ? 0.087 : 0.0, // ~5 degrees
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: widget.role.gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              widget.role.icon,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 16),

                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: widget.isSelected
                                    ? AppColors.blue600
                                    : null,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.role.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Selection Indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isSelected
                            ? AppColors.blue600
                            : (isDark ? AppColors.slate600 : AppColors.slate300),
                        width: 2,
                      ),
                      color: widget.isSelected ? AppColors.blue600 : Colors.transparent,
                    ),
                    child: widget.isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class RoleOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  RoleOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });
}

