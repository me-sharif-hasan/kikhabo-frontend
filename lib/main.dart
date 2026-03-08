import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/services/analytics_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
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
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/dashboard/fridge_scan_screen.dart';
import 'data/models/meal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KikhaboApp()));
}

class KikhaboApp extends StatefulWidget {
  const KikhaboApp({super.key});

  @override
  State<KikhaboApp> createState() => _KikhaboAppState();
}

class _KikhaboAppState extends State<KikhaboApp> {
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    // Initialize Firebase in the background. runApp() above has already
    // rendered the first frame (dark scaffold below), satisfying Android's
    // pre-draw listener immediately.
    Firebase.initializeApp().then((_) {
      if (mounted) setState(() => _firebaseReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      // Dark placeholder drawn on the very first frame — stops the
      // cancelAndRedraw loop without blocking on Firebase.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF111827)),
      );
    }
    return const _KikhaboRouter();
  }
}

/// Bridges Riverpod auth state into a ChangeNotifier so GoRouter can
/// call its redirect callback whenever authentication status changes.
class _AuthNotifierBridge extends ChangeNotifier {
  _AuthNotifierBridge();
  void notify() => notifyListeners();
}

class _KikhaboRouter extends ConsumerStatefulWidget {
  const _KikhaboRouter();

  @override
  ConsumerState<_KikhaboRouter> createState() => _KikhaboRouterState();
}

class _KikhaboRouterState extends ConsumerState<_KikhaboRouter> {
  late final GoRouter _router;
  late final _AuthNotifierBridge _authBridge;

  @override
  void initState() {
    super.initState();
    _authBridge = _AuthNotifierBridge();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: _authBridge,
      observers: [AnalyticsService.instance.observer],
      redirect: (context, state) {
        final isAuthenticated = ref.read(authProvider).isAuthenticated;
        final isOnLoginOrRegister = state.matchedLocation == '/' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/splash' ||
            state.matchedLocation == '/onboarding';

        // If logged out and on a protected page, send to login.
        if (!isAuthenticated && !isOnLoginOrRegister) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
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
          redirect: (context, state) => '/dashboard/home',
        ),
        GoRoute(
          path: '/dashboard/home',
          builder: (context, state) => const DashboardScreen(child: HomeScreen()),
        ),
        GoRoute(
          path: '/dashboard/meals',
          builder: (context, state) => const DashboardScreen(child: MealsScreen()),
        ),
        GoRoute(
          path: '/dashboard/family',
          builder: (context, state) => const DashboardScreen(child: ManageFamilyScreen()),
        ),
        GoRoute(
          path: '/dashboard/manage_family',
          builder: (context, state) => const DashboardScreen(child: ManageFamilyScreen()),
        ),
        GoRoute(
          path: '/dashboard/preferences',
          builder: (context, state) => const DashboardScreen(child: ManagePreferencesScreen()),
        ),
        GoRoute(
          path: '/dashboard/statistics',
          builder: (context, state) => const DashboardScreen(child: MealStatisticsScreen()),
        ),
        GoRoute(
          path: '/dashboard/meal_details',
          builder: (context, state) {
            final meal = state.extra as Meal;
            return DashboardScreen(child: MealDetailsScreen(meal: meal));
          },
        ),
        GoRoute(
          path: '/dashboard/profile',
          builder: (context, state) => const DashboardScreen(child: ProfileScreen()),
        ),
        GoRoute(
          path: '/dashboard/profile/edit',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/dashboard/fridge_scan',
          builder: (context, state) => const FridgeScanScreen(),
        ),
      ],
    );

    // Notify GoRouter whenever auth state changes so the redirect runs again.
    ref.listenManual<AuthState>(authProvider, (_, __) => _authBridge.notify());
  }

  @override
  void dispose() {
    _authBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeProvider);
    AppColors.current = AppColors.paletteFor(themeType);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.forType(themeType),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
