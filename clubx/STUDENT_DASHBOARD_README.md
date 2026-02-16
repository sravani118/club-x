# Student Dashboard - ClubX App

## Overview
Complete, production-ready Student Dashboard with 5-tab bottom navigation, club join approval system, event registration, and QR code generation for event attendance.

## 🎨 Theme
- **Background**: Dark navy (#0F1B2D)
- **Cards**: #1A2840
- **Accent**: Orange (#FF6B2C)
- **Text**: White & Grey
- **Border Radius**: 16px
- **Material 3**: Enabled

## 📱 Bottom Navigation Structure

### 5 Tabs:
1. **Home** (Icons.home)
2. **Clubs** (Icons.groups)
3. **Events** (Icons.event)
4. **My Activity** (Icons.qr_code)
5. **Profile** (Icons.person)

---

## 📄 Screen Details

### 1️⃣ Home Screen
**File**: `student_home_screen.dart`

**Features**:
- Personalized greeting with student name
- Real-time stats cards:
  - Joined Clubs count
  - Pending Join Requests count
- Upcoming registered events list
- Event cards showing:
  - Title, date, time
  - Club name
  - Venue
  - Status badge (Upcoming/Ongoing/Completed)

**Real-time Updates**: Uses `StreamBuilder` for live data

---

### 2️⃣ Clubs Screen (Approval System)
**File**: `student_clubs_screen.dart`

**Features**:
- Browse all active clubs
- Search functionality
- Category filter (All, Technical, Cultural, Sports, Arts, Social)
- Club cards display:
  - Logo
  - Name & Category
  - Description
  - Member count (current/max)
  - Main coordinator name
  - Join button / Status badge

**Join Request System**:

1. **Request to Join Button**:
   - Validates max 2 clubs per student
   - Checks if club is full
   - Prevents duplicate requests
   - Creates document in `clubJoinRequests`
   - Status: "pending"

2. **Status Display**:
   - **Pending**: Orange badge "Pending Approval"
   - **Approved**: Green badge "Joined" + Leave button
   - **Rejected**: Red badge "Rejected" + Request Again button

3. **Leave Club**:
   - Confirmation dialog
   - Deletes join request
   - Decrements club member count

**Validations**:
- ✅ Max 2 clubs per student
- ✅ Club must be active
- ✅ Club not full
- ✅ No duplicate requests

---

### 3️⃣ Events Screen
**File**: `student_events_screen.dart`

**Features**:
- Shows events from joined clubs only
- Filter by status (All, Upcoming, Ongoing, Completed)
- Event cards display:
  - Banner image
  - Title & status badge
  - Date, time, venue
  - Club name
  - Capacity (registered/max)
  - Register button / Registered badge

**Event Registration Logic**:

1. **Register Button**:
   - Checks if already registered
   - Validates event capacity
   - Creates document in `eventRegistrations`
   - Increments `registeredCount`
   - Generates QR data: `{eventId}_{studentId}`

2. **Status Display**:
   - **Registered**: Green badge with checkmark
   - **Completed**: Grey badge (disabled)
   - **Available**: Orange register button

**Validations**:
- ✅ Cannot register twice
- ✅ Cannot exceed max capacity
- ✅ Must be club member
- ✅ Event must not be inactive

---

### 4️⃣ My Activity Screen
**File**: `student_activity_screen.dart`

**Features**: 4 Tabs

#### Tab 1: Joined Clubs
- List of all approved clubs
- Club logo, name, category
- Green checkmark indicator

#### Tab 2: Registered Events
- All registered events
- Event title & date
- **QR Code Button** for upcoming/ongoing events
- QR dialog with:
  - Event name
  - Scannable QR code (250x250)
  - Close button

#### Tab 3: Attendance History
- Past events attended
- Check-in timestamp
- Event name
- Green check indicator

#### Tab 4: Join Requests
- All join requests history
- Status indicators:
  - Pending: Orange hourglass
  - Approved: Green checkmark
  - Rejected: Red cancel icon

**QR Code Generation**:
- Uses `qr_flutter` package
- Data format: `{eventId}_{studentId}`
- White background, 250x250 size
- Modal dialog display

---

### 5️⃣ Profile Screen
**File**: `student_profile_screen.dart`

**Features**:
- Profile avatar (photo or initial)
- Name & email
- Stats card:
  - Joined clubs count
  - Registered events count
  - Attendance count

**Profile Options**:
- Account Information
- Notifications
- Help & Support
- About (shows version info)

**Logout**:
- Confirmation dialog
- Signs out from Firebase
- Navigates to `/landing`
- Clears navigation stack

---

## 🗄️ Firestore Structure

### Collections:

#### 1. `clubs`
```dart
{
  name: String,
  category: String,
  description: String,
  logoUrl: String?,
  maxMembers: int,
  currentMembers: int,
  mainCoordinatorId: String,
  status: String, // "active" or "inactive"
}
```

#### 2. `clubJoinRequests`
Document ID: `{clubId}_{studentId}`
```dart
{
  clubId: String,
  studentId: String,
  studentName: String,
  status: String, // "pending", "approved", "rejected"
  requestedAt: Timestamp,
}
```

#### 3. `events`
```dart
{
  clubId: String,
  title: String,
  description: String?,
  bannerUrl: String?,
  date: Timestamp,
  venue: String?,
  maxCapacity: int,
  registeredCount: int,
  status: String, // "upcoming", "ongoing", "completed", "inactive"
}
```

#### 4. `eventRegistrations`
Document ID: `{eventId}_{studentId}`
```dart
{
  eventId: String,
  studentId: String,
  registeredAt: Timestamp,
  qrData: String, // "{eventId}_{studentId}"
}
```

#### 5. `attendance`
```dart
{
  eventId: String,
  studentId: String,
  checkInTime: Timestamp,
}
```

#### 6. `users`
```dart
{
  name: String,
  email: String,
  role: String, // "student", "coordinator", "admin"
  photoUrl: String?,
  createdAt: Timestamp,
}
```

---

## 🔧 Key Features

### Real-time Updates
- All screens use `StreamBuilder` for live data
- Instant UI updates when data changes
- No manual refresh needed

### Validation Logic
- ✅ Max 2 clubs per student
- ✅ Cannot join inactive clubs
- ✅ Cannot exceed club capacity
- ✅ Cannot register for events without club membership
- ✅ Cannot register twice for same event
- ✅ Cannot register if event full

### User Experience
- Loading indicators during data fetch
- Success/error SnackBar messages
- Confirmation dialogs for destructive actions
- Smooth animations
- Clean spacing (24px padding)
- Rounded cards (16px)
- Premium SaaS look

### Navigation
- Bottom navigation with 5 tabs
- Selected state with orange highlight
- Icon + label display
- Smooth transitions

---

## 🚀 Routes

### Updated Routes:
```dart
/student       → StudentDashboard
/admin         → AdminDashboard
/coordinator   → CoordinatorDashboard
/landing       → LandingScreen
/login         → LoginScreen
/signup        → SignupScreen
```

### Automatic Routing:
- **SplashScreen**: Routes based on user role
- **LoginScreen**: Routes students to `/student`
- **SignupScreen**: Routes students to `/student`

---

## 📦 Dependencies Used

```yaml
firebase_core: ^3.8.1
firebase_auth: ^5.3.4
cloud_firestore: ^5.5.2
go_router: ^14.7.1
qr_flutter: ^4.1.0
intl: ^0.20.1
```

---

## 📂 File Structure

```
lib/screens/student/
├── student_dashboard.dart          # Main container with bottom nav
├── student_home_screen.dart        # Home tab
├── student_clubs_screen.dart       # Clubs tab (approval system)
├── student_events_screen.dart      # Events tab (registration)
├── student_activity_screen.dart    # My Activity tab (4 sections)
└── student_profile_screen.dart     # Profile tab (logout)
```

---

## 🎯 Production Ready

### Scalability:
- Efficient Firestore queries with proper indexing
- Pagination support structure
- Optimized image loading with error handlers

### Error Handling:
- Try-catch blocks for all async operations
- User-friendly error messages
- Graceful fallbacks for missing data

### Code Quality:
- Clean architecture
- Reusable widgets
- Proper state management
- Type-safe operations
- Null-safety enabled

---

## 🔐 Security Rules (Recommended)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read their own data
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
    }
    
    // Students can read active clubs
    match /clubs/{clubId} {
      allow read: if request.auth != null && resource.data.status == 'active';
    }
    
    // Students can create/read their own join requests
    match /clubJoinRequests/{requestId} {
      allow read: if request.auth != null && 
                     resource.data.studentId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.studentId == request.auth.uid;
    }
    
    // Students can create/read their own event registrations
    match /eventRegistrations/{regId} {
      allow read: if request.auth != null && 
                     resource.data.studentId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.studentId == request.auth.uid;
    }
  }
}
```

---

## 🎉 Complete Features Checklist

- ✅ 5-tab bottom navigation
- ✅ Home screen with stats and upcoming events
- ✅ Clubs browsing with search & filter
- ✅ Club join approval system (request → approve/reject)
- ✅ Max 2 clubs validation
- ✅ Event listing from joined clubs
- ✅ Event registration with capacity check
- ✅ QR code generation for event passes
- ✅ My Activity with 4 sections
- ✅ Attendance history tracking
- ✅ Profile with stats
- ✅ Logout functionality
- ✅ Real-time updates
- ✅ Dark theme with orange accent
- ✅ Material 3 design
- ✅ Production-ready code
- ✅ Clean spacing and animations
- ✅ Error handling
- ✅ Loading states

---

## 📝 Usage

### For Students:
1. Sign up / Login
2. Browse clubs and request to join
3. Wait for coordinator approval
4. View events from joined clubs
5. Register for events
6. Get QR code pass for events
7. Track activity and attendance
8. Manage profile

### For Coordinators (Approval):
- Review join requests in coordinator dashboard
- Approve/reject based on club policies
- Requests automatically update in real-time for students

---

## 🔮 Future Enhancements
- Push notifications for request approvals
- In-app messaging with coordinators
- Event reminders
- Social features (comments, reactions)
- Event photo galleries
- Achievement badges
- Leaderboards

---

**Built with ❤️ for ClubX - Production Ready Student Dashboard**
