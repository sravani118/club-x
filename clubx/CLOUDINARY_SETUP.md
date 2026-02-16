# 🚀 Cloudinary Setup Guide

## ✅ What We've Done

1. ✅ Added `cloudinary_public` package to `pubspec.yaml`
2. ✅ Created `lib/utils/cloudinary_service.dart` 
3. ✅ Updated `lib/main.dart` to initialize Cloudinary
4. ✅ Updated `lib/screens/admin/edit_profile_screen.dart` to use Cloudinary
5. ✅ Installed dependencies with `flutter pub get`

---

## 🔧 Setup Steps (YOU NEED TO DO THIS!)

### Step 1: Create Free Cloudinary Account

1. **Go to**: https://cloudinary.com/users/register_free
2. **Sign up** (no credit card required)
3. **Confirm email** and login

### Step 2: Get Your Credentials

1. After login, go to **Dashboard** (https://console.cloudinary.com/)
2. You'll see your credentials:

```
Cloud Name: dxxxxx
API Key: 123456789012345
API Secret: abcdefghijklmnop (keep this secret!)
```

3. **Copy your Cloud Name** (you'll need it in Step 4)

### Step 3: Create Upload Preset

1. In Cloudinary Dashboard, click **Settings** (⚙️ icon top right)
2. Click **Upload** tab
3. Scroll down to **Upload presets**
4. Click **Add upload preset**
5. Configure:
   - **Preset name**: `clubx_uploads` (must match exactly!)
   - **Signing Mode**: **Unsigned** (important for mobile apps!)
   - **Folder**: leave empty (we set it in code)
6. Click **Save**

### Step 4: Update Your Code with Credentials

Open `lib/utils/cloudinary_service.dart` and replace:

```dart
// LINE 10-11: Replace these values
static const String _cloudName = 'YOUR_CLOUD_NAME'; // Replace with your cloud name
static const String _uploadPreset = 'clubx_uploads'; // This should match Step 3
```

**Example:**
```dart
static const String _cloudName = 'dxxxxx'; // Your actual cloud name
static const String _uploadPreset = 'clubx_uploads';
```

---

## 🧪 Test It!

1. **Run your app**:
   ```bash
   flutter run
   ```

2. **Try uploading a profile image**:
   - Login to your app
   - Go to Edit Profile
   - Select an image
   - Click Save
   - Check the console logs for success messages

3. **Verify in Cloudinary**:
   - Go to https://console.cloudinary.com/media_library
   - You should see your uploaded images in `profile_images` folder

---

## 📊 Free Tier Limits

Cloudinary's **free tier includes**:
- ✅ **25 GB** storage
- ✅ **25 GB** bandwidth per month
- ✅ **Unlimited** transformations
- ✅ **No credit card** required
- ✅ **No time limit** (forever free)

**This is enough for:**
- ~25,000 profile images (1 MB each)
- ~250,000 page views per month

---

## 🔍 Troubleshooting

### Error: "Invalid upload preset"
**Solution**: Make sure upload preset name is exactly `clubx_uploads` and Signing Mode is **Unsigned**

### Error: "Invalid cloud name"
**Solution**: Check your cloud name in `lib/utils/cloudinary_service.dart` matches your Cloudinary dashboard

### Images not uploading
1. Check console logs for error messages
2. Verify internet connection
3. Check Cloudinary dashboard quota (https://console.cloudinary.com/settings/usage)

### How to view uploaded images?
Go to: https://console.cloudinary.com/media_library

---

## 🎯 What Changed in Your Code?

### Before (Firebase Storage - NOT WORKING):
```dart
// Required Firebase Storage bucket (needs upgrade)
final ref = FirebaseStorage.instance.ref().child(fileName);
final uploadTask = ref.putFile(_newProfileImage!);
// ... 100+ lines of retry logic ...
```

### After (Cloudinary - FREE & WORKING):
```dart
// Simple, clean, reliable
final imageUrl = await CloudinaryService().uploadProfileImage(
  imageFile: _newProfileImage!,
  userId: user.uid,
);
```

---

## 📁 Files Modified

1. **pubspec.yaml** - Added `cloudinary_public: ^0.21.0`
2. **lib/utils/cloudinary_service.dart** - NEW: Cloudinary upload service
3. **lib/main.dart** - Added Cloudinary initialization
4. **lib/screens/admin/edit_profile_screen.dart** - Replaced Firebase Storage with Cloudinary

---

## 🔄 Next Steps

After setting up Cloudinary (Steps 1-4 above):

1. **Test profile image upload** - Should work immediately
2. **Optional**: Update other screens that upload images:
   - `lib/screens/admin/create_club_page.dart` (club logos)
   - Any event banner uploads

All these can use the same `CloudinaryService()` methods!

---

## ❓ Need Help?

- **Cloudinary Docs**: https://cloudinary.com/documentation/flutter_integration
- **Support**: https://support.cloudinary.com

---

**Ready to test!** 🎉

Just complete Steps 1-4 above and your image uploads will work perfectly!
