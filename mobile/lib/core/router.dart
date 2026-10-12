import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../features/auth/auth_screens.dart';
import '../features/auth/setup_screen.dart';
import '../features/child/child_home_screen.dart';
import '../features/child/pair_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/parent/alerts_screen.dart';
import '../features/parent/child_detail_screen.dart';
import '../features/parent/family_screen.dart';
import '../features/parent/live_track_screen.dart';
import '../features/parent/map_screen.dart';
import '../features/parent/place_editor_screen.dart';
import '../features/parent/places_screen.dart';
import '../features/parent/plans_screen.dart';
import '../features/parent/schedules_screen.dart';
import '../features/parent/settings_screen.dart';
import '../features/parent/shell.dart';
import '../features/parent/sos_screen.dart';

/// Pure redirect logic, unit-tested in test/router_test.dart.
String? redirectFor({required bool loading, required Session? session, required String location}) {
  if (loading) return location == '/' ? null : '/';
  final publicPaths = location == '/welcome' || location.startsWith('/auth') || location == '/child/pair';

  if (session == null) return publicPaths ? null : '/welcome';
  if (session.isChild) return location.startsWith('/child') && location != '/child/pair' ? null : '/child';
  if (session.isParent) {
    if (location == '/' || publicPaths || location == '/setup') return '/p/map';
    return location.startsWith('/p') ? null : '/p/map';
  }
  // Signed in but not set up yet.
  if (!session.emailVerified) return location == '/auth/verify' ? null : '/auth/verify';
  return location == '/setup' ? null : '/setup';
}

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      return redirectFor(loading: s.isLoading && !s.hasValue, session: s.value, location: state.matchedLocation);
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/auth/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/auth/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/auth/verify', builder: (_, _) => const VerifyEmailScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/child/pair', builder: (_, _) => const PairScreen()),
      GoRoute(path: '/child', builder: (_, _) => const ChildHomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ParentShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/p/map', builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/alerts', builder: (_, _) => const AlertsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/places', builder: (_, _) => const PlacesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/family', builder: (_, _) => const FamilyScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/p/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(path: '/p/sos/:id', builder: (_, s) => SosScreen(alertId: s.pathParameters['id']!)),
      GoRoute(path: '/p/child/:id', builder: (_, s) => ChildDetailScreen(childId: s.pathParameters['id']!)),
      GoRoute(path: '/p/live/:id', builder: (_, s) => LiveTrackScreen(childId: s.pathParameters['id']!)),
      GoRoute(path: '/p/place', builder: (_, s) => PlaceEditorScreen(place: s.extra as Place?)),
      GoRoute(path: '/p/schedules', builder: (_, _) => const SchedulesScreen()),
      GoRoute(path: '/p/plans', builder: (_, _) => const PlansScreen()),
    ],
  );
});

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_moon_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ]),
        ),
      );
}
