import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

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
      final fullPhone = '$_selectedCountryCode${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}';
      
      // Additional validation: ensure it starts with +964
      if (!fullPhone.startsWith('+964')) {
        _showError('Invalid Phone Number', 'Only Iraq (+964) numbers are allowed.');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      _normalizedPhone = fullPhone;

      // 🧪 Mock mode: Use mock OTP for all phone numbers (API disabled)
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      setState(() {
        _isLoading = false;
        _currentStep = 1;
        _receivedOTP = '123456'; // Mock OTP for all numbers
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock OTP sent: 123456 (API disabled for testing)'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 3),
          ),
        );

        // Auto-fill OTP after short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _currentStep == 1) {
            _autoFillOTP();
          }
        });
      }
    } catch (e) {
      // Ignore errors - use mock OTP instead
      setState(() {
        _isLoading = false;
        _currentStep = 1;
        _receivedOTP = '123456'; // Fallback to mock OTP
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using mock OTP: 123456 (API error ignored)'),
            backgroundColor: AppColors.info,
            duration: Duration(seconds: 3),
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _currentStep == 1) {
            _autoFillOTP();
          }
        });
      }
    }
  }

  String get _enteredOTP {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _handleOTPVerify() async {
    final otp = _enteredOTP;
    if (otp.length != 6) {
      _showError('Invalid OTP', 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 🧪 Mock mode: Verify OTP locally (API disabled)
      // Accept mock OTP "123456" for any phone number
      if (otp == '123456') {
        // Simulate API delay
        await Future.delayed(const Duration(milliseconds: 800));
        
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          // Save phone number to storage
          await StorageService.saveUserData(
            userId: 0,
            role: 'buyer',
            phone: _normalizedPhone,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone verified! Welcome to BidMaster'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/role-selection');
        }
        return; // Skip API call
      }

      // If not mock OTP, try API call but handle errors gracefully
      try {
        final response = await apiService.verifyOTP(_normalizedPhone, otp);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          // Check if user already exists (has profile)
          if (response['token'] != null) {
            // Save phone number to storage for profile setup
            if (response['user'] != null && response['user']['phone'] != null) {
              await StorageService.saveUserData(
                userId: 0, // Will be set after registration
                role: 'buyer', // Temporary, will be set in role selection
                phone: response['user']['phone'] as String,
              );
            } else {
              // Fallback: save normalized phone
              await StorageService.saveUserData(
                userId: 0,
                role: 'buyer',
                phone: _normalizedPhone,
              );
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone verified! Welcome to BidMaster'),
                backgroundColor: AppColors.success,
              ),
            );
            context.go('/role-selection');
          } else {
            _showError('Verification failed', 'Please enter the correct OTP (use 123456 for mock)');
          }
        }
      } catch (apiError) {
        // Ignore API errors - treat as if OTP is incorrect
        setState(() {
          _isLoading = false;
          _otpAttempts++;
        });

        if (_otpAttempts >= _maxOTPAttempts) {
          _showError('Too many failed attempts',
              'Please use mock OTP: 123456');
        } else {
          _showError('Incorrect OTP', 'Please use mock OTP: 123456 (API errors ignored)');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _otpAttempts++;
      });

      if (_otpAttempts >= _maxOTPAttempts) {
        _showError('Too many failed attempts',
            'Please use mock OTP: 123456');
      } else {
        _showError('Verification error', 'Please use mock OTP: 123456');
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
      // 🧪 Mock mode: Use mock OTP (API disabled)
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      setState(() {
        _isLoading = false;
        _receivedOTP = '123456'; // Mock OTP
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock OTP resent: 123456 (API disabled)'),
            backgroundColor: AppColors.info,
          ),
        );

        // Auto-fill OTP
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _autoFillOTP();
          }
        });
      }
    } catch (e) {
      // Ignore errors - use mock OTP
      setState(() {
        _isLoading = false;
        _receivedOTP = '123456'; // Fallback to mock OTP
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock OTP: 123456 (API error ignored)'),
            backgroundColor: AppColors.info,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _autoFillOTP();
          }
        });
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
    if (_receivedOTP == null || _receivedOTP!.length != 6) return;
    
    setState(() {
      for (int i = 0; i < 6; i++) {
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
          "You'll receive a 6-digit verification code",
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

        // OTP Input
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

