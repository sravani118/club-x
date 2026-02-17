# Role-Based Navigation Fix - Test Scenarios

## Issue Fixed
When an admin changes a user's role to "coordinator", upon login, the user was being redirected to the home page instead of the coordinator dashboard.

## Files Modified

### 1. lib/screens/auth/login_screen.dart
**Change:** Added coordinator role check in login navigation logic
- **Before:** Only checked for 'admin', everyone else went to '/home'
- **After:** Checks for 'admin' → '/admin', 'coordinator' → '/coordinator', others → '/home'

### 2. lib/screens/splash_screen.dart  
**Change:** Added auth state persistence with role-based navigation
- **Before:** Always navigated to '/landing' regardless of login state
- **After:** Checks if user is logged in and routes to appropriate dashboard based on role

## How to Test

### Test Case 1: New Coordinator Login
1. As admin, change an existing user's role to "coordinator" in Firestore
2. Logout from the app
3. Login with that user's credentials
4. **Expected Result:** User should be redirected to Coordinator Dashboard with bottom navigation

### Test Case 2: Persistent Login for Coordinator
1. Login as a coordinator
2. Close the app (don't logout)
3. Reopen the app
4. **Expected Result:** After splash screen, user should be automatically redirected to Coordinator Dashboard

### Test Case 3: Admin Login
1. Login with admin credentials (admin@gmail.com)
2. **Expected Result:** Redirected to Admin Dashboard

### Test Case 4: Student Login
1. Login with student credentials
2. **Expected Result:** Redirected to Home Screen

## Navigation Flow After Fix

```
Splash Screen
    ↓
Check Auth State
    ↓
If Logged In → Get User Role from Firestore
    ├─ role == 'admin' → /admin (Admin Dashboard)
    ├─ role == 'coordinator' → /coordinator (Coordinator Dashboard)
    └─ role == 'student' → /home (Home Screen)
    
If Not Logged In
    └─ /landing → Login → Same role check as above
```

## Verification Checklist
- [✓] Login screen checks for coordinator role
- [✓] Splash screen handles persistent auth state
- [✓] Coordinator Dashboard route exists in app_router
- [✓] All changes compile without errors
- [✓] No breaking changes to admin or student flows

## Next Steps for Full Testing
1. Run the app: `flutter run`
2. Test each scenario above
3. Verify Firestore data structure matches expected format:
   ```
   users/{userId}
     - email: string
     - role: string ('admin' | 'coordinator' | 'student')
     - name: string
     - clubId: string (for coordinators)
   ```
