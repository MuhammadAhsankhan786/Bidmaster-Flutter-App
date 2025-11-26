import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../config/dev_config.dart' show AUTO_LOGIN_ENABLED, ONE_NUMBER_LOGIN_PHONE;

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
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  String _selectedCountryCode = '+964'; // Default to Iraq for backend compatibility
  bool _isLoading = false;
  bool _isPhoneValid = false;
  int _otpAttempts = 0;
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
  /// Note: Auto-fills phone only, user must enter OTP manually from SMS
  Future<void> _performAutoLogin() async {
    if (!mounted) return;
    
    final String devPhone = ONE_NUMBER_LOGIN_PHONE;
    
    if (kDebugMode) {
      print('🚀 AUTO LOGIN ENABLED - Development Mode');
      print('📱 Phone: $devPhone');
      print('⚠️ Note: OTP must be entered manually from SMS (no auto-fill)');
    }
    
    // Extract phone digits (remove +964 prefix)
    String phoneDigits = devPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (phoneDigits.startsWith('964')) {
      phoneDigits = phoneDigits.substring(3); // Remove '964' prefix
    }
    
    // Set phone number in controller
    setState(() {
      _phoneController.text = phoneDigits;
      _normalizedPhone = devPhone; // Use full phone with +964
      _isPhoneValid = true;
    });
    
    if (kDebugMode) {
      print('📱 Phone digits for input: $phoneDigits');
      print('📱 Normalized phone (will be used for OTP): $_normalizedPhone');
    }
    
    // Validate phone
    _validatePhoneNumber();
    
    // Wait before sending OTP
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Send OTP via Twilio Verify
    if (kDebugMode) {
      print('📤 Sending OTP via Twilio Verify: $_normalizedPhone');
    }
    try {
      await apiService.sendOTP(_normalizedPhone);
      if (kDebugMode) {
        print('✅ OTP sent successfully via Twilio Verify');
      }
      
      // Move to OTP screen (user must enter OTP manually)
      setState(() {
        _currentStep = 1;
      });
      
      // Show info message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚀 Auto login (Dev Mode) - Enter OTP manually from SMS'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error sending OTP: $e');
      }
      if (mounted) {
        _showError('OTP Error', 'Failed to send OTP. Please try again.');
      }
    }
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
      // Normalize phone number to match backend normalizeIraqPhone() rules
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      String normalizedPhone = '';
      
      // Apply backend normalization rules
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
      
      // Validate phone format (must start with +964 and have 9-10 digits after)
      if (!normalizedPhone.startsWith('+964')) {
        _showError('Invalid Phone Number', 'Only Iraq (+964) numbers are allowed.');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Validate phone length (Iraq format: +964 + 9-10 digits)
      final digitsAfterPrefix = normalizedPhone.substring(4); // Remove '+964'
      if (digitsAfterPrefix.length < 9 || digitsAfterPrefix.length > 10) {
        _showError('Invalid Phone Number', 'Phone number must be 9-10 digits after +964');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      _normalizedPhone = normalizedPhone;
      if (kDebugMode) {
        print('📱 Phone normalized: $_normalizedPhone');
        print('📤 Sending OTP request to backend with phone: $_normalizedPhone');
      }

      // Call POST /auth/send-otp via Twilio Verify
      await apiService.sendOTP(_normalizedPhone);
      if (kDebugMode) {
        print('✅ OTP sent successfully via Twilio Verify to: $_normalizedPhone');
      }
      
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your phone. Please check your SMS.'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        String errorMsg = 'Failed to send OTP. Please try again.';
        
        // Handle specific Twilio Verify errors
        if (e.toString().contains('404') || e.toString().contains('not registered')) {
          errorMsg = 'Phone number not registered. Please contact administrator.';
        } else if (e.toString().contains('Twilio') || e.toString().contains('SMS service')) {
          errorMsg = 'SMS service temporarily unavailable. Please try again later.';
        } else if (e.toString().contains('Invalid phone')) {
          errorMsg = 'Invalid phone number format. Please check and try again.';
        }
        
        _showError('OTP Error', errorMsg);
      }
    }
  }

  String get _enteredOTP {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _handleOTPVerify() async {
    final otp = _enteredOTP;
    if (otp.length != 6) {
      _showError('Invalid OTP', 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure we're using the entered phone, not stored phone
      if (_normalizedPhone.isEmpty) {
        // Reconstruct from controller if somehow empty
        final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        _normalizedPhone = '$_selectedCountryCode$phoneDigits';
        if (kDebugMode) {
          print('⚠️ _normalizedPhone was empty during verify, reconstructed: $_normalizedPhone');
        }
      }
      
      if (kDebugMode) {
        print('🔐 Verifying OTP via Twilio Verify');
        print('📱 Phone: $_normalizedPhone');
        // Note: OTP is hidden in logs for security
      }
      
      // Call POST /auth/verify-otp with phone + otp
      // Backend will verify OTP via Twilio Verify API
      final response = await apiService.verifyOTP(
        _normalizedPhone,
        otp,
      );
      
      if (kDebugMode) {
        print('📦 Full response from verifyOTP:');
        print('   success: ${response['success']}');
        print('   token: ${response['token'] != null ? 'present' : 'missing'}');
        print('   accessToken: ${response['accessToken'] != null ? 'present' : 'missing'}');
        print('   user: ${response['user'] != null ? 'present' : 'missing'}');
        print('   role: ${response['role']}');
      }
      
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Check if response has success and token
        final hasSuccess = response['success'] == true;
        final hasToken = response['token'] != null || response['accessToken'] != null;
        
        if (kDebugMode) {
          print('🔍 Response validation:');
          print('   success == true: $hasSuccess');
          print('   hasToken: $hasToken');
          print('   Will proceed: ${hasSuccess && hasToken}');
        }
        
        if (hasSuccess && hasToken) {
          // ✅ CONFIRMATION: OTP VERIFIED
          if (kDebugMode) {
            print('========================================');
            print('✅ OTP VERIFICATION: SUCCESS');
            print('✅ Response Success: YES');
            print('✅ Token Present: YES');
            print('========================================');
          }
          
          final user = response['user'];
          final role = (response['role'] ?? user?['role'] ?? 'buyer').toString().toLowerCase();
          
          if (kDebugMode) {
            print('✅ OTP verified successfully - Login successful');
            print('🧠 Role detected: $role');
            print('   User ID: ${user?['id'] ?? 'N/A'}');
            print('   User Name: ${user?['name'] ?? 'N/A'}');
            print('   User Email: ${user?['email'] ?? 'N/A'}');
          }
          
          // Note: verifyOTP already saves tokens and user data in api_service.dart
          // Verify token was saved
          final savedToken = await StorageService.getToken();
          if (savedToken == null) {
            if (kDebugMode) {
              print('⚠️ Warning: Token not found in storage');
            }
            // Save token if not already saved by verifyOTP
            final accessToken = response['accessToken'] ?? response['token'];
            if (accessToken != null) {
              await StorageService.saveToken(accessToken as String);
            }
          }
          
          // 🔧 FIX: Ensure user data is saved even if verifyOTP didn't save it
          final savedUserId = await StorageService.getUserId();
          final savedPhone = await StorageService.getUserPhone();
          
          if (savedUserId == null || savedPhone == null) {
            if (kDebugMode) {
              print('⚠️ Warning: User data not found in storage after OTP verification');
              print('   Attempting to save user data from response...');
            }
            
            if (user != null && user['id'] != null) {
              // Save user data from response
              await StorageService.saveUserData(
                userId: user['id'] as int,
                role: role,
                phone: _normalizedPhone,
                name: user['name'] as String?,
                email: user['email'] as String?,
              );
              if (kDebugMode) {
                print('✅ User data saved from response');
              }
            } else {
              // If user data is missing from response, try to fetch from profile
              if (kDebugMode) {
                print('⚠️ User data missing from response, fetching from profile endpoint...');
              }
              try {
                final profile = await apiService.getProfile();
                await StorageService.saveUserData(
                  userId: profile.id,
                  role: role,
                  phone: _normalizedPhone,
                  name: profile.name,
                  email: profile.email,
                );
                if (kDebugMode) {
                  print('✅ User data fetched and saved from profile endpoint');
                }
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Failed to fetch user profile: $e');
                }
                // Still save what we have (at least phone and role)
                await StorageService.saveUserData(
                  userId: 0, // Temporary - will be updated later
                  role: role,
                  phone: _normalizedPhone,
                  name: null,
                  email: null,
                );
              }
            }
          } else {
            if (kDebugMode) {
              print('✅ User data already saved in storage');
              print('   User ID: $savedUserId');
              print('   Phone: $savedPhone');
            }
          }

          // Show success message
          if (mounted) {
            final userName = user?['name'] as String?;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login successful! Welcome ${userName ?? 'to BidMaster'}'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Wait a moment for UI to update
          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) {
            if (kDebugMode) {
              print('⚠️ Widget not mounted, cannot navigate');
            }
            return;
          }

          // Always show role selection screen after login
          final userName = user?['name'] as String?;
          final userEmail = user?['email'] as String?;
          
          if (kDebugMode) {
            print('🧭 Navigation check:');
            print('   userName: ${userName ?? 'null'}');
            print('   userEmail: ${userEmail ?? 'null'}');
            print('   role: $role');
          }
          
          try {
            if (userName == null || userEmail == null) {
              // Profile incomplete - redirect to profile setup first
              if (kDebugMode) {
                print('🧭 Navigating to ProfileSetup (incomplete profile)');
              }
              if (mounted) {
                context.go('/profile-setup', extra: {'role': role});
                // ✅ CONFIRMATION: NAVIGATION ATTEMPTED
                if (kDebugMode) {
                  print('========================================');
                  print('✅ NAVIGATION: ATTEMPTED');
                  print('✅ Route: /profile-setup');
                  print('✅ Status: SUCCESS');
                  print('========================================');
                }
              }
            } else {
              // Profile complete - always show role selection to let user choose buyer/seller
              if (kDebugMode) {
                print('🧭 Navigating to RoleSelection (user can choose buyer or seller)');
              }
              if (mounted) {
                context.go('/role-selection');
                // ✅ CONFIRMATION: NAVIGATION ATTEMPTED
                if (kDebugMode) {
                  print('========================================');
                  print('✅ NAVIGATION: ATTEMPTED');
                  print('✅ Route: /role-selection');
                  print('✅ Status: SUCCESS');
                  print('========================================');
                }
              }
            }
            
            if (kDebugMode) {
              print('✅ Navigation completed');
            }
          } catch (e) {
            // ❌ CONFIRMATION: NAVIGATION FAILED
            if (kDebugMode) {
              print('========================================');
              print('❌ NAVIGATION: FAILED');
              print('❌ Error: $e');
              print('========================================');
            }
            // Fallback: try to navigate to home
            if (mounted) {
              try {
                context.go('/role-selection');
                if (kDebugMode) {
                  print('✅ Fallback navigation attempted');
                }
              } catch (e2) {
                if (kDebugMode) {
                  print('❌ Fallback navigation also failed: $e2');
                }
              }
            }
          }
        } else {
          // ❌ CONFIRMATION: OTP VERIFICATION FAILED
          if (kDebugMode) {
            print('========================================');
            print('❌ OTP VERIFICATION: FAILED');
            print('❌ Response success: ${response['success']}');
            print('❌ Token present: ${response['token'] != null || response['accessToken'] != null}');
            print('❌ NAVIGATION: NOT ATTEMPTED (verification failed)');
            print('========================================');
            print('   Full response: $response');
          }
          
          final errorMessage = response['message'] ?? 
                               response['error'] ?? 
                               'Invalid OTP. Please try again.';
          
          if (kDebugMode) {
            print('   Error message: $errorMessage');
          }
          
          _showError('Verification failed', errorMessage);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _otpAttempts++;
      });

      if (kDebugMode) {
        print('========================================');
        print('❌ OTP VERIFICATION: EXCEPTION');
        print('❌ Error: $e');
        if (e is DioException && e.response != null) {
          print('   Status Code: ${e.response?.statusCode}');
          print('   Response Data: ${e.response?.data}');
          print('   Error Message: ${e.response?.data?['message'] ?? e.response?.data?['error']}');
        }
        print('========================================');
      }

      if (_otpAttempts >= _maxOTPAttempts) {
        _showError('Too many failed attempts', 'Please request a new OTP');
      } else {
        String errorMsg = 'Invalid OTP. Please check and try again.';
        
        // Extract error message from backend response
        if (e is DioException && e.response != null) {
          final responseData = e.response?.data;
          if (responseData is Map) {
            errorMsg = responseData['message'] ?? 
                      responseData['error'] ?? 
                      'Server error. Please try again.';
            
            // If 500 error, show more details in debug mode
            if (e.response?.statusCode == 500) {
              if (kDebugMode) {
                errorMsg += '\n\nDebug: ${responseData['message'] ?? 'Internal server error'}';
              }
            }
          }
        }
        
        // Handle specific error codes
        if (e.toString().contains('500') || e.toString().contains('Internal Server Error')) {
          errorMsg = 'Server error occurred. Please try again or contact support.';
        } else if (e.toString().contains('404') || e.toString().contains('not registered')) {
          errorMsg = 'Phone number not registered. Please contact administrator.';
        } else if (e.toString().contains('Invalid OTP') || e.toString().contains('expired')) {
          errorMsg = 'Invalid or expired OTP. Please request a new OTP.';
        } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          errorMsg = 'Invalid OTP. Please check the code and try again.';
        } else if (e.toString().contains('Twilio') || e.toString().contains('SMS service')) {
          errorMsg = 'SMS service temporarily unavailable. Please try again later.';
        }
        
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
      // Ensure _normalizedPhone is set from entered phone, not stored
      if (_normalizedPhone.isEmpty) {
        // Reconstruct from controller if somehow empty
        final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        _normalizedPhone = '$_selectedCountryCode$phoneDigits';
        if (kDebugMode) {
          print('⚠️ _normalizedPhone was empty, reconstructed: $_normalizedPhone');
        }
      }
      
      if (kDebugMode) {
        print('📤 Resending OTP to: $_normalizedPhone');
      }
      
      // Call POST /auth/send-otp via Twilio Verify
      await apiService.sendOTP(_normalizedPhone);
      if (kDebugMode) {
        print('✅ OTP resent successfully via Twilio Verify to: $_normalizedPhone');
      }
      
      setState(() {
        _isLoading = false;
        // Clear OTP fields for new entry
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent to your phone. Please check your SMS.'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        String errorMsg = 'Failed to resend OTP. Please try again.';
        
        // Handle specific Twilio Verify errors
        if (e.toString().contains('404') || e.toString().contains('not registered')) {
          errorMsg = 'Phone number not registered. Please contact administrator.';
        } else if (e.toString().contains('Twilio') || e.toString().contains('SMS service')) {
          errorMsg = 'SMS service temporarily unavailable. Please try again later.';
        } else if (e.toString().contains('Invalid phone')) {
          errorMsg = 'Invalid phone number format. Please check and try again.';
        }
        
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
          "OTP will be sent to your phone via SMS",
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
            'Enter 6-digit OTP',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        const SizedBox(height: 24),

        // OTP Input (6 digits for backend)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
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
                  // Trigger rebuild to enable/disable verify button
                  setState(() {});
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
            onPressed: _isLoading || _enteredOTP.length != 6
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
