import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/firebase_gateway.dart';
import 'services/notification_service.dart';
import 'state/app_store.dart';
import 'ui/theme.dart';
import 'ui/home_screen.dart';
import 'ui/training_screens.dart';
import 'ui/planning_screens.dart';
import 'ui/account_coach.dart';
import 'ui/auth_scope_gate.dart';
import 'ui/workout_notification_coordinator.dart';
import 'ui/live_heart_rate_card.dart';

final _navigationKey = GlobalKey<NavigatorState>();
final _workoutRoutes = _WorkoutRoutes();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  String? startupWarning;
  try {
    await FirebaseGateway.instance.initialize();
  } catch (_) {
    startupWarning =
        'Firebase could not connect. Your local workouts are available.';
  }
  try {
    await NotificationService.instance.initialize();
  } catch (_) {
    startupWarning =
        'Notifications are unavailable. You can still use the calendar.';
  }
  runApp(PiFitApp(store: store, startupWarning: startupWarning));
}

class PiFitApp extends StatelessWidget {
  final AppStore store;
  final String? startupWarning;
  const PiFitApp({super.key, required this.store, this.startupWarning});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      title: 'Pi Fit',
      navigatorKey: _navigationKey,
      navigatorObservers: [_workoutRoutes],
      debugShowCheckedModeBanner: false,
      theme: piTheme(Brightness.light),
      darkTheme: piTheme(Brightness.dark),
      themeMode: store.themeMode,
      routes: {'/workout': (_) => ActiveWorkoutScreen(store: store)},
      builder: (context, child) => GlassBackground(
        child: WorkoutNotificationCoordinator(
          store: store,
          onOpenWorkout: () {
            if (store.activeSession != null && !_workoutRoutes.workoutOpen) {
              _navigationKey.currentState?.pushNamed('/workout');
            }
          },
          child: PiWatchScope(
            store: store,
            child: AuthScopeGate(
              store: store,
              navigatorKey: _navigationKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      home: PiShell(store: store, startupWarning: startupWarning),
    ),
  );
}

class _WorkoutRoutes extends NavigatorObserver {
  final _routes = <Route<dynamic>>{};
  bool get workoutOpen =>
      _routes.any((route) => route.settings.name == '/workout');
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _routes.remove(oldRoute);
    if (newRoute != null) _routes.add(newRoute);
  }
}

class PiShell extends StatefulWidget {
  final AppStore store;
  final String? startupWarning;
  const PiShell({super.key, required this.store, this.startupWarning});
  @override
  State<PiShell> createState() => _PiShellState();
}

class _PiShellState extends State<PiShell> {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final warning = widget.startupWarning ?? widget.store.persistenceError;
      if (warning != null) toast(context, warning);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        store: widget.store,
        onNavigate: (i) => setState(() => index = i),
      ),
      ExercisesScreen(store: widget.store),
      ProgressScreen(store: widget.store),
      CalendarScreen(store: widget.store),
      AccountScreen(store: widget.store, embedded: true),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: PiCard(
            radius: 25,
            padding: const EdgeInsets.all(5),
            child: Row(
              children: List.generate(5, (i) {
                const labels = [
                  'Home',
                  'Exercises',
                  'Progress',
                  'Calendar',
                  'Profile',
                ];
                const icons = [
                  Icons.home_outlined,
                  Icons.fitness_center_rounded,
                  Icons.insights_outlined,
                  Icons.calendar_month_outlined,
                  Icons.person_outline_rounded,
                ];
                final selected = index == i;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => index = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: selected
                              ? PiColors.lime.withValues(
                                  alpha: PiColors.dark(context) ? 0.13 : 0.28,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icons[i],
                              size: 22,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : PiColors.muted(context),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : PiColors.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
