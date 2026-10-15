import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/app_store.dart';
import '../services/firebase_gateway.dart';
import '../services/coach_service.dart';
import 'theme.dart';

class AccountScreen extends StatefulWidget {
  final AppStore store;
  const AccountScreen({super.key, required this.store});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final gateway = FirebaseGateway.instance;
  final email = TextEditingController(),
      password = TextEditingController(),
      displayName = TextEditingController();
  bool register = false, busy = false, obscure = true;
  @override
  void initState() {
    super.initState();
    displayName.text = widget.store.name;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, String success) async {
    setState(() => busy = true);
    try {
      await action();
      if (mounted) toast(context, success);
    } on FirebaseAuthException catch (e) {
      if (mounted) toast(context, _authError(e));
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _authError(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'Adresa de email nu este validă.',
    'weak-password' => 'Folosește o parolă de cel puțin 8 caractere.',
    'email-already-in-use' => 'Există deja un cont cu această adresă.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Emailul sau parola nu sunt corecte.',
    'too-many-requests' => 'Prea multe încercări. Revino în câteva minute.',
    'network-request-failed' => 'Conexiunea nu este disponibilă.',
    'operation-not-allowed' =>
      'Activează Email/Password în Firebase Authentication pentru acest proiect.',
    'app-not-authorized' || 'invalid-api-key' =>
      'Verifică înregistrarea aplicației și configurația Firebase.',
    _ => 'Autentificarea nu a reușit (${e.code}).',
  };
  Future<void> restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurezi backupul?'),
        content: const Text(
          'Datele de pe acest dispozitiv vor fi înlocuite cu backupul din cont. Exportă mai întâi datele locale dacă vrei să le păstrezi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Restaurează'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await run(() async {
      final data = await gateway.loadBackup();
      if (data == null) {
        throw StateError('Nu există încă un backup în acest cont.');
      }
      await widget.store.restoreBackup(data);
    }, 'Backup restaurat pe acest dispozitiv.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contul tău')),
    body: StreamBuilder<User?>(
      stream: gateway.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data ?? gateway.currentUser;
        return AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) => PageBody(
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: PiColors.lime,
                      child: Text(
                        widget.store.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF172000),
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.store.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      user?.email ?? 'Profil local · pe acest dispozitiv',
                      style: TextStyle(color: PiColors.muted(context)),
                    ),
                  ],
                ),
              ),
              const SectionHeading(title: 'Obiectivul tău'),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: displayName,
                      decoration: const InputDecoration(labelText: 'Nume'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: widget.store.goal,
                      decoration: const InputDecoration(labelText: 'Obiectiv'),
                      items:
                          const [
                                'Forță și masă musculară',
                                'Condiție fizică',
                                'Controlul greutății',
                                'Mobilitate și recuperare',
                              ]
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(
                                    g,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          widget.store.updateProfile(displayName.text, v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => run(
                        () => widget.store.updateProfile(
                          displayName.text,
                          widget.store.goal,
                        ),
                        'Profil salvat.',
                      ),
                      child: const Text('Salvează profilul'),
                    ),
                  ],
                ),
              ),
              const SectionHeading(title: 'Aspect'),
              PiCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tema aplicației',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    DropdownButton<ThemeMode>(
                      value: widget.store.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('Sistem'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) widget.store.setTheme(v);
                      },
                    ),
                  ],
                ),
              ),
              const SectionHeading(title: 'Cont și cloud'),
              if (!gateway.configured)
                const PiCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_off_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mod local activ. Conectarea și backupul vor fi disponibile după configurarea proiectului Firebase. Antrenamentele sunt salvate pe acest dispozitiv.',
                        ),
                      ),
                    ],
                  ),
                )
              else if (user == null)
                PiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        register ? 'Creează contul Pi Fit' : 'Bine ai revenit.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 17),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Parolă',
                          suffixIcon: IconButton(
                            tooltip: obscure
                                ? 'Arată parola'
                                : 'Ascunde parola',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => run(
                                () async {
                                  if (!email.text.contains('@')) {
                                    throw ArgumentError(
                                      'Introdu o adresă de email validă.',
                                    );
                                  }
                                  if (register && password.text.length < 8) {
                                    throw ArgumentError(
                                      'Parola trebuie să aibă cel puțin 8 caractere.',
                                    );
                                  }
                                  if (register) {
                                    await gateway.signUp(
                                      email.text,
                                      password.text,
                                      displayName.text,
                                    );
                                  } else {
                                    await gateway.signIn(
                                      email.text,
                                      password.text,
                                    );
                                  }
                                },
                                register
                                    ? 'Cont creat. Verifică emailul pentru confirmare.'
                                    : 'Te-ai conectat.',
                              ),
                        child: Text(
                          busy
                              ? 'Se procesează…'
                              : register
                              ? 'Creează cont'
                              : 'Conectează-te',
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => register = !register),
                        child: Text(
                          register
                              ? 'Ai deja cont? Conectează-te'
                              : 'Ești nou? Creează un cont',
                        ),
                      ),
                      if (!register)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () async {
                                    if (!email.text.contains('@')) {
                                      throw ArgumentError(
                                        'Introdu mai întâi adresa de email.',
                                      );
                                    }
                                    await gateway.resetPassword(email.text);
                                  },
                                  'Dacă adresa are un cont, vei primi instrucțiuni pentru resetare.',
                                ),
                          child: const Text('Am uitat parola'),
                        ),
                    ],
                  ),
                )
              else
                PiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined),
                          SizedBox(width: 10),
                          Text(
                            'Conectat la Firebase',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Backupul este manual. Încărcarea înlocuiește backupul acestui cont; restaurarea înlocuiește datele locale.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => run(
                                () => gateway.saveBackup(
                                  widget.store.exportData(),
                                ),
                                'Backup trimis în contul tău.',
                              ),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          busy ? 'Se procesează…' : 'Salvează backup în cloud',
                        ),
                      ),
                      const SizedBox(height: 9),
                      OutlinedButton.icon(
                        onPressed: busy ? null : restore,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Restaurează din cloud'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(
                                gateway.signOut,
                                'Te-ai deconectat. Datele locale rămân pe dispozitiv.',
                              ),
                        child: const Text('Deconectează-te'),
                      ),
                    ],
                  ),
                ),
              const SectionHeading(title: 'Datele tale'),
              PiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tu controlezi datele. Poți exporta jurnalul, rutinele și calendarul într-un fișier JSON prin copiere.',
                    ),
                    const SizedBox(height: 13),
                    OutlinedButton.icon(
                      onPressed: () => run(
                        () => Clipboard.setData(
                          ClipboardData(
                            text: const JsonEncoder.withIndent(
                              '  ',
                            ).convert(widget.store.exportData()),
                          ),
                        ),
                        'Export JSON copiat. Salvează-l într-un loc sigur.',
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Copiază exportul JSON'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pi Fit · 0.1.0\nDatele locale sunt comune profilului acestui dispozitiv. Deconectarea din Firebase nu le șterge.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class CoachScreen extends StatefulWidget {
  final AppStore store;
  const CoachScreen({super.key, required this.store});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  final service = CoachService();
  final List<({String text, bool user})> messages = [];
  bool busy = false;
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send([String? suggestion]) async {
    final question = (suggestion ?? input.text).trim();
    if (question.isEmpty || busy) return;
    setState(() {
      messages.add((text: question, user: true));
      busy = true;
      input.clear();
    });
    _bottom();
    try {
      final reply = await service.reply(
        question,
        context: widget.store.coachContext,
      );
      if (mounted) setState(() => messages.add((text: reply, user: false)));
    } catch (e) {
      if (mounted) {
        setState(
          () => messages.add((
            text: e.toString().replaceFirst('Bad state: ', ''),
            user: false,
          )),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        _bottom();
      }
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PiColors.lime,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF172000),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pi Coach',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            service.remoteConfigured
                                ? 'AI online · necesită cont'
                                : 'Recomandări locale · AI neconectat',
                            style: TextStyle(
                              color: PiColors.muted(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(22),
                  children: [
                    if (messages.isEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Mai multă claritate.\nMai mult progres.',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Discută despre tehnică, planificare și recuperare. Recomandările țin cont de obiectivul și activitatea ta când AI-ul este conectat.',
                        style: TextStyle(color: PiColors.muted(context)),
                      ),
                      const SizedBox(height: 25),
                      ...[
                        'Cum încep cu 3 antrenamente pe săptămână?',
                        'Cum cresc greutățile în siguranță?',
                        'Câtă pauză îmi trebuie pentru recuperare?',
                      ].map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PiCard(
                            onTap: () => send(q),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    q,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.north_east_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        service.remoteConfigured
                            ? 'Mesajele și un rezumat al antrenamentelor sunt trimise către serviciul AI când apeși Trimite. Răspunsurile pot conține erori.'
                            : 'În modul local, mesajele nu sunt trimise unui serviciu AI. Recomandările sunt predefinite și nu înlocuiesc evaluarea unui antrenor sau medic.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                    ...messages.map(
                      (m) => Align(
                        alignment: m.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 650),
                          margin: EdgeInsets.only(
                            bottom: 16,
                            left: m.user ? 35 : 0,
                            right: m.user ? 0 : 20,
                          ),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: m.user
                                ? PiColors.lime
                                : PiColors.surface(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SelectableText(
                            m.text,
                            style: TextStyle(
                              height: 1.55,
                              color: m.user ? const Color(0xFF172000) : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Pi Coach pregătește răspunsul…'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          hintText: 'Întreabă-l pe Pi Coach…',
                          counterText: '',
                        ),
                        onSubmitted: (_) => send(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: busy ? null : send,
                      style: IconButton.styleFrom(
                        backgroundColor: PiColors.lime,
                        foregroundColor: const Color(0xFF172000),
                        padding: const EdgeInsets.all(16),
                      ),
                      tooltip: 'Trimite',
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
