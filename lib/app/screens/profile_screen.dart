import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../widgets/user_info_card.dart';
import '../widgets/reward_balance_card.dart';
import '../widgets/role_toggle_card.dart';
import '../widgets/theme_toggle_tile.dart';
import 'invite_and_earn_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool scrollToSettings;
  
  const ProfileScreen({super.key, this.scrollToSettings = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userName;
  String? _userPhone;
  String? _userEmail;
  String? _referralCode;
  double _rewardBalance = 0.0;
  String? _userRole;
  bool _isLoading = true;
  bool _isTogglingRole = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _settingsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  void _handleScrollToSettings() {
    // Wait for data to load and widget to be built, then scroll
    if (widget.scrollToSettings && !_isLoading) {
      // Use multiple post-frame callbacks to ensure widget is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToSettings();
        });
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSettings() {
    // Wait for the widget to be built, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_settingsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _settingsKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final name = await StorageService.getUserName();
      final phone = await StorageService.getUserPhone();
      final email = await StorageService.getUserEmail();
      final referralCode = await StorageService.getReferralCode();
      final rewardBalance = await StorageService.getRewardBalance();
      final role = await StorageService.getUserRole();

      setState(() {
        _userName = name;
        _userPhone = phone;
        _userEmail = email;
        _referralCode = referralCode;
        _rewardBalance = rewardBalance;
        _userRole = role;
        _isLoading = false;
      });
      
      // If scrollToSettings is requested, scroll after data is loaded
      if (widget.scrollToSettings) {
        _handleScrollToSettings();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRole(String newRole) async {
    if (_isTogglingRole) return;

    setState(() {
      _isTogglingRole = true;
    });

    try {
      // Call API to update role
      await apiService.updateProfile(role: newRole);

      // Update local state
      setState(() {
        _userRole = newRole;
        _isTogglingRole = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role switched to ${newRole == 'seller' ? 'Seller' : 'Buyer'}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to appropriate dashboard
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (newRole == 'seller') {
              context.go('/seller-dashboard');
            } else {
              context.go('/home');
            }
          }
        });
      }
    } catch (e) {
      setState(() {
        _isTogglingRole = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch role: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _scrollToSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Info Card
                    RepaintBoundary(
                      child: UserInfoCard(
                        userName: _userName,
                        userEmail: _userEmail,
                        userPhone: _userPhone,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Reward Balance Card
                    RepaintBoundary(
                      child: RewardBalanceCard(
                        rewardBalance: _rewardBalance,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Role Toggle Card
                    RepaintBoundary(
                      child: RoleToggleCard(
                        userRole: _userRole,
                        isTogglingRole: _isTogglingRole,
                        onRoleChanged: (bool value) {
                          _toggleRole(value ? 'seller' : 'buyer');
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Wallet Button
                    RepaintBoundary(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/wallet');
                        },
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Wallet'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Invite & Earn Button
                    RepaintBoundary(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/invite-and-earn');
                        },
                        icon: const Icon(Icons.people),
                        label: const Text('Invite & Earn'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Settings Section
                    Container(
                      key: _settingsKey,
                      child: Text(
                        'Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Theme Toggle
                    RepaintBoundary(
                      child: const ThemeToggleTile(),
                    ),

                    const SizedBox(height: 8),

                    // Role Toggle in Settings
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.swap_horiz,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Switch Role'),
                        subtitle: Text(
                          'Current: ${(_userRole == 'seller') ? 'Seller' : (_userRole == 'buyer' ? 'Buyer' : 'Not Set')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: _isTogglingRole
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: _userRole == 'seller',
                                onChanged: (bool value) {
                                  _toggleRole(value ? 'seller' : 'buyer');
                                },
                              ),
                        onTap: _isTogglingRole
                            ? null
                            : () {
                                if (_userRole == 'seller') {
                                  _toggleRole('buyer');
                                } else {
                                  _toggleRole('seller');
                                }
                              },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Logout Button
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.error),
                        title: const Text('Logout'),
                        onTap: () async {
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),
                          );

                          if (shouldLogout == true && mounted) {
                            await StorageService.clearAll();
                            if (mounted) {
                              context.go('/auth');
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

