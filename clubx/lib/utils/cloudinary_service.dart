import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // TODO: Replace with your Cloudinary credentials
  static const String _cloudName = 'dp24jeomh'; // e.g., 'dxxxxx'
  static const String _uploadPreset = 'clubx_uploads'; // Create this in Cloudinary dashboard
  
  late final CloudinaryPublic _cloudinary;
  
  void initialize() {
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
    debugPrint('✅ [CLOUDINARY] Initialized with cloud: $_cloudName');
  }

  /// Upload profile image to Cloudinary
  /// Returns the secure URL of the uploaded image
  Future<String> uploadProfileImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      debugPrint('🚀 [CLOUDINARY] Starting upload for user: $userId');
      debugPrint('📁 [CLOUDINARY] File path: ${imageFile.path}');
      
      // Validate file exists
      final fileExists = await imageFile.exists();
      if (!fileExists) {
        throw Exception('Image file does not exist');
      }
      
      // Get file size
      final fileSize = await imageFile.length();
      debugPrint('📊 [CLOUDINARY] File size: ${fileSize ~/ 1024} KB');
      
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }
      
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image file is too large (max 10MB)');
      }
      
      // Upload to Cloudinary with retry logic
      int attempts = 0;
      const maxAttempts = 3;
      CloudinaryResponse? response;
      
      while (attempts < maxAttempts) {
        attempts++;
        debugPrint('🔄 [CLOUDINARY] Upload attempt $attempts/$maxAttempts');
        
        try {
          response = await _cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              imageFile.path,
              folder: 'profile_images',
              resourceType: CloudinaryResourceType.Image,
              context: {
                'userId': userId,
                'uploadedAt': DateTime.now().toIso8601String(),
              },
            ),
          );
          
          debugPrint('✅ [CLOUDINARY] Upload completed on attempt $attempts');
          break;
          
        } catch (e) {
          debugPrint('❌ [CLOUDINARY] Upload attempt $attempts failed: $e');
          
          if (attempts >= maxAttempts) {
            debugPrint('❌ [CLOUDINARY] All upload attempts exhausted');
            rethrow;
          }
          
          // Wait before retry with exponential backoff
          final waitTime = attempts * 2;
          debugPrint('⏳ [CLOUDINARY] Waiting ${waitTime}s before retry...');
          await Future.delayed(Duration(seconds: waitTime));
        }
      }
      
      if (response == null) {
        throw Exception('Upload failed - no response received');
      }
      
      final imageUrl = response.secureUrl;
      debugPrint('🔗 [CLOUDINARY] Image URL: $imageUrl');
      debugPrint('🎉 [CLOUDINARY] Upload completed successfully!');
      
      return imageUrl;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [CLOUDINARY] Critical error during upload: $e');
      debugPrint('📋 [CLOUDINARY] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload club logo to Cloudinary
  Future<String> uploadClubLogo({
    required File imageFile,
    required String clubId,
  }) async {
    try {
      debugPrint('🚀 [CLOUDINARY] Starting club logo upload for club: $clubId');
      
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'club_logos',
          resourceType: CloudinaryResourceType.Image,
          context: {
            'clubId': clubId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      debugPrint('✅ [CLOUDINARY] Club logo uploaded: ${response.secureUrl}');
      return response.secureUrl;
      
    } catch (e) {
      debugPrint('❌ [CLOUDINARY] Club logo upload failed: $e');
      rethrow;
    }
  }

  /// Upload event banner to Cloudinary
  Future<String> uploadEventBanner({
    required File imageFile,
    required String eventId,
  }) async {
    try {
      debugPrint('🚀 [CLOUDINARY] Starting event banner upload for event: $eventId');
      
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'event_banners',
          resourceType: CloudinaryResourceType.Image,
          context: {
            'eventId': eventId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      debugPrint('✅ [CLOUDINARY] Event banner uploaded: ${response.secureUrl}');
      return response.secureUrl;
      
    } catch (e) {
      debugPrint('❌ [CLOUDINARY] Event banner upload failed: $e');
      rethrow;
    }
  }

  /// Delete image from Cloudinary (requires public_id)
  /// Note: For free accounts, deletion requires admin API
  /// For now, old images will remain in Cloudinary
  Future<void> deleteImage(String publicId) async {
    debugPrint('⚠️ [CLOUDINARY] Image deletion requires admin API (not available in free tier)');
    debugPrint('💡 [CLOUDINARY] Old images will remain but won\'t affect your app');
    // Deletion would require backend API call with API secret
  }
}
