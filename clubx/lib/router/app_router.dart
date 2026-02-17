import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/home_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/coordinator/coordinator_dashboard.dart';
import '../screens/student/student_dashboard.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/role-selection',
      name: 'role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/landing',
      name: 'landing',
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'student';
        return SignupScreen(selectedRole: role);
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'student';
        return LoginScreen(selectedRole: role);
      },
    ),
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/coordinator',
      name: 'coordinator',
      builder: (context, state) => const CoordinatorDashboard(),
    ),
    GoRoute(
      path: '/student',
      name: 'student',
      builder: (context, state) => const StudentDashboard(),
    ),
  ],
  errorBuilder: (context, state) => const ErrorScreen(),
);

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: const Center(
        child: Text('Page not found'),
      ),
    );
  }
}
