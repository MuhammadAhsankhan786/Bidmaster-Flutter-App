import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../config/dev_config.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _currentStep = 0; // 0: phone, 1: OTP
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );
  String _selectedCountryCode = '+964'; // Default to Iraq for backend compatibility
  bool _isLoading = false;
  bool _isPhoneValid = false;
  int _otpAttempts = 0;
  String? _receivedOTP; // Store OTP from API response for auto-fill
  String _normalizedPhone = ''; // Store normalized phone for verification

  static const int _maxOTPAttempts = 5;

  // Backend currently supports Iraq only - limiting to Iraq codes
  final List<CountryCode> _countryCodes = [
    CountryCode(code: '+964', country: '🇮🇶 Iraq', maxLength: 12), // +964 + 9-10 digits
  ];

  int get _maxPhoneLength {
    return _countryCodes
        .firstWhere((c) => c.code == _selectedCountryCode)
        .maxLength;
  }

  bool get _isPhoneNumberValid {
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    // Phone must be at least 10 digits (for countries that require it) and match the expected length
    // For countries with 9 digits, we check exact match; for others, ensure at least 10
    if (_maxPhoneLength < 10) {
      return phoneDigits.length == _maxPhoneLength;
    }
    return phoneDigits.length >= 10 && phoneDigits.length == _maxPhoneLength;
  }

  void _validatePhoneNumber() {
    final isValid = _isPhoneNumberValid;
    if (_isPhoneValid != isValid) {
      setState(() {
        _isPhoneValid = isValid;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Auto-login for development mode
    if (AUTO_LOGIN_ENABLED) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performAutoLogin();
      });
    }
  }

  /// Auto-login function (development mode)
  Future<void> _performAutoLogin() async {
    if (!mounted) return;
    
    final String devPhone = DEV_PHONES[DEFAULT_DEV_INDEX];
    
    print('🚀 AUTO LOGIN ENABLED - Development Mode');
    print('   Phone: $devPhone');
    print('   OTP: $DEFAULT_DEV_OTP');
    
    // Extract phone digits (remove +964 prefix)
    String phoneDigits = devPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (phoneDigits.startsWith('964')) {
      phoneDigits = phoneDigits.substring(3); // Remove '964' prefix
    }
    
    // Set phone number in controller
    setState(() {
      _phoneController.text = phoneDigits;
      _normalizedPhone = devPhone;
      _isPhoneValid = true;
    });
    
    // Validate phone
    _validatePhoneNumber();
    
    // Simulate phone submit delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Move to OTP screen
    setState(() {
      _currentStep = 1;
      _receivedOTP = DEFAULT_DEV_OTP;
    });
    
    // Auto-fill OTP after short delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    // Auto-fill OTP fields
    setState(() {
      for (int i = 0; i < 4 && i < DEFAULT_DEV_OTP.length; i++) {
        _otpControllers[i].text = DEFAULT_DEV_OTP[i];
      }
      _otpController.text = DEFAULT_DEV_OTP;
    });
    
    // Show info message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Auto login (Dev Mode)'),
          backgroundColor: AppColors.info,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Auto-verify after short delay
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (!mounted) return;
    
    // Trigger login automatically
    await _handleOTPVerify();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handlePhoneSubmit() async {
    // Validate Iraq (+964) restriction
    if (_selectedCountryCode != '+964') {
      _showError('Invalid Country', 'Only Iraq (+964) numbers are allowed.');
      return;
    }

    if (!_isPhoneValid) {
      _showError('Invalid phone number',
          'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Construct full phone number with country code
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      final fullPhone = '$_selectedCountryCode$phoneDigits';
      
      // Additional validation: ensure it starts with +964
      if (!fullPhone.startsWith('+964')) {
        _showError('Invalid Phone Number', 'Only Iraq (+964) numbers are allowed.');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Validate phone length (Iraq format: +964 + 9-10 digits)
      if (phoneDigits.length < 9 || phoneDigits.length > 10) {
        _showError('Invalid Phone Number', 'Phone number must be 9-10 digits after +964');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      _normalizedPhone = fullPhone;
      print('📱 Phone normalized: $_normalizedPhone');

      // Call actual sendOTP API
      final otpResponse = await apiService.sendOTP(_normalizedPhone);
      
      setState(() {
        _isLoading = false;
        _currentStep = 1;
        // Get OTP from API response (backend returns OTP in response for development)
        _receivedOTP = otpResponse['otp']?.toString() ?? '';
      });

      if (mounted) {
        final otpMessage = _receivedOTP.isNotEmpty 
            ? 'OTP sent: $_receivedOTP'
            : 'OTP sent to your phone';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(otpMessage),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 3),
          ),
        );

        // Auto-fill OTP after short delay if OTP is available
        if (_receivedOTP.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _currentStep == 1) {
              _autoFillOTP();
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final errorMsg = e.toString().contains('404')
            ? 'Phone number not registered. Please contact administrator.'
            : 'Failed to send OTP. Please try again.';
        _showError('OTP Error', errorMsg);
      }
    }
  }

  String get _enteredOTP {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _handleOTPVerify() async {
    final otp = _enteredOTP;
    if (otp.length != 4) {
      _showError('Invalid OTP', 'Please enter the 4-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use /api/auth/login-phone endpoint
      final response = await apiService.loginPhone(
        phone: _normalizedPhone,
        otp: otp,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (response['success'] == true && response['token'] != null) {
          final user = response['user'];
          // Extract role from response (backend returns role at top level and in user object)
          final role = (response['role'] ?? user['role'] ?? 'buyer').toString().toLowerCase();
          
          print('✅ Login successful - Token saved');
          print('🧠 Role detected: $role');
          print('   User ID: ${user['id']}');
          print('   User Name: ${user['name'] ?? 'N/A'}');
          print('   User Email: ${user['email'] ?? 'N/A'}');
          
          // Verify token was saved
          final savedToken = await StorageService.getToken();
          if (savedToken == null) {
            print('⚠️ Warning: Token not found in storage, saving again...');
            await StorageService.saveToken(response['token'] as String);
          }
          
          // Save user data (ensure role is saved correctly)
          await StorageService.saveUserData(
            userId: user['id'] as int,
            role: role,
            phone: user['phone'] as String,
            name: user['name'] as String?,
            email: user['email'] as String?,
          );
          
          // Verify role was saved
          final savedRole = await StorageService.getUserRole();
          print('   Verified saved role: $savedRole');

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login successful! Welcome ${user['name'] ?? 'to BidMaster'}'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Wait a moment for UI to update
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          // Dev mode: Skip profile setup redirect for auto-login
          if (AUTO_LOGIN_ENABLED && kDebugMode) {
            print('🧠 Dev mode active - skipping profile setup redirect');
            
            // Redirect based on role (skip profile setup in dev mode)
            if (role == 'buyer') {
              print('🧭 Redirecting to BuyerDashboard()');
              context.go('/home');
            } else if (role == 'seller') {
              print('🧭 Redirecting to SellerDashboard()');
              context.go('/seller-dashboard');
            } else {
              // Admin roles (superadmin, moderator, viewer) - redirect to role-selection
              // They can choose to be buyer or seller
              print('🧭 Redirecting to RoleSelection (admin role)');
              context.go('/role-selection');
            }
          } else {
            // Production mode: Check profile completion
            final userName = user['name'] as String?;
            final userEmail = user['email'] as String?;
            
            if (userName == null || userEmail == null) {
              // Profile incomplete - redirect to profile setup
              print('🧭 Redirecting to ProfileSetup (incomplete profile)');
              context.go('/profile-setup', extra: {'role': role});
            } else {
              // Profile complete - redirect based on role
              if (role == 'buyer') {
                print('🧭 Redirecting to BuyerDashboard()');
                context.go('/home');
              } else if (role == 'seller') {
                print('🧭 Redirecting to SellerDashboard()');
                context.go('/seller-dashboard');
              } else {
                // Admin or unknown role - go to role selection
                print('🧭 Redirecting to RoleSelection (unknown role: $role)');
                context.go('/role-selection');
              }
            }
          }
        } else {
          print('⚠️ Navigation blocked - Missing role or token');
          print('   Response success: ${response['success']}');
          print('   Token present: ${response['token'] != null}');
          _showError('Login failed', response['message'] ?? 'Invalid OTP. Please try again.');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _otpAttempts++;
      });

      if (_otpAttempts >= _maxOTPAttempts) {
        _showError('Too many failed attempts', 'Please request a new OTP');
      } else {
        final errorMsg = e.toString().contains('404') 
            ? 'Phone number not registered. Please contact administrator.'
            : 'Login failed. Please check your OTP and try again.';
        _showError('Verification error', errorMsg);
      }
    }
  }

  Future<void> _handleResendOTP() async {
    setState(() {
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _otpController.clear();
      _isLoading = true;
    });

    try {
      // Call actual sendOTP API
      final otpResponse = await apiService.sendOTP(_normalizedPhone);
      
      setState(() {
        _isLoading = false;
        _receivedOTP = otpResponse['otp']?.toString() ?? '';
      });

      if (mounted) {
        final otpMessage = _receivedOTP.isNotEmpty 
            ? 'OTP resent: $_receivedOTP'
            : 'OTP resent to your phone';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(otpMessage),
            backgroundColor: AppColors.info,
          ),
        );

        // Auto-fill OTP if available
        if (_receivedOTP.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _autoFillOTP();
            }
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final errorMsg = e.toString().contains('404')
            ? 'Phone number not registered. Please contact administrator.'
            : 'Failed to resend OTP. Please try again.';
        _showError('Resend OTP Error', errorMsg);
      }
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

  void _autoFillOTP() {
    if (_receivedOTP == null || _receivedOTP!.length != 4) return;
    
    setState(() {
      for (int i = 0; i < 4; i++) {
        if (i < _receivedOTP!.length) {
          _otpControllers[i].text = _receivedOTP![i];
        }
      }
      _otpController.text = _receivedOTP!;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP auto-filled. Click Verify & Continue to proceed'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Logo & Header
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.blue600, AppColors.blue700],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.gavel,
                      size: 32,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _currentStep == 0
                        ? 'Welcome to BidMaster'
                        : 'Verify Your Phone',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == 0
                        ? 'Enter your phone number to get started'
                        : 'We sent a code to $_selectedCountryCode ${_phoneController.text}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Phone Input Step
              if (_currentStep == 0) _buildPhoneStep(isDark),

              // OTP Verification Step
              if (_currentStep == 1) _buildOTPStep(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phone Number Input
        Row(
          children: [
            // Country Code Selector
            Container(
              width: 120,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  items: _countryCodes.map((country) {
                    return DropdownMenuItem<String>(
                      value: country.code,
                      child: Text(
                        '${country.country} ${country.code}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: null, // Disabled - only Iraq (+964) supported
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Phone Number Input
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_maxPhoneLength),
                ],
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone, size: 20),
                  hintText: '9876543210',
                  filled: true,
                  fillColor:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                autofocus: true,
                onChanged: (_) => _validatePhoneNumber(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          "OTP sent to your phone",
          style: Theme.of(context).textTheme.bodySmall,
        ),

        const SizedBox(height: 24),

        // Send OTP Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading || !_isPhoneValid
                ? null
                : _handlePhoneSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Send OTP'),
          ),
        ),

      ],
    );
  }

  Widget _buildOTPStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back Button
        TextButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = 0;
            });
          },
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Change phone number'),
        ),

        const SizedBox(height: 24),

        // OTP Input Label
        Center(
          child: Text(
            'Enter 4-digit OTP',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        const SizedBox(height: 24),

        // OTP Input (4 digits for backend)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              width: 48,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.blue600,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  }
                  // Update the main controller for verification check
                  _otpController.text = _enteredOTP;
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 24),

        // Resend OTP
        Center(
          child: TextButton(
            onPressed: _handleResendOTP,
            child: RichText(
              text: TextSpan(
                text: "Didn't receive the code? ",
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: 'Resend OTP',
                    style: TextStyle(
                      color: AppColors.blue600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Verify Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading || _enteredOTP.length != 4
                ? null
                : _handleOTPVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Verify & Continue'),
          ),
        ),

        const SizedBox(height: 12),

        // Security Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            '🔒 Your phone number is secure and will never be shared with third parties',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.blue700,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class CountryCode {
  final String code;
  final String country;
  final int maxLength;

  CountryCode({
    required this.code,
    required this.country,
    required this.maxLength,
  });
}

