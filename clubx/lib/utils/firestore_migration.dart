import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One-time migration script to clean up empty profileImage strings in Firestore
/// This fixes the "Invalid argument(s): No host specified in URI" error
/// 
/// To use this:
/// 1. Import this file in your main.dart or any admin screen
/// 2. Call cleanupEmptyProfileImages() once (e.g., from a debug button)
/// 3. Remove or comment out the call after running once
Future<void> cleanupEmptyProfileImages() async {
  try {
    debugPrint('Starting cleanup of empty profileImage values...');
    
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    
    int updatedCount = 0;
    final batch = FirebaseFirestore.instance.batch();
    
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final profileImage = data['profileImage'];
      
      // Check if profileImage exists and is an empty string
      if (profileImage != null && profileImage == '') {
        debugPrint('Fixing user ${doc.id}: "${data['name'] ?? 'Unknown'}" - removing empty profileImage');
        batch.update(doc.reference, {'profileImage': null});
        updatedCount++;
      }
    }
    
    if (updatedCount > 0) {
      await batch.commit();
      debugPrint('✓ Successfully updated $updatedCount user(s)');
    } else {
      debugPrint('✓ No users found with empty profileImage values');
    }
    
    debugPrint('Cleanup complete!');
  } catch (e) {
    debugPrint('Error during cleanup: $e');
    rethrow;
  }
}

/// Check if there are any users with empty profileImage strings
Future<int> countUsersWithEmptyProfileImages() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    
    int count = 0;
    for (var doc in snapshot.docs) {
      final profileImage = doc.data()['profileImage'];
      if (profileImage != null && profileImage == '') {
        count++;
      }
    }
    
    return count;
  } catch (e) {
    debugPrint('Error counting users: $e');
    return 0;
  }
}
