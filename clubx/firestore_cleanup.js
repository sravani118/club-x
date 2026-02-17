// Firestore Cleanup Script
// Run this once to fix any empty string profileImage values in the database
// 
// To run this script:
// 1. Install Firebase Admin SDK: npm install firebase-admin
// 2. Download your service account key from Firebase Console
// 3. Run: node firestore_cleanup.js

const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json'); // Update this path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanupEmptyProfileImages() {
  console.log('Starting cleanup of empty profileImage values...');
  
  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.get();
    
    let updatedCount = 0;
    const batch = db.batch();
    
    snapshot.forEach((doc) => {
      const data = doc.data();
      
      // Check if profileImage exists and is an empty string
      if (data.profileImage === '') {
        console.log(`Fixing user ${doc.id}: "${data.name || 'Unknown'}" - removing empty profileImage`);
        batch.update(doc.ref, { profileImage: null });
        updatedCount++;
      }
    });
    
    if (updatedCount > 0) {
      await batch.commit();
      console.log(`\n✓ Successfully updated ${updatedCount} user(s)`);
    } else {
      console.log('\n✓ No users found with empty profileImage values');
    }
    
    console.log('Cleanup complete!');
    process.exit(0);
  } catch (error) {
    console.error('Error during cleanup:', error);
    process.exit(1);
  }
}

cleanupEmptyProfileImages();
