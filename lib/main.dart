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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(await SharedPreferences.getInstance());
  await store.load();
  String? startupWarning;
  try {
    await FirebaseGateway.instance.initialize();
  } catch (_) {
    startupWarning =
        'Firebase nu a putut fi inițializat. Modul local este disponibil.';
  }
  try {
    await NotificationService.instance.initialize();
  } catch (_) {
    startupWarning =
        'Notificările nu sunt disponibile. Calendarul poate fi folosit în continuare.';
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
      debugShowCheckedModeBanner: false,
      theme: piTheme(Brightness.light),
      darkTheme: piTheme(Brightness.dark),
      themeMode: store.themeMode,
      home: PiShell(store: store, startupWarning: startupWarning),
    ),
  );
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
      RoutinesScreen(store: widget.store),
      ExercisesScreen(store: widget.store),
      CalendarScreen(store: widget.store),
      CoachScreen(store: widget.store),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Acasă',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Antrenamente',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Exerciții',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Pi Coach',
          ),
        ],
      ),
    );
  }
}
