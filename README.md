# Club-X 🎓

**Empowering Campus Life**

Club-X is a comprehensive Flutter-based mobile application designed to streamline club and event management in educational institutions. It provides a unified platform for students, coordinators, and administrators to manage clubs, organize events, track attendance, and foster campus engagement.

---

## 📱 Features

### For Students
- **Club Discovery & Membership**
  - Browse all available clubs with detailed information
  - Apply to join clubs with approval workflow
  - View membership status and club activities
  - Track personal club memberships

- **Event Management**
  - Discover upcoming campus events
  - Filter events by category (Academic, Sports, Cultural, Technical, Social)
  - RSVP to events with real-time availability tracking
  - View event details, location, and schedules
  - Track attendance history

- **Session Attendance**
  - Mark attendance for club sessions via QR code scanning
  - View all past and present sessions (Active/Closed)
  - See attendance status (Present/Absent) for each session
  - Real-time session expiry tracking (15-minute window)

- **Activity Tracking**
  - Personal dashboard showing all activities
  - View registered events and attendance records
  - Track club join requests status (Pending/Approved/Rejected)
  - Unified attendance history with session and event records

- **Profile Management**
  - Update personal information and profile photo
  - Unique Student ID (auto-generated: CLX-STU-XXXX)
  - Email verification status
  - Profile photo upload with Cloudinary integration

### For Coordinators
- **Club Management**
  - Manage assigned club information
  - Update club details, description, and profile image
  - View member roster with student details
  - Manage member requests (Approve/Reject)

- **Event Creation & Management**
  - Create and publish club events
  - Set event details (date, time, location, capacity)
  - Upload event images
  - Track event registrations and attendance
  - Dynamic event status (Upcoming/Ongoing/Completed/Cancelled)

- **Attendance Management**
  - **Sessions Mode**: Start attendance sessions with QR code generation
  - **Events Mode**: Manage event-specific attendance
  - **History Mode**: View all past sessions with attendance counts
  - One session per club per day with auto-close functionality
  - 15-minute expiry timer for attendance windows
  - Real-time attendance counting with live updates

- **QR Code System**
  - Generate unique QR codes for attendance sessions
  - Secure session validation with club verification
  - Prevent duplicate attendance marking
  - Session expiry tracking

### For Administrators
- **User Management**
  - View all users (Students, Coordinators, Admins)
  - Monitor user activities and registrations
  - Manage user roles and permissions

- **Club Administration**
  - Create and manage all clubs
  - Assign coordinators to clubs
  - Monitor club activities and membership
  - Approve or reject club join requests

- **Event Oversight**
  - View all campus events across clubs
  - Monitor event attendance and engagement
  - Event analytics and reporting

- **System Management**
  - Student ID generation and tracking
  - Firestore data integrity monitoring
  - Role-based access control

---

## 🛠️ Tech Stack

### Frontend
- **Flutter SDK**: 3.10.7
- **Dart**: 3.10.7
- **State Management**: Provider + StreamBuilder
- **Navigation**: go_router 14.6.2

### Backend & Services
- **Firebase Authentication**: Email/Password authentication
- **Cloud Firestore**: NoSQL database for real-time data
- **Firebase Storage**: Profile and event image storage
- **Cloudinary**: Image upload and optimization

### Key Packages
```yaml
dependencies:
  firebase_core: ^3.9.0
  firebase_auth: ^5.3.4
  cloud_firestore: ^5.5.2
  firebase_storage: ^12.3.8
  image_picker: ^1.1.2
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.2.3
  intl: ^0.19.0
  go_router: ^14.6.2
```

---

## 📂 Project Structure

```
clubx/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── router/
│   │   └── app_router.dart           # Navigation configuration
│   ├── screens/
│   │   ├── splash_screen.dart        # Initial splash screen
│   │   ├── role_selection_screen.dart # Role selection UI
│   │   ├── auth/
│   │   │   ├── login_screen.dart     # Login with role badge
│   │   │   └── signup_screen.dart    # Registration
│   │   ├── admin/
│   │   │   ├── admin_dashboard.dart  # Admin home
│   │   │   ├── clubs_section.dart    # Club management
│   │   │   └── users_section.dart    # User management
│   │   ├── coordinator/
│   │   │   ├── coordinator_dashboard.dart
│   │   │   ├── club_management_screen.dart
│   │   │   ├── create_event_screen.dart
│   │   │   └── attendance_qr_screen.dart # QR & attendance
│   │   └── student/
│   │       ├── student_dashboard.dart
│   │       ├── student_activity_screen.dart
│   │       ├── student_session_scanner_screen.dart
│   │       └── clubs_list_screen.dart
│   ├── widgets/
│   │   ├── primary_button.dart       # Reusable button widget
│   │   └── event_card.dart           # Event card component
│   └── utils/
│       └── firestore_migration.dart  # Data migration utilities
├── android/                           # Android configuration
├── ios/                              # iOS configuration
├── images/                           # App assets
│   └── logo.png
├── pubspec.yaml                      # Dependencies
└── README.md                         # This file
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.10.7 or higher
- Dart 3.10.7 or higher
- Android Studio / VS Code with Flutter extensions
- Firebase project with Firestore and Authentication enabled
- Cloudinary account (for image uploads)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/clubx.git
   cd clubx
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Email/Password authentication
   - Enable Cloud Firestore
   - Enable Firebase Storage
   - Download `google-services.json` (Android) and place in `android/app/`
   - Download `GoogleService-Info.plist` (iOS) and place in `ios/Runner/`

4. **Cloudinary Setup** (Optional for image uploads)
   - Create account at [Cloudinary](https://cloudinary.com/)
   - Update credentials in image upload configurations

5. **Firebase Configuration**
   - Update `lib/firebase_options.dart` with your Firebase project details
   - Configure Firestore security rules from `firestore.rules`
   - Configure Storage security rules from `storage.rules`

6. **Run the app**
   ```bash
   flutter run
   ```

---

## 🔐 User Roles & Default Credentials

### Admin
- **Email**: `admin@gmail.com`
- **Password**: Set during first login
- **Capabilities**: Full system access, user management, club oversight

### Coordinator
- Assigned by admin to specific clubs
- Created through admin panel with club assignment
- **Capabilities**: Club and event management, attendance tracking

### Student
- Self-registration through signup flow
- Auto-generated Student ID (CLX-STU-XXXX)
- **Capabilities**: Join clubs, attend events, mark attendance

---

## 📊 Database Schema

### Collections

#### `users`
```
{
  uid: string,
  name: string,
  email: string,
  role: "admin" | "coordinator" | "student",
  studentId?: string,        // For students only
  clubId?: string,           // For coordinators only
  profileImageUrl?: string,
  createdAt: Timestamp
}
```

#### `clubs`
```
{
  id: string,
  name: string,
  description: string,
  category: string,
  coordinatorId: string,
  coordinatorName: string,
  imageUrl?: string,
  memberCount: number,
  createdAt: Timestamp
}
```

#### `events`
```
{
  id: string,
  title: string,
  description: string,
  clubId: string,
  clubName: string,
  date: Timestamp,
  location: string,
  capacity: number,
  category: string,
  registrationCount: number,
  imageUrl?: string,
  status: "upcoming" | "ongoing" | "completed" | "cancelled",
  createdAt: Timestamp
}
```

#### `clubSessions`
```
{
  id: string,
  clubId: string,
  date: Timestamp,
  status: "active" | "closed",
  attendanceCount: number,
  expiresAt: Timestamp,     // Auto-close after 15 minutes
  createdAt: Timestamp
}
```

#### `clubAttendance/{sessionId}/students/{userId}`
```
{
  studentId: string,
  studentName: string,
  checkInTime: Timestamp
}
```

#### `attendance/{eventId}/students/{studentId}`
```
{
  studentId: string,
  studentName: string,
  eventId: string,
  checkInTime: Timestamp
}
```

#### `clubJoinRequests`
```
{
  id: string,
  studentId: string,
  studentName: string,
  clubId: string,
  clubName: string,
  status: "pending" | "approved" | "rejected",
  requestedAt: Timestamp
}
```

---

## 🎯 Key Features Implementation

### QR Code Attendance System
- **Session Creation**: Coordinators start sessions with automatic QR generation
- **QR Scanning**: Students scan QR codes to mark attendance
- **Validation**:
  - Verifies club membership
  - Checks session status (active/expired)
  - Prevents duplicate attendance
  - Validates 15-minute expiry window
- **Auto-Close**: Sessions automatically close after 15 minutes

### Real-time Updates
- **StreamBuilder Integration**: Live data synchronization
- **includeMetadataChanges**: Instant UI updates without refresh
- **Optimistic UI**: Immediate feedback on user actions

### Event Status Management
- **Dynamic Calculation**: Status computed based on date/time
- **Categories**: Upcoming → Ongoing → Completed
- **Visual Indicators**: Color-coded badges and status icons

### Student ID Generation
- **Auto-increment System**: Uses Firestore transactions
- **Format**: CLX-STU-XXXX (e.g., CLX-STU-0001)
- **Unique IDs**: Counter-based generation ensures uniqueness

### Image Management
- **Profile Photos**: Cloudinary integration with optimization
- **Event Images**: Firebase Storage for event banners
- **Compression**: Automatic image compression before upload

---

## 🔧 Configuration Files

### Firestore Rules (`firestore.rules`)
- Role-based access control
- Data validation rules
- Security policies

### Storage Rules (`storage.rules`)
- File upload permissions
- Size and type restrictions

### Firebase Indexes (`firestore.indexes.json`)
- Composite indexes for complex queries
- Optimized query performance

---

## 🐛 Known Issues & Solutions

### Issue: "Missing index" error in queries
**Solution**: Deploy composite indexes from `firestore.indexes.json`
```bash
firebase deploy --only firestore:indexes
```

### Issue: Attendance not showing
**Solution**: The app uses `collectionGroup` queries. Ensure proper data structure in Firestore.

### Issue: Session expired immediately
**Solution**: Check server time synchronization. Sessions expire 15 minutes after creation.

---

## 🤝 Contributing

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style
- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused

---

## 📝 Changelog

### Version 1.0.0 (Current)
- ✅ Role-based authentication (Admin, Coordinator, Student)
- ✅ Club management and membership system
- ✅ Event creation and registration
- ✅ QR code attendance tracking for sessions
- ✅ Real-time attendance updates
- ✅ Student activity dashboard
- ✅ Profile management with image upload
- ✅ Auto-generated Student IDs
- ✅ Session history with Present/Absent status
- ✅ Role selection welcome screen
- ✅ 15-minute session expiry with auto-close
- ✅ One session per club per day rule
- ✅ Event status calculation (Upcoming/Ongoing/Completed)

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👥 Authors

**Club-X Development Team**

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Cloudinary for image management
- All contributors and testers

---

## 📞 Support

For issues, questions, or suggestions:
- Create an issue on GitHub
- Email: support@clubx.app
- Documentation: [Wiki](https://github.com/yourusername/clubx/wiki)

---

## 🚦 Status

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Flutter Version](https://img.shields.io/badge/flutter-3.10.7-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**Active Development** | Last Updated: February 2026

---

Made with ❤️ for educational institutions
