import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/models/trip.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/history/history_screen.dart';
import 'features/itinerary/itinerary_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/planner/planner_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shared_trip/shared_trip_screen.dart';
import 'features/subscription/paywall_screen.dart';

class GowaiApp extends StatelessWidget {
  GowaiApp({super.key});

  final _router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isAuth = user != null;
      final path = state.uri.path;

      // Public routes — no auth required
      if (path.startsWith('/share/') ||
          path == '/onboarding' ||
          path == '/login' ||
          path == '/signup') {
        return null;
      }

      if (!isAuth) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final user = Supabase.instance.client.auth.currentUser;
          return user != null ? '/planner' : '/onboarding';
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/planner',
        builder: (_, __) => const PlannerScreen(),
      ),
      GoRoute(
        path: '/itinerary',
        builder: (_, state) {
          final trip = state.extra as Trip;
          return ItineraryScreen(trip: trip);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (_, __) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (_, __) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/share/:token',
        builder: (_, state) {
          final token = state.pathParameters['token']!;
          return SharedTripScreen(token: token);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gowai',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
