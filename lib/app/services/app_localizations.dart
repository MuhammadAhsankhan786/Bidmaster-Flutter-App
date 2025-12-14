import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'language_service.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    // Always use LanguageService locale to ensure Kurdish works
    // MaterialApp might use English for Kurdish, but we use actual selected language
    final actualLocale = LanguageService.getLocale();
    return AppLocalizations(actualLocale);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Common translations
  String get appName => _localizedValues[locale.languageCode]?['appName'] ?? 'IQ BidMaster';
  String get home => _localizedValues[locale.languageCode]?['home'] ?? 'Home';
  String get transactions => _localizedValues[locale.languageCode]?['transactions'] ?? 'Transactions';
  String get contactUs => _localizedValues[locale.languageCode]?['contactUs'] ?? 'Contact Us';
  String get aboutUs => _localizedValues[locale.languageCode]?['aboutUs'] ?? 'About Us';
  String get shareApp => _localizedValues[locale.languageCode]?['shareApp'] ?? 'Share this App';
  String get loginSignUp => _localizedValues[locale.languageCode]?['loginSignUp'] ?? 'Login/Sign Up';
  String get language => _localizedValues[locale.languageCode]?['language'] ?? 'Language';
  String get notLoggedIn => _localizedValues[locale.languageCode]?['notLoggedIn'] ?? 'Not Logged In';
  String get loginRequired => _localizedValues[locale.languageCode]?['loginRequired'] ?? 'You need to be logged in to access the full features of this app';
  
  // Auth screen
  String get welcome => _localizedValues[locale.languageCode]?['welcome'] ?? 'Welcome to IQ BidMaster';
  String get enterPhone => _localizedValues[locale.languageCode]?['enterPhone'] ?? 'Enter your phone number to get started';
  String get phoneNumber => _localizedValues[locale.languageCode]?['phoneNumber'] ?? 'Phone Number';
  String get referralCode => _localizedValues[locale.languageCode]?['referralCode'] ?? 'Referral Code (Optional)';
  String get sendOtp => _localizedValues[locale.languageCode]?['sendOtp'] ?? 'Send OTP';
  String get otpSent => _localizedValues[locale.languageCode]?['otpSent'] ?? 'OTP will be sent to your phone via SMS';
  String get dontHaveAccount => _localizedValues[locale.languageCode]?['dontHaveAccount'] ?? "Don't have an account?";
  String get signUp => _localizedValues[locale.languageCode]?['signUp'] ?? 'Sign Up';
  
  // Categories
  String get categories => _localizedValues[locale.languageCode]?['categories'] ?? 'Categories';
  String get electronics => _localizedValues[locale.languageCode]?['electronics'] ?? 'Electronics';
  String get fashion => _localizedValues[locale.languageCode]?['fashion'] ?? 'Fashion';
  String get furniture => _localizedValues[locale.languageCode]?['furniture'] ?? 'Furniture';
  String get homeAppliances => _localizedValues[locale.languageCode]?['homeAppliances'] ?? 'Home Appliances';
  String get laptops => _localizedValues[locale.languageCode]?['laptops'] ?? 'Laptops';
  String get mobile => _localizedValues[locale.languageCode]?['mobile'] ?? 'Mobile';
  
  // Common
  String get search => _localizedValues[locale.languageCode]?['search'] ?? 'Search';
  String get myBids => _localizedValues[locale.languageCode]?['myBids'] ?? 'My Bids';
  String get profile => _localizedValues[locale.languageCode]?['profile'] ?? 'Profile';
  String get notifications => _localizedValues[locale.languageCode]?['notifications'] ?? 'Notifications';
  String get logout => _localizedValues[locale.languageCode]?['logout'] ?? 'Logout';
  String get settings => _localizedValues[locale.languageCode]?['settings'] ?? 'Settings';
  
  // Auth screen additional
  String get verifyPhone => _localizedValues[locale.languageCode]?['verifyPhone'] ?? 'Verify Your Phone';
  String get otpSentMessage => _localizedValues[locale.languageCode]?['otpSentMessage'] ?? 'We sent a code to';
  String get enterOtp => _localizedValues[locale.languageCode]?['enterOtp'] ?? 'Enter OTP';
  String get verify => _localizedValues[locale.languageCode]?['verify'] ?? 'Verify';
  String get resendOtp => _localizedValues[locale.languageCode]?['resendOtp'] ?? 'Resend OTP';
  String get invalidOtp => _localizedValues[locale.languageCode]?['invalidOtp'] ?? 'Invalid OTP';
  String get invalidPhone => _localizedValues[locale.languageCode]?['invalidPhone'] ?? 'Invalid Phone Number';
  String get onlyIraqNumbers => _localizedValues[locale.languageCode]?['onlyIraqNumbers'] ?? 'Only Iraq (+964) numbers are allowed.';
  String get enterValidPhone => _localizedValues[locale.languageCode]?['enterValidPhone'] ?? 'Please enter a valid phone number';
  String get phoneMustBe10Digits => _localizedValues[locale.languageCode]?['phoneMustBe10Digits'] ?? 'Phone number must be exactly 10 digits';
  String get otpSentToPhone => _localizedValues[locale.languageCode]?['otpSentToPhone'] ?? 'OTP sent to your phone. Please check your SMS.';
  String get failedToSendOtp => _localizedValues[locale.languageCode]?['failedToSendOtp'] ?? 'Failed to send OTP. Please try again.';
  String get phoneNotRegistered => _localizedValues[locale.languageCode]?['phoneNotRegistered'] ?? 'Phone number not registered. Please contact administrator.';
  String get invalidPhoneFormat => _localizedValues[locale.languageCode]?['invalidPhoneFormat'] ?? 'Invalid phone number format. Please check and try again.';
  String get enter6DigitOtp => _localizedValues[locale.languageCode]?['enter6DigitOtp'] ?? 'Please enter the 6-digit OTP';
  
  // Home screen
  String get all => _localizedValues[locale.languageCode]?['all'] ?? 'All';
  String get allProducts => _localizedValues[locale.languageCode]?['allProducts'] ?? 'All Products';
  String get selectCategory => _localizedValues[locale.languageCode]?['selectCategory'] ?? 'Select Category';
  String get failedToLoadProducts => _localizedValues[locale.languageCode]?['failedToLoadProducts'] ?? 'Failed to load products';
  String get retry => _localizedValues[locale.languageCode]?['retry'] ?? 'Retry';
  String get noProductsFound => _localizedValues[locale.languageCode]?['noProductsFound'] ?? 'No products found';
  String get tryAdjustingSearch => _localizedValues[locale.languageCode]?['tryAdjustingSearch'] ?? 'Try adjusting your search or filters';
  String get close => _localizedValues[locale.languageCode]?['close'] ?? 'Close';

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'IQ BidMaster',
      'home': 'Home',
      'transactions': 'Transactions',
      'contactUs': 'Contact Us',
      'aboutUs': 'About Us',
      'shareApp': 'Share this App',
      'loginSignUp': 'Login/Sign Up',
      'language': 'Language',
      'notLoggedIn': 'Not Logged In',
      'loginRequired': 'You need to be logged in to access the full features of this app',
      'welcome': 'Welcome to IQ BidMaster',
      'enterPhone': 'Enter your phone number to get started',
      'phoneNumber': 'Phone Number',
      'referralCode': 'Referral Code (Optional)',
      'sendOtp': 'Send OTP',
      'otpSent': 'OTP will be sent to your phone via SMS',
      'dontHaveAccount': "Don't have an account?",
      'signUp': 'Sign Up',
      'categories': 'Categories',
      'electronics': 'Electronics',
      'fashion': 'Fashion',
      'furniture': 'Furniture',
      'homeAppliances': 'Home Appliances',
      'laptops': 'Laptops',
      'mobile': 'Mobile',
      'search': 'Search',
      'myBids': 'My Bids',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'logout': 'Logout',
      'settings': 'Settings',
      'verifyPhone': 'Verify Your Phone',
      'otpSentMessage': 'We sent a code to',
      'enterOtp': 'Enter OTP',
      'verify': 'Verify',
      'resendOtp': 'Resend OTP',
      'invalidOtp': 'Invalid OTP',
      'invalidPhone': 'Invalid Phone Number',
      'onlyIraqNumbers': 'Only Iraq (+964) numbers are allowed.',
      'enterValidPhone': 'Please enter a valid phone number',
      'phoneMustBe10Digits': 'Phone number must be exactly 10 digits',
      'otpSentToPhone': 'OTP sent to your phone. Please check your SMS.',
      'failedToSendOtp': 'Failed to send OTP. Please try again.',
      'phoneNotRegistered': 'Phone number not registered. Please contact administrator.',
      'invalidPhoneFormat': 'Invalid phone number format. Please check and try again.',
      'enter6DigitOtp': 'Please enter the 6-digit OTP',
      'all': 'All',
      'allProducts': 'All Products',
      'selectCategory': 'Select Category',
      'failedToLoadProducts': 'Failed to load products',
      'retry': 'Retry',
      'noProductsFound': 'No products found',
      'tryAdjustingSearch': 'Try adjusting your search or filters',
      'close': 'Close',
    },
    'ar': {
      'appName': 'IQ BidMaster',
      'home': 'الرئيسية',
      'transactions': 'المعاملات',
      'contactUs': 'اتصل بنا',
      'aboutUs': 'من نحن',
      'shareApp': 'شارك التطبيق',
      'loginSignUp': 'تسجيل الدخول / التسجيل',
      'language': 'اللغة',
      'notLoggedIn': 'غير مسجل الدخول',
      'loginRequired': 'تحتاج إلى تسجيل الدخول للوصول إلى جميع ميزات هذا التطبيق',
      'welcome': 'مرحباً بك في IQ BidMaster',
      'enterPhone': 'أدخل رقم هاتفك للبدء',
      'phoneNumber': 'رقم الهاتف',
      'referralCode': 'رمز الإحالة (اختياري)',
      'sendOtp': 'إرسال رمز التحقق',
      'otpSent': 'سيتم إرسال رمز التحقق إلى هاتفك عبر الرسائل النصية',
      'dontHaveAccount': 'ليس لديك حساب؟',
      'signUp': 'سجل الآن',
      'categories': 'الفئات',
      'electronics': 'إلكترونيات',
      'fashion': 'أزياء',
      'furniture': 'أثاث',
      'homeAppliances': 'أجهزة منزلية',
      'laptops': 'أجهزة كمبيوتر محمولة',
      'mobile': 'جوال',
      'search': 'بحث',
      'myBids': 'مزايداتي',
      'profile': 'الملف الشخصي',
      'notifications': 'الإشعارات',
      'logout': 'تسجيل الخروج',
      'settings': 'الإعدادات',
      'verifyPhone': 'تحقق من هاتفك',
      'otpSentMessage': 'أرسلنا رمزاً إلى',
      'enterOtp': 'أدخل رمز التحقق',
      'verify': 'تحقق',
      'resendOtp': 'إعادة إرسال رمز التحقق',
      'invalidOtp': 'رمز التحقق غير صحيح',
      'invalidPhone': 'رقم الهاتف غير صحيح',
      'onlyIraqNumbers': 'يُسمح بأرقام العراق (+964) فقط.',
      'enterValidPhone': 'يرجى إدخال رقم هاتف صحيح',
      'phoneMustBe10Digits': 'يجب أن يكون رقم الهاتف 10 أرقام بالضبط',
      'otpSentToPhone': 'تم إرسال رمز التحقق إلى هاتفك. يرجى التحقق من رسائلك النصية.',
      'failedToSendOtp': 'فشل إرسال رمز التحقق. يرجى المحاولة مرة أخرى.',
      'phoneNotRegistered': 'رقم الهاتف غير مسجل. يرجى الاتصال بالمسؤول.',
      'invalidPhoneFormat': 'تنسيق رقم الهاتف غير صحيح. يرجى التحقق والمحاولة مرة أخرى.',
      'enter6DigitOtp': 'يرجى إدخال رمز التحقق المكون من 6 أرقام',
      'all': 'الكل',
      'allProducts': 'جميع المنتجات',
      'selectCategory': 'اختر الفئة',
      'failedToLoadProducts': 'فشل تحميل المنتجات',
      'retry': 'إعادة المحاولة',
      'noProductsFound': 'لم يتم العثور على منتجات',
      'tryAdjustingSearch': 'حاول تعديل البحث أو المرشحات',
      'close': 'إغلاق',
    },
    'ku': {
      'appName': 'IQ BidMaster',
      'home': 'سەرەکی',
      'transactions': 'مامەڵەکان',
      'contactUs': 'پەیوەندی',
      'aboutUs': 'دەربارەمان',
      'shareApp': 'ئەپەکە هاوبەش بکە',
      'loginSignUp': 'چوونەژوورەوە / خۆتۆمارکردن',
      'language': 'زمان',
      'notLoggedIn': 'چوونەژوورەوە نەکراوە',
      'loginRequired': 'پێویستە چوونەژوورەوە بکەیت بۆ دەستگەیشتن بە هەموو تایبەتمەندیەکانی ئەم ئەپە',
      'welcome': 'بەخێربێیت بۆ IQ BidMaster',
      'enterPhone': 'ژمارەی تەلەفۆنەکەت بنووسە بۆ دەستپێکردن',
      'phoneNumber': 'ژمارەی تەلەفۆن',
      'referralCode': 'کۆدی داواتکردن (دڵخواز)',
      'sendOtp': 'کۆدی پشتڕاستکردنەوە بنێرە',
      'otpSent': 'کۆدی پشتڕاستکردنەوە بە پەیامی دەستنووس بۆ تەلەفۆنەکەت دەنێردرێت',
      'dontHaveAccount': 'هیژمارت نییە؟',
      'signUp': 'خۆتۆمار بکە',
      'categories': 'بەشەکان',
      'electronics': 'ئەلیکترۆنی',
      'fashion': 'فەیشن',
      'furniture': 'فرنیچەر',
      'homeAppliances': 'ئامێرەکانی ماڵ',
      'laptops': 'لێپتۆپ',
      'mobile': 'مۆبایل',
      'search': 'گەڕان',
      'myBids': 'مزایندەکانم',
      'profile': 'پرۆفایل',
      'notifications': 'ئاگاداریەکان',
      'logout': 'دەرچوون',
      'settings': 'ڕێکخستنەکان',
      'verifyPhone': 'تەلەفۆنەکەت پشتڕاست بکەوە',
      'otpSentMessage': 'کۆدێکمان نارد بۆ',
      'enterOtp': 'کۆدی پشتڕاستکردنەوە بنووسە',
      'verify': 'پشتڕاست بکەوە',
      'resendOtp': 'دووبارە کۆد بنێرە',
      'invalidOtp': 'کۆدی پشتڕاستکردنەوە نادروستە',
      'invalidPhone': 'ژمارەی تەلەفۆن نادروستە',
      'onlyIraqNumbers': 'تەنها ژمارەکانی عێراق (+964) ڕێگەپێدراون.',
      'enterValidPhone': 'تکایە ژمارەیەکی تەلەفۆنی دروست بنووسە',
      'phoneMustBe10Digits': 'ژمارەی تەلەفۆن دەبێت بەتەواوی 10 ژمارە بێت',
      'otpSentToPhone': 'کۆدی پشتڕاستکردنەوە نێردرا بۆ تەلەفۆنەکەت. تکایە پەیامەکەت بپشکنە.',
      'failedToSendOtp': 'ناردنی کۆدی پشتڕاستکردنەوە سەرکەوتوو نەبوو. تکایە دووبارە هەوڵ بدە.',
      'phoneNotRegistered': 'ژمارەی تەلەفۆن تۆمار نەکراوە. تکایە پەیوەندی بە بەڕێوەبەرەوە بکە.',
      'invalidPhoneFormat': 'شێوەی ژمارەی تەلەفۆن نادروستە. تکایە پشکنین بکە و دووبارە هەوڵ بدە.',
      'enter6DigitOtp': 'تکایە کۆدی پشتڕاستکردنەوەی 6 ژمارەیی بنووسە',
      'all': 'هەموو',
      'allProducts': 'هەموو بەرهەمەکان',
      'selectCategory': 'بەش هەڵبژێرە',
      'failedToLoadProducts': 'بارکردنی بەرهەمەکان سەرکەوتوو نەبوو',
      'retry': 'دووبارە هەوڵ بدە',
      'noProductsFound': 'هیچ بەرهەمێک نەدۆزرایەوە',
      'tryAdjustingSearch': 'هەوڵ بدە گەڕان یان فیلتەرەکان دەستکاری بکەیت',
      'close': 'داخستن',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar', 'ku'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Always use the locale from LanguageService to ensure Kurdish works
    final actualLocale = LanguageService.getLocale();
    return AppLocalizations(actualLocale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

