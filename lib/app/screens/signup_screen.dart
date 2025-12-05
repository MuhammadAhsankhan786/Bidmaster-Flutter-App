import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SignupScreen extends StatefulWidget {
  final String? selectedRole; // 'company_products' or 'seller_products'
  
  const SignupScreen({
    super.key,
    this.selectedRole,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  
  String _selectedCountryCode = '+964'; // Default to Iraq
  bool _isLoading = false;
  bool _isPhoneValid = false;

  // No hardcoded colors - using theme colors

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _validatePhoneNumber() {
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    final isValid = phoneDigits.length >= 9 && phoneDigits.length <= 10;
    if (_isPhoneValid != isValid) {
      setState(() {
        _isPhoneValid = isValid;
      });
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isPhoneValid) {
      _showError('Invalid Phone Number', 'Please enter a valid phone number');
      return;
    }

    if (widget.selectedRole == null) {
      _showError('Role Required', 'Please select a role first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Normalize phone number
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      String normalizedPhone = '';
      
      if (phoneDigits.startsWith('0')) {
        normalizedPhone = '+964${phoneDigits.substring(1)}';
      } else if (phoneDigits.startsWith('00964')) {
        normalizedPhone = '+964${phoneDigits.substring(5)}';
      } else if (phoneDigits.startsWith('964')) {
        normalizedPhone = '+$phoneDigits';
      } else if (_selectedCountryCode == '+964') {
        normalizedPhone = '$_selectedCountryCode$phoneDigits';
      } else {
        _showError('Invalid Phone Number', 'Only Iraq (+964) numbers are allowed.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Validate phone format
      if (!normalizedPhone.startsWith('+964')) {
        _showError('Invalid Phone Number', 'Only Iraq (+964) numbers are allowed.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final digitsAfterPrefix = normalizedPhone.substring(4);
      if (digitsAfterPrefix.length < 9 || digitsAfterPrefix.length > 10) {
        _showError('Invalid Phone Number', 'Phone number must be 9-10 digits after +964');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Call register API
      // Note: Backend might require password, but we'll use a temporary one or check if OTP-based registration is supported
      // For now, using a temporary password that user won't need (since login is OTP-based)
      final response = await apiService.register(
        name: _fullNameController.text.trim(),
        phone: normalizedPhone,
        email: null, // Optional
        password: 'temp_password_${normalizedPhone}', // Temporary password (user will login with OTP)
        role: widget.selectedRole!,
      );

      // Save user data
      final user = response['user'];
      final accessToken = response['accessToken'] ?? response['token'];
      final refreshToken = response['refreshToken'];

      if (accessToken != null) {
        if (refreshToken != null) {
          await StorageService.saveTokens(
            accessToken: accessToken as String,
            refreshToken: refreshToken as String,
          );
        } else {
          await StorageService.saveAccessToken(accessToken as String);
        }
      }

      // Save user data
      if (user != null) {
        await StorageService.saveUserData(
          userId: user['id'] as int,
          role: widget.selectedRole!,
          phone: normalizedPhone,
          name: _fullNameController.text.trim(),
          email: user['email'] as String?,
        );
      }

      // Try to update profile with city and area (if backend supports it)
      try {
        // Note: This might fail if backend doesn't support city/area yet
        // But registration will still succeed
        await apiService.updateProfile(
          name: _fullNameController.text.trim(),
        );
        // If backend adds city/area support, we can add them here:
        // await apiService.updateProfile(city: _cityController.text.trim(), area: _areaController.text.trim());
      } catch (e) {
        // Profile update failed, but registration succeeded - that's okay
        if (kDebugMode) {
          print('⚠️ Could not update profile with city/area: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! You can now login with your phone number.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to home or appropriate dashboard
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          if (widget.selectedRole == 'company_products') {
            context.go('/home');
          } else if (widget.selectedRole == 'seller_products') {
            context.go('/seller-dashboard');
          } else {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMsg = 'Failed to create account. Please try again.';
      if (e.toString().contains('already exists') || e.toString().contains('duplicate')) {
        errorMsg = 'This phone number is already registered. Please login instead.';
      } else if (e.toString().contains('Invalid phone')) {
        errorMsg = 'Invalid phone number format. Please check and try again.';
      }

      _showError('Signup Error', errorMsg);
    }
  }

  void _showError(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_add,
                        size: 32,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Create Your Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in your details to get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.person_outline, color: colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Phone Number
                Row(
                  children: [
                    // Country Code
                    Container(
                      width: 120,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.onSurface.withOpacity(0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          icon: Icon(Icons.arrow_drop_down, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
                          style: TextStyle(color: colorScheme.onSurface),
                          items: [
                            DropdownMenuItem<String>(
                              value: '+964',
                              child: Text('🇮🇶 +964', style: TextStyle(color: colorScheme.onSurface)),
                            ),
                          ],
                          onChanged: null, // Only Iraq supported
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Phone Number Input
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.phone, size: 20, color: colorScheme.onSurface.withOpacity(0.7)),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                          if (digits.length < 9 || digits.length > 10) {
                            return 'Phone number must be 9-10 digits';
                          }
                          return null;
                        },
                        onChanged: (_) => _validatePhoneNumber(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // City
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.location_city_outlined, color: colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your city';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Area
                TextFormField(
                  controller: _areaController,
                  decoration: InputDecoration(
                    labelText: 'Area',
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.location_on_outlined, color: colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your area';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Sign Up Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.cardWhite),
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.go('/auth');
                      },
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
