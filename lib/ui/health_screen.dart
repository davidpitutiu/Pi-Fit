import 'package:flutter/material.dart';

import '../services/health_service.dart';
import '../state/app_store.dart';
import 'theme.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, required this.store, this.service});
  final AppStore store;
  final HealthService? service;
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late HealthService _service;
  HealthAvailability? _availability;
  HealthSnapshot? _snapshot;
  String? _energySource;
  String? _error;
  String? _accountId;
  bool _busy = false;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HealthService();
    _accountId = widget.store.accountId;
    widget.store.addListener(_accountChanged);
    _inspect();
  }

  @override
  void didUpdateWidget(covariant HealthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_accountChanged);
      widget.store.addListener(_accountChanged);
      _accountChanged();
    }
  }

  void _accountChanged() {
    if (_accountId == widget.store.accountId) return;
    _accountId = widget.store.accountId;
    _operation++;
    if (mounted) {
      setState(() {
        _snapshot = null;
        _energySource = null;
        _error = null;
        _busy = false;
        _service = widget.service ?? HealthService();
      });
    }
  }

  Future<void> _inspect() async {
    final availability = await _service.inspect();
    if (mounted) setState(() => _availability = availability);
  }

  Future<void> _read({required bool connect}) async {
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await (connect
          ? _service.connect()
          : _service.refresh());
      if (!mounted || operation != _operation) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.energySources.contains(_energySource)) {
          _energySource = snapshot.energySources.firstOrNull;
        }
      });
    } catch (error) {
      if (!mounted || operation != _operation) return;
      setState(() {
        _snapshot = null;
        _error = error is HealthReadException
            ? error.message
            : 'Datele nu au putut fi citite. Verifică permisiunile în aplicația de sănătate și încearcă din nou.';
      });
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _operation++;
    widget.store.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Sănătate și activitate')),
        body: PageBody(
          children: [
            PiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: PiColors.mint,
                    size: 32,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _service.providerName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Pași, energie activă și înregistrări de antrenament din ultimele 7 zile, într-un singur loc.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Datele Health sunt vizibile doar aici. Nu sunt sincronizate cu contul și nu sunt trimise antrenorului AI. Scorul tău de antrenament rămâne bazat pe jurnalul Pi Fit.',
                    style: TextStyle(color: PiColors.muted(context)),
                  ),
                  const SizedBox(height: 18),
                  if (_availability == null)
                    const LinearProgressIndicator()
                  else if (_availability == HealthAvailability.unsupported)
                    const Text(
                      'Disponibil în aplicația Android prin Health Connect și pe iPhone prin Apple Health. Browserul și aplicațiile desktop nu oferă acces la aceste date.',
                      key: ValueKey('health-unsupported'),
                    )
                  else if (_availability ==
                      HealthAvailability.installRequired) ...[
                    const Text(
                      'Instalează sau actualizează Health Connect, apoi verifică din nou disponibilitatea.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await _service.installProvider();
                                  if (mounted) await _inspect();
                                },
                          child: const Text('Deschide instalarea'),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : _inspect,
                          child: const Text('Verifică din nou'),
                        ),
                      ],
                    ),
                  ] else if (_availability ==
                      HealthAvailability.unavailable) ...[
                    const Text(
                      'Serviciul de sănătate nu este disponibil aici. Health Connect necesită un dispozitiv compatibil; pe iOS verifică accesul la aplicația Sănătate.',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : _inspect,
                      child: const Text('Verifică din nou'),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('health-connect'),
                          onPressed: _busy ? null : () => _read(connect: true),
                          icon: const Icon(Icons.health_and_safety_outlined),
                          label: Text(
                            snapshot == null
                                ? 'Conectează și alege accesul'
                                : 'Revede permisiunile',
                          ),
                        ),
                        if (snapshot != null)
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _read(connect: false),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Actualizează'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Solicităm doar citire pentru cele 3 categorii. Poți modifica sau retrage accesul din setările Apple Health / Health Connect.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (snapshot != null) ...[
              const SectionHeading(title: 'Ultimele 7 zile'),
              Text(
                'Citire la ${formatDate(snapshot.updatedAt)} · ${formatTime(snapshot.updatedAt)}',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
              const SizedBox(height: 12),
              if (snapshot.iosReadAccessUndisclosed)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: PiCard(
                    child: Text(
                      'Apple nu dezvăluie aplicațiilor dacă ai refuzat citirea. O listă goală poate însemna date inexistente sau acces neacordat; afișarea acestei pagini nu confirmă toate permisiunile.',
                    ),
                  ),
                ),
              for (final warning in snapshot.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PiCard(child: Text(warning)),
                ),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pași raportați de platformă',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      snapshot.totalSteps?.toString() ?? '—',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Totalul folosește agregarea platformei. „—” înseamnă că datele nu au putut fi citite.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Energie activă înregistrată',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${snapshot.totalEnergy(_energySource)?.round().toString() ?? '—'} kcal',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.energySources.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey('energy-$_energySource'),
                        initialValue: _energySource,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sursa de energie',
                        ),
                        items: snapshot.energySources
                            .map(
                              (source) => DropdownMenuItem(
                                value: source,
                                child: Text(
                                  source.isEmpty ? 'Sursă fără nume' : source,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (source) =>
                            setState(() => _energySource = source),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'Afișăm o singură sursă pentru a nu aduna automat aplicații care raportează același efort. Valorile sunt înregistrări ale sursei; Pi Fit nu estimează calorii.',
                    ),
                  ],
                ),
              ),
              const SectionHeading(title: 'Pe zile'),
              PiCard(
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Zi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Pași',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'kcal',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final day in snapshot.days.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(formatDate(day.date)),
                            ),
                            Expanded(child: Text(day.steps?.toString() ?? '—')),
                            Expanded(
                              child: Text(
                                snapshot
                                        .energyForDay(day.date, _energySource)
                                        ?.round()
                                        .toString() ??
                                    '—',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Energia este grupată după începutul înregistrării. Înregistrările care trec de miezul nopții nu sunt împărțite prin estimare.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeading(
                title:
                    'Înregistrări de antrenament (${snapshot.workouts.length})',
              ),
              if (snapshot.workouts.isEmpty)
                const PiCard(
                  child: Text(
                    'Nu există antrenamente accesibile în această perioadă. Verifică sursele și permisiunile în aplicația de sănătate.',
                  ),
                ),
              for (final workout in snapshot.workouts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${formatDate(workout.start)} · ${formatTime(workout.start)} – ${formatTime(workout.end)} · ${workout.duration.inMinutes} min',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          workout.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: PiColors.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 5),
              Text(
                'Înregistrările externe nu sunt importate în jurnalul Pi Fit și nu cresc streak-ul sau scorul. Nu se exportă antrenamente către platforma de sănătate în această versiune.',
                style: TextStyle(fontSize: 12, color: PiColors.muted(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
