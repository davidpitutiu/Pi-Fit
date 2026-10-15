import 'package:flutter/material.dart';

import '../state/app_store.dart';
import 'theme.dart';
import 'training_screens.dart';
import 'planning_screens.dart';
import 'account_coach.dart';

class HomeScreen extends StatelessWidget {
  final AppStore store;
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.store, required this.onNavigate});
  void _workout(BuildContext context) async {
    await store.startEmptyWorkout();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActiveWorkoutScreen(store: store),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final next =
            store.schedule.where((s) => s.date.isAfter(DateTime.now())).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        final today = DateTime.now();
        final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
        return PageBody(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PiColors.lime,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'π',
                      style: TextStyle(
                        color: Color(0xFF101216),
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'pi fit',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Progres',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgressScreen(store: store),
                    ),
                  ),
                  icon: const Icon(Icons.bar_chart_rounded),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountScreen(store: store),
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: PiColors.surface(context),
                    child: Text(
                      store.name.isEmpty
                          ? 'P'
                          : store.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
          'Bine ai revenit, ${store.name.split(' ').first}',
              style: TextStyle(color: PiColors.muted(context), fontSize: 15),
            ),
            const SizedBox(height: 9),
            Text(
              'Mai puternic.\nÎn fiecare zi.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 23),
            _HeroCard(
              onStart: () => _workout(context),
              active: store.activeSession != null,
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    value: '${store.weeklyCount}',
                    label: 'săptămâna aceasta',
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    value: '${store.history.length}',
                    label: 'antrenamente',
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            SectionHeading(
              title: 'Ritmul tău',
              action: 'Vezi progresul',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProgressScreen(store: store),
                ),
              ),
            ),
            PiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: PiColors.lime,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.weeklyCount == 0
                              ? 'Un început bun începe azi.'
                              : '${store.weeklyCount} antrenamente. Continuă în ritmul tău.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = DateTime(
                        today.year,
                        today.month,
                        today.day - today.weekday + 1 + i,
                      );
                      final done = store.history.any(
                        (s) =>
                            s.startedAt.year == day.year &&
                            s.startedAt.month == day.month &&
                            s.startedAt.day == day.day,
                      );
                      final isToday = today.weekday == i + 1;
                      return Column(
                        children: [
                          Text(
                            days[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: PiColors.muted(context),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Container(
                            width: 32,
                            height: 36,
                            decoration: BoxDecoration(
                              color: done
                                  ? PiColors.lime
                                  : (isToday
                                        ? PiColors.lime.withValues(alpha: 0.12)
                                        : Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor),
                              border: Border.all(
                                color: isToday
                                    ? PiColors.lime
                                    : Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(
                                      Icons.check,
                                      color: Color(0xFF172000),
                                      size: 20,
                                    )
                                  : Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isToday
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : null,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            SectionHeading(
              title: 'Următorul antrenament',
              action: 'Calendar',
              onAction: () => onNavigate(3),
            ),
            if (next.isEmpty)
              PiCard(
                onTap: () => onNavigate(3),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fă loc pentru tine.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Programează o sesiune sau o lună întreagă.',
                            style: TextStyle(color: PiColors.muted(context)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_rounded),
                  ],
                ),
              )
            else
              PiCard(
                onTap: () => onNavigate(3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PiColors.lime.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${next.first.date.day}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.routineById(next.first.routineId)?.name ??
                                'Antrenament',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            '${formatDate(next.first.date)} · ${formatTime(next.first.date)}',
                            style: TextStyle(color: PiColors.muted(context)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            SectionHeading(
              title: 'Construiește-ți rutina',
              action: 'Toate',
              onAction: () => onNavigate(1),
            ),
            ...store.routines
                .take(3)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PiCard(
                      onTap: () => onNavigate(1),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              r.category.toLowerCase().contains('for')
                                  ? Icons.fitness_center
                                  : Icons.bolt_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${r.exercises.length} exerciții · ${r.estimatedMinutes} min',
                                  style: TextStyle(
                                    color: PiColors.muted(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            PiCard(
              onTap: () => onNavigate(4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Un plan mai bun, împreună.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Întreabă Pi Coach despre progres și recuperare.',
                          style: TextStyle(color: PiColors.muted(context)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.north_east_rounded),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onStart;
  final bool active;
  const _HeroCard({required this.onStart, required this.active});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: PiColors.lime,
      borderRadius: BorderRadius.circular(27),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -28,
          top: -35,
          child: Transform.rotate(
            angle: -0.35,
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 190,
              color: Color(0x22253500),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AZI E DESPRE TINE',
                style: TextStyle(
                  color: Color(0xFF3D510E),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                active
                    ? 'Continuă de unde\nai rămas.'
                    : 'Tu aduci energia.\nNoi ținem evidența.',
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.15,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172000),
                ),
              ),
              const SizedBox(height: 21),
              FilledButton.icon(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF172000),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 21),
                label: Text(
                  active ? 'Reia antrenamentul' : 'Începe antrenamentul',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _Metric({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => PiCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
            ),
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: PiColors.muted(context)),
        ),
      ],
    ),
  );
}
