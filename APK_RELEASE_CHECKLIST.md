# APK Release Checklist - White Screen Prevention

## ✅ Fixed Issues

### 1. API URL Configuration
- ✅ Updated to use environment variable
- ✅ Added fallback for release mode
- ⚠️ **ACTION REQUIRED**: Set production API URL before release

### 2. Android Permissions
- ✅ Added INTERNET permission
- ✅ Added ACCESS_NETWORK_STATE permission

### 3. Error Handling
- ✅ SharedPreferences initialized before navigation
- ✅ Auto-login check added
- ✅ Token validation added

## ⚠️ Before Releasing APK

### Step 1: Set Production API URL

**Option A: Using Environment Variable (Recommended)**

1. Create `.env` file:
```bash
cd "bidmaster flutter"
cp .env.example .env
```

2. Edit `.env` and add your production URL:
```
API_BASE_URL=https://your-production-server.com/api
```

3. Update `api_service.dart` to read from .env:
```dart
// Add flutter_dotenv import
import 'package:flutter_dotenv/flutter_dotenv.dart';

// In baseUrl getter:
return dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api';
```

**Option B: Direct URL in Code**

Edit `lib/app/services/api_service.dart`:
```dart
// Release mode
return 'https://your-production-server.com/api';
```

### Step 2: Test Release Build

```bash
# Build release APK
flutter build apk --release

# Test on device
flutter install --release
```

### Step 3: Check for White Screen

**Common Causes:**
1. ❌ API URL not set → Connection fails → White screen
2. ❌ Missing internet permission → No network access → White screen
3. ❌ Unhandled errors → App crashes → White screen
4. ❌ Missing assets → App fails to load → White screen

**Testing:**
1. Install APK on device
2. Check if app loads (not white screen)
3. Test login flow
4. Test API calls
5. Check logs: `adb logcat | grep flutter`

## 🔍 Debug White Screen Issues

### Check Logs
```bash
# Android logs
adb logcat | grep -E "flutter|BidMaster"

# Check for errors
adb logcat | grep -i error
```

### Common Fixes

1. **API Connection Failed**
   - Check API URL is correct
   - Check server is running
   - Check network connectivity

2. **Permission Denied**
   - Verify AndroidManifest has INTERNET permission
   - Check app permissions in device settings

3. **Asset Loading Failed**
   - Verify all assets exist in `assets/` folder
   - Check `pubspec.yaml` has correct asset paths

4. **Unhandled Exception**
   - Check `main.dart` has error handling
   - Add try-catch blocks in critical code

## ✅ Current Status

- ✅ Internet permission added
- ✅ API URL configuration updated
- ✅ Error handling improved
- ⚠️ **TODO**: Set production API URL before release

## 🚀 Release Commands

```bash
# 1. Set production API URL in .env or api_service.dart

# 2. Build release APK
flutter build apk --release

# 3. Build app bundle (for Play Store)
flutter build appbundle --release

# 4. Test APK
flutter install --release
```

## 📝 Notes

- **Localhost won't work on real device** - Use production URL or local network IP
- **HTTPS recommended** for production
- **Test thoroughly** before releasing
- **Check logs** if white screen appears

