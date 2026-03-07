import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'domain/providers/auth_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/registration_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/dashboard/home_screen.dart';
import 'presentation/screens/dashboard/meals_screen.dart';
import 'presentation/screens/dashboard/manage_family_screen.dart';
import 'presentation/screens/dashboard/manage_preferences_screen.dart';
import 'presentation/screens/dashboard/meal_statistics_screen.dart';
import 'presentation/screens/dashboard/meal_details_screen.dart';
import 'presentation/screens/dashboard/profile_screen.dart';
import 'presentation/screens/dashboard/edit_profile_screen.dart';
import 'data/models/meal.dart';


void main() {
  runApp(const ProviderScope(child: KikhaboApp()));
}

class KikhaboApp extends ConsumerStatefulWidget {
  const KikhaboApp({super.key});

  @override
  ConsumerState<KikhaboApp> createState() => _KikhaboAppState();
}

class _KikhaboAppState extends ConsumerState<KikhaboApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    ref.read(authProvider.notifier).checkAuthStatus();
    _router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const SizedBox(),
          redirect: (context, state) {
            if (state.uri.toString() == '/dashboard') return '/dashboard/home';
            return null;
          },
          routes: [
            GoRoute(
              path: 'home',
              builder: (context, state) => const DashboardScreen(child: HomeScreen()),
            ),
            GoRoute(
              path: 'meals',
              builder: (context, state) => const DashboardScreen(child: MealsScreen()),
            ),
            GoRoute(
              path: 'family',
              builder: (context, state) => const DashboardScreen(child: ManageFamilyScreen()),
            ),
            GoRoute(
              path: 'manage_family',
              builder: (context, state) => const DashboardScreen(child: ManageFamilyScreen()),
            ),
            GoRoute(
              path: 'preferences',
              builder: (context, state) => const DashboardScreen(child: ManagePreferencesScreen()),
            ),
            GoRoute(
              path: 'statistics',
              builder: (context, state) => const DashboardScreen(child: MealStatisticsScreen()),
            ),
            GoRoute(
              path: 'meal_details',
              builder: (context, state) {
                final meal = state.extra as Meal;
                return DashboardScreen(child: MealDetailsScreen(meal: meal));
              },
            ),
            GoRoute(
              path: 'profile',
              builder: (context, state) => const DashboardScreen(child: ProfileScreen()),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.liquidGlassTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
