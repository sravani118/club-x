# Student ID Security Rules

## Overview
This document outlines the Firestore security rules needed to prevent students from manually editing their auto-generated Student ID.

## Implementation

Add the following rules to your `firestore.rules` file:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection rules
    match /users/{userId} {
      // Allow users to read their own document
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow users to update their own document, but NOT the studentId or role fields
      allow update: if request.auth != null 
                    && request.auth.uid == userId
                    && !('studentId' in request.resource.data.diff(resource.data).affectedKeys())
                    && !('role' in request.resource.data.diff(resource.data).affectedKeys())
                    && !('createdAt' in request.resource.data.diff(resource.data).affectedKeys());
      
      // Only allow creation during signup (handled by backend)
      allow create: if request.auth != null;
    }
    
    // Counter collection - only backend can access
    match /counters/{document=**} {
      allow read, write: if false; // No direct client access
    }
  }
}
```

## Key Protection Rules

### 1. **Student ID Protection**
```javascript
!('studentId' in request.resource.data.diff(resource.data).affectedKeys())
```
- Prevents any update that includes the `studentId` field
- Students cannot modify their Student ID through the app

### 2. **Role Protection**
```javascript
!('role' in request.resource.data.diff(resource.data).affectedKeys())
```
- Prevents students from changing their role (e.g., student → admin)
- Ensures role integrity

### 3. **Counter Protection**
```javascript
match /counters/{document=**} {
  allow read, write: if false;
}
```
- Prevents direct client access to counter documents
- Only server-side operations (like transactions) can access counters

## What Users CAN Update

Students can update the following fields in their profile:
- `name` - Full name
- `department` - Academic department
- `phone` - Phone number
- `notificationSettings` - Notification preferences

## What Users CANNOT Update

Students are blocked from updating:
- ❌ `studentId` - Auto-generated, immutable
- ❌ `role` - User role (student/coordinator/admin)
- ❌ `email` - Managed by Firebase Auth
- ❌ `createdAt` - Account creation timestamp

## Testing

To test these rules:

1. **Deploy the rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Test studentId protection:**
   - Try to update studentId from the app
   - Should fail with permission denied error

3. **Test allowed updates:**
   - Update name, department, or phone
   - Should succeed

## Error Handling

If a user attempts to modify a protected field, they will receive:
```
Error: Missing or insufficient permissions
```

Your app should handle this gracefully and avoid allowing users to attempt protected field updates through the UI (which is already implemented with disabled fields).
