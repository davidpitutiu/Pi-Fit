import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/user_profile.dart';
import '../services/coach_service.dart';
import '../services/firebase_gateway.dart';
import '../state/app_store.dart';
import 'health_screen.dart';
import 'theme.dart';

class AccountScreen extends StatefulWidget {
  final AppStore store;
  final bool embedded;
  final FirebaseGateway? gateway;
  const AccountScreen({
    super.key,
    required this.store,
    this.embedded = false,
    this.gateway,
  });
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  FirebaseGateway get gateway => widget.gateway ?? FirebaseGateway.instance;
  bool busy = false;

  Future<void> run(Future<void> Function() action, String success) async {
    final accountId = widget.store.accountId;
    final authUid = gateway.currentUser?.uid;
    bool sameScope() =>
        mounted &&
        widget.store.accountId == accountId &&
        gateway.currentUser?.uid == authUid;
    setState(() => busy = true);
    try {
      await action();
      if (mounted && sameScope()) toast(context, success);
    } catch (e) {
      if (mounted && sameScope()) toast(context, _readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final authUid = gateway.currentUser?.uid;
    final accountId = widget.store.accountId;
    if (authUid == null || accountId != authUid) {
      toast(
        context,
        'Contul nu este încă pregătit. Conectează-te din nou înainte de restaurare.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurezi backupul?'),
        content: const Text(
          'Datele locale vor fi înlocuite cu backupul acestui cont. Exportă-le mai întâi dacă vrei să le păstrezi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Restaurează'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (gateway.currentUser?.uid != authUid ||
        widget.store.accountId != accountId) {
      return;
    }
    await run(() async {
      if (gateway.currentUser?.uid != authUid ||
          widget.store.accountId != accountId) {
        throw StateError('Contul s-a schimbat. Reîncearcă restaurarea.');
      }
      final data = await gateway.loadBackup();
      if (gateway.currentUser?.uid != authUid ||
          widget.store.accountId != accountId) {
        throw StateError('Contul s-a schimbat. Reîncearcă restaurarea.');
      }
      if (data == null) {
        throw StateError('Nu există încă un backup în acest cont.');
      }
      await widget.store.restoreBackup(data, expectedAccountId: authUid);
    }, 'Backup restaurat pe acest dispozitiv.');
  }

  Future<void> saveBackup() => run(() async {
    final authUid = gateway.currentUser?.uid;
    if (authUid == null || widget.store.accountId != authUid) {
      throw StateError(
        'Contul nu este încă pregătit. Conectează-te din nou înainte de backup.',
      );
    }
    final data = widget.store.exportData();
    await gateway.saveBackup(data);
  }, 'Backup salvat în cont.');

  Future<void> deleteAccount() async {
    final authUid = gateway.currentUser?.uid;
    final accountId = widget.store.accountId;
    if (authUid == null || accountId != authUid) return;
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Șterge contul Pi Fit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Contul Firebase și backupul său vor fi șterse definitiv. Exportă mai întâi jurnalul pe care vrei să îl păstrezi: copia locală a contului nu va mai putea fi deschisă prin autentificare după ștergere. Confirmă cu parola contului.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Parola actuală'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Șterge definitiv'),
          ),
        ],
      ),
    );
    // The dialog route may still be animating with its controller attached.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (password == null ||
        !mounted ||
        gateway.currentUser?.uid != authUid ||
        widget.store.accountId != accountId) {
      return;
    }
    if (password.isEmpty) {
      toast(context, 'Introdu parola actuală pentru a confirma.');
      return;
    }
    await run(
      () => gateway.deleteAccount(password),
      'Contul și backupul cloud au fost șterse.',
    );
  }

  Future<void> importGuestJournal() async {
    final authUid = gateway.currentUser?.uid;
    final accountId = widget.store.accountId;
    if (authUid == null || accountId != authUid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Importă jurnalul local'),
        content: const Text(
          'Istoricul, rutinele, calendarul și favoritele profilului de oaspete vor fi adăugate la acest cont. Datele existente și copia de oaspete se păstrează. Profilul contului și antrenamentul activ rămân neschimbate. Backupul în cloud se face separat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Importă jurnalul'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        gateway.currentUser?.uid != authUid ||
        widget.store.accountId != accountId) {
      return;
    }
    await run(
      widget.store.importGuestJournal,
      'Jurnalul local a fost importat în cont.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.embedded,
      title: const Text('Profilul tău'),
    ),
    body: StreamBuilder<User?>(
      stream: gateway.authStateChanges,
      builder: (context, snapshot) {
        final user = gateway.currentUser ?? snapshot.data;
        return AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final profile = widget.store.profile;
            return PageBody(
              children: [
                PiCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: PiColors.lime,
                        child: Text(
                          widget.store.name.isEmpty
                              ? 'P'
                              : widget.store.name.characters.first
                                    .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF172000),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.store.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ??
                                  'Profil local · salvat pe dispozitiv',
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
                ),
                const SizedBox(height: 16),
                PiCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HealthScreen(store: widget.store),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: PiColors.lime.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.favorite_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Activitate și sănătate',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pași, energie și antrenamente',
                              style: TextStyle(
                                fontSize: 12,
                                color: PiColors.muted(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Citire locală · doar cu permisiunea ta',
                              style: TextStyle(
                                fontSize: 11,
                                color: PiColors.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (user == null) ...[
                  PiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Eyebrow(
                          icon: Icons.fingerprint_rounded,
                          text: 'CONTUL TĂU PI FIT',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Progresul tău merită\nun loc sigur.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Conectează-te pentru backup în cloud și acces la Pi Coach online când serviciul este configurat.',
                          style: TextStyle(color: PiColors.muted(context)),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _openAuth(false),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Conectează-te'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _openAuth(true),
                          child: const Text('Creează un cont'),
                        ),
                        if (!gateway.configured) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Conectarea nu a pornit încă. Configurația Firebase este inclusă; verifică internetul și repornește aplicația. Jurnalul local rămâne disponibil.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  PiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Eyebrow(
                          icon: user.emailVerified
                              ? Icons.verified_user_outlined
                              : Icons.mark_email_unread_outlined,
                          text: user.emailVerified
                              ? 'CONT CONECTAT'
                              : 'CONFIRMĂ ADRESA DE EMAIL',
                        ),
                        if (!user.emailVerified) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Verifică mesajul de confirmare primit pe email.',
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => run(
                                    gateway.resendVerification,
                                    'Email de confirmare retrimis.',
                                  ),
                            child: const Text(
                              'Retrimite emailul de verificare',
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => run(
                                    user.reload,
                                    'Starea adresei de email a fost actualizată.',
                                  ),
                            child: const Text('Am verificat emailul'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Backupul este manual. Încărcarea înlocuiește backupul contului; restaurarea înlocuiește datele locale.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: busy ? null : saveBackup,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Salvează backup în cloud'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : restore,
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('Restaurează din cloud'),
                        ),
                        if (widget.store.hasGuestJournal) ...[
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Ai antrenamente în profilul de oaspete? Poți adăuga o copie la jurnalul acestui cont.',
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: busy ? null : importGuestJournal,
                            icon: const Icon(Icons.move_to_inbox_outlined),
                            label: const Text('Importă jurnalul local'),
                          ),
                        ],
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  gateway.signOut,
                                  'Te-ai deconectat. Profilul de oaspete este activ; jurnalul contului este păstrat separat.',
                                ),
                          child: const Text('Deconectează-te'),
                        ),
                        if (busy) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ],
                SectionHeading(
                  title: 'Profil de antrenament',
                  action: 'Editează',
                  onAction: () => editTrainingProfile(context, widget.store),
                ),
                PiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.store.goal,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DetailPill(
                            icon: Icons.bolt_rounded,
                            text: profile.experience,
                          ),
                          _DetailPill(
                            icon: Icons.calendar_month_outlined,
                            text: '${profile.sessionsPerWeek} zile / săpt.',
                          ),
                          _DetailPill(
                            icon: Icons.timer_outlined,
                            text: '${profile.sessionMinutes} min / ședință',
                          ),
                          if (profile.age != null)
                            _DetailPill(
                              icon: Icons.person_outline,
                              text: '${profile.age} ani',
                            ),
                          if (profile.heightCm != null)
                            _DetailPill(
                              icon: Icons.height_rounded,
                              text: '${_number(profile.heightCm!)} cm',
                            ),
                          if (profile.weightKg != null)
                            _DetailPill(
                              icon: Icons.monitor_weight_outlined,
                              text: '${_number(profile.weightKg!)} kg',
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile.equipment.isEmpty
                            ? 'Adaugă echipamentul disponibil pentru recomandări mai potrivite.'
                            : 'Echipament: ${profile.equipment.join(', ')}',
                        style: TextStyle(color: PiColors.muted(context)),
                      ),
                      if (profile.limitations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Preferințe și limitări: ${profile.limitations}'),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Detaliile fizice sunt opționale. Nu sunt folosite pentru a calcula scorul de consecvență.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Preferințe'),
                PiCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.contrast_rounded),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Aspect',
                              style: TextStyle(fontWeight: FontWeight.w600),
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
                              if (v != null) {
                                run(
                                  () => widget.store.setTheme(v),
                                  'Aspect actualizat.',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 26),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Personalizare Pi Coach online'),
                        subtitle: const Text(
                          'Permite trimiterea profilului și a unui rezumat al jurnalului către serviciul AI când trimiți mesaje. Poți retrage acordul oricând.',
                        ),
                        value: profile.coachConsent,
                        onChanged: busy
                            ? null
                            : (v) => run(
                                () => widget.store.updateUserProfile(
                                  profile.copyWith(coachConsent: v),
                                ),
                                v
                                    ? 'Personalizarea AI online este permisă.'
                                    : 'Pi Coach va folosi recomandări locale.',
                              ),
                      ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Date și confidențialitate'),
                PiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Profilul de oaspete și fiecare cont au jurnale locale separate. Conectarea deschide doar datele contului tău; jurnalul de oaspete nu este importat automat. Îl poți accesa din nou prin deconectare sau poți importa o copie în cont. Deconectarea păstrează copia locală a contului, vizibilă când revii în același cont.',
                      ),
                      const SizedBox(height: 14),
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
                      if (user != null)
                        TextButton(
                          onPressed: busy ? null : deleteAccount,
                          child: Text(
                            'Șterge contul și backupul cloud',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );

  void _openAuth(bool register) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AuthScreen(store: widget.store, initialRegister: register),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final AppStore store;
  final bool initialRegister;
  const AuthScreen({
    super.key,
    required this.store,
    this.initialRegister = false,
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final gateway = FirebaseGateway.instance;
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController(),
      name = TextEditingController();
  late bool register;
  bool busy = false, obscure = true;
  String? error;
  @override
  void initState() {
    super.initState();
    register = widget.initialRegister;
    name.text = widget.store.name == 'Atlet' ? '' : widget.store.name;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!gateway.configured) {
      setState(
        () => error =
            gateway.configurationIssue ??
            'Firebase nu a putut porni. Configurația este inclusă; verifică conexiunea și repornește aplicația. Modul local rămâne disponibil.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final initialAuthUid = gateway.currentUser?.uid;
    final initialAccountId = widget.store.accountId;
    String? operationUid;
    try {
      String? profileWarning;
      if (register) {
        final requestedName = name.text;
        operationUid = await gateway.signUp(
          email.text,
          password.text,
          requestedName,
        );
        if (gateway.currentUser?.uid != operationUid) return;
        await widget.store.switchAccount(operationUid);
        if (gateway.currentUser?.uid != operationUid ||
            widget.store.accountId != operationUid) {
          return;
        }
        try {
          await widget.store.updateProfile(requestedName, widget.store.goal);
        } catch (_) {
          profileWarning =
              'Cont creat. Numele nu a putut fi salvat local; îl poți actualiza din Profil. Verifică și emailul de confirmare.';
        }
      } else {
        operationUid = await gateway.signIn(email.text, password.text);
        if (gateway.currentUser?.uid != operationUid) return;
        await widget.store.switchAccount(operationUid);
      }
      if (mounted &&
          gateway.currentUser?.uid == operationUid &&
          widget.store.accountId == operationUid) {
        toast(
          context,
          profileWarning ??
              (register
                  ? 'Cont creat. Verifică emailul de confirmare.'
                  : 'Bine ai revenit în Pi Fit.'),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted &&
          (operationUid == null
              ? gateway.currentUser?.uid == initialAuthUid &&
                    widget.store.accountId == initialAccountId
              : gateway.currentUser?.uid == operationUid)) {
        setState(() => error = _readableError(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (_validateEmail(email.text) != null) {
      setState(() => error = 'Introdu mai întâi o adresă de email validă.');
      return;
    }
    if (!gateway.configured) {
      setState(
        () => error =
            'Firebase nu este disponibil momentan. Verifică conexiunea și repornește aplicația pentru resetarea parolei.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await gateway.resetPassword(email.text);
      if (mounted) {
        toast(
          context,
          'Dacă există un cont cu această adresă, vei primi instrucțiuni de resetare.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = _readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pi Fit')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Eyebrow(
                      icon: Icons.bolt_rounded,
                      text: 'MAI MULTĂ PUTERE. ÎMPREUNĂ.',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      register ? 'Începe cu tine.' : 'Bine ai\nrevenit.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      register
                          ? 'Un cont pentru progresul pe care îl construiești, antrenament cu antrenament.'
                          : 'Intră în cont și păstrează-ți antrenamentele aproape.',
                      style: TextStyle(color: PiColors.muted(context)),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Conectare')),
                        ButtonSegment(value: true, label: Text('Cont nou')),
                      ],
                      selected: {register},
                      onSelectionChanged: busy
                          ? null
                          : (v) => setState(() {
                              register = v.first;
                              error = null;
                              form.currentState?.reset();
                            }),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 24),
                    if (register) ...[
                      TextFormField(
                        key: const Key('auth-name'),
                        controller: name,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nume',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Introdu numele tău.'
                            : v.trim().length > 60
                            ? 'Folosește cel mult 60 de caractere.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      key: const Key('auth-email'),
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: password,
                      obscureText: obscure,
                      autofillHints: [
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Parolă',
                        helperText: register ? 'Cel puțin 8 caractere.' : null,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Arată parola' : 'Ascunde parola',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Introdu parola.'
                          : v.length < 8
                          ? 'Parola trebuie să aibă cel puțin 8 caractere.'
                          : null,
                      onFieldSubmitted: (_) {
                        if (!register) submit();
                      },
                    ),
                    if (register) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('auth-confirmation'),
                        controller: confirmation,
                        obscureText: obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirmă parola',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) =>
                            v != password.text || v == null || v.isEmpty
                            ? 'Parolele trebuie să coincidă.'
                            : null,
                        onFieldSubmitted: (_) => submit(),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy ? null : resetPassword,
                          child: const Text('Ai uitat parola?'),
                        ),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          key: const Key('auth-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(register ? 'Creează cont' : 'Conectează-te'),
                    ),
                    const SizedBox(height: 20),
                    if (!gateway.configured)
                      PiCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mod local activ. Configurația Firebase este inclusă. Dacă autentificarea nu pornește, verifică internetul și repornește aplicația.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PiColors.muted(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Fiecare cont are un jurnal local separat. Datele de oaspete nu sunt importate automat. Backupul în cont se face explicit din Profil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? _validateEmail(String? value) =>
    value == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Introdu o adresă de email validă.'
    : null;

String _readableError(Object error) {
  if (error is! FirebaseAuthException) {
    if (error.toString().contains('permission-denied')) {
      return 'Accesul la datele cloud a fost refuzat. Verifică regulile Firestore pentru contul tău înainte de a reîncerca.';
    }
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
  return switch (error.code) {
    'invalid-email' => 'Adresa de email nu este validă.',
    'weak-password' => 'Folosește o parolă de cel puțin 8 caractere.',
    'email-already-in-use' => 'Există deja un cont cu această adresă.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Emailul sau parola nu sunt corecte.',
    'too-many-requests' => 'Prea multe încercări. Revino în câteva minute.',
    'network-request-failed' =>
      'Verifică conexiunea la internet și încearcă din nou.',
    'operation-not-allowed' =>
      'Activează Email/Password în Firebase Authentication.',
    'requires-recent-login' =>
      'Conectează-te din nou pentru a confirma această operație.',
    'app-not-authorized' || 'invalid-api-key' =>
      'Verifică înregistrarea aplicației și configurația Firebase.',
    _ => 'Operația nu a reușit (${error.code}).',
  };
}

Future<void> editTrainingProfile(BuildContext context, AppStore store) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProfileEditor(store: store),
    );

class _ProfileEditor extends StatefulWidget {
  final AppStore store;
  const _ProfileEditor({required this.store});
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      age = TextEditingController(),
      height = TextEditingController(),
      weight = TextEditingController(),
      limitations = TextEditingController();
  late String goal, experience;
  late int sessions, minutes;
  late Set<String> equipment;
  late Set<int> days;
  late final String? _editingAccountId, _editingAuthUid;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _editingAccountId = widget.store.accountId;
    _editingAuthUid = FirebaseGateway.instance.currentUser?.uid;
    final p = widget.store.profile;
    name.text = widget.store.name;
    goal = widget.store.goal;
    experience = p.experience;
    age.text = p.age?.toString() ?? '';
    height.text = p.heightCm == null ? '' : _number(p.heightCm!);
    weight.text = p.weightKg == null ? '' : _number(p.weightKg!);
    limitations.text = p.limitations;
    sessions = p.sessionsPerWeek;
    minutes = p.sessionMinutes;
    equipment = {...p.equipment};
    days = {...p.preferredDays};
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    height.dispose();
    weight.dispose();
    limitations.dispose();
    super.dispose();
  }

  Future<void> save() async {
    bool sameScope() =>
        mounted &&
        widget.store.accountId == _editingAccountId &&
        FirebaseGateway.instance.currentUser?.uid == _editingAuthUid;
    if (!sameScope()) return;
    if (!form.currentState!.validate()) {
      toast(context, 'Verifică valorile marcate în formular.');
      return;
    }
    setState(() => busy = true);
    try {
      final profile = widget.store.profile.copyWith(
        age: _decimal(age.text)?.toInt(),
        heightCm: _decimal(height.text),
        weightKg: _decimal(weight.text),
        clearAge: age.text.trim().isEmpty,
        clearHeightCm: height.text.trim().isEmpty,
        clearWeightKg: weight.text.trim().isEmpty,
        experience: experience,
        sessionsPerWeek: sessions,
        sessionMinutes: minutes,
        equipment: equipment.toList(),
        preferredDays: days.toList()..sort(),
        limitations: limitations.text.trim(),
      );
      await widget.store.updateUserProfile(
        profile,
        newName: name.text,
        newGoal: goal,
      );
      if (mounted && sameScope()) {
        toast(context, 'Profil de antrenament salvat.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted && sameScope()) toast(context, _readableError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .93,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Planul începe cu tine',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Închide',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Completează doar ce vrei să folosească Pi Coach. Poți modifica sau șterge detaliile oricând.',
                      style: TextStyle(color: PiColors.muted(context)),
                    ),
                    const SectionHeading(title: 'Tu și obiectivul tău'),
                    TextFormField(
                      key: const Key('profile-name'),
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nume'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Introdu un nume.'
                          : v.trim().length > 60
                          ? 'Maximum 60 de caractere.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: goal,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Obiectiv'),
                      items: AppStore.profileGoals
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
                      onChanged: (v) => setState(() => goal = v!),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: experience,
                      decoration: const InputDecoration(
                        labelText: 'Experiență',
                      ),
                      items: UserProfile.experiences
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => experience = v!),
                    ),
                    const SectionHeading(title: 'Ritmul tău'),
                    _StepperRow(
                      label: 'Antrenamente / săptămână',
                      value: '$sessions',
                      minus: sessions > 1
                          ? () => setState(() => sessions--)
                          : null,
                      plus: sessions < 7
                          ? () => setState(() => sessions++)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _StepperRow(
                      label: 'Minute / antrenament',
                      value: '$minutes',
                      minus: minutes > 15
                          ? () => setState(
                              () => minutes = (minutes - 5).clamp(15, 180),
                            )
                          : null,
                      plus: minutes < 180
                          ? () => setState(
                              () => minutes = (minutes + 5).clamp(15, 180),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Zile preferate',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: List.generate(
                        7,
                        (i) => FilterChip(
                          label: Text(
                            const ['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'][i],
                          ),
                          selected: days.contains(i + 1),
                          onSelected: (v) => setState(() {
                            v ? days.add(i + 1) : days.remove(i + 1);
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Preferințele nu programează automat antrenamente. Folosește Calendar pentru date și remindere.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                    const SectionHeading(title: 'Echipament disponibil'),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children:
                          {
                                ...equipment,
                                'Sală completă',
                                'Gantere',
                                'Bară',
                                'Aparate',
                                'Cablu',
                                'Greutatea corpului',
                                'Benzi elastice',
                                'Kettlebell',
                              }
                              .map(
                                (e) => FilterChip(
                                  label: Text(e),
                                  selected: equipment.contains(e),
                                  onSelected: (v) => setState(() {
                                    v ? equipment.add(e) : equipment.remove(e);
                                  }),
                                ),
                              )
                              .toList(),
                    ),
                    const SectionHeading(title: 'Detalii opționale'),
                    _optionalNumber(
                      age,
                      'Vârstă (ani)',
                      13,
                      100,
                      integer: true,
                      keyName: 'profile-age',
                    ),
                    const SizedBox(height: 12),
                    _optionalNumber(
                      height,
                      'Înălțime (cm)',
                      100,
                      250,
                      keyName: 'profile-height',
                    ),
                    const SizedBox(height: 12),
                    _optionalNumber(
                      weight,
                      'Greutate (kg)',
                      25,
                      350,
                      keyName: 'profile-weight',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('profile-limitations'),
                      controller: limitations,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1500,
                      decoration: const InputDecoration(
                        labelText: 'Preferințe sau limitări',
                        hintText:
                            'Ex.: prefer aparatele; evit mișcările deasupra capului.',
                      ),
                      validator: (v) => (v?.length ?? 0) > 1500
                          ? 'Maximum 1.500 de caractere.'
                          : null,
                    ),
                    Text(
                      'Pi Coach nu poate diagnostica afecțiuni. Pentru durere sau recuperare după o accidentare, cere sfatul unui specialist.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-training-profile'),
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Se salvează…' : 'Salvează profilul'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _optionalNumber(
    TextEditingController controller,
    String label,
    num min,
    num max, {
    bool integer = false,
    required String keyName,
  }) => TextFormField(
    key: Key(keyName),
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(
      labelText: label,
      helperText: 'Opțional · $min–$max',
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      final n = _decimal(v);
      if (n == null ||
          !n.isFinite ||
          n < min ||
          n > max ||
          (integer && n != n.roundToDouble())) {
        return 'Introdu ${integer ? 'un număr întreg' : 'o valoare'} între $min și $max.';
      }
      return null;
    },
  );
}

double? _decimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class _StepperRow extends StatelessWidget {
  final String label, value;
  final VoidCallback? minus, plus;
  const _StepperRow({
    required this.label,
    required this.value,
    this.minus,
    this.plus,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        onPressed: minus,
        tooltip: 'Redu $label',
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      IconButton(
        onPressed: plus,
        tooltip: 'Crește $label',
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ],
  );
}

class _Eyebrow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Eyebrow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: PiColors.muted(context),
          ),
        ),
      ),
    ],
  );
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailPill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
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
  String? _conversationAccountId;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _conversationAccountId = widget.store.accountId;
    widget.store.addListener(_accountChanged);
  }

  void _accountChanged() {
    if (_conversationAccountId == widget.store.accountId) return;
    _conversationAccountId = widget.store.accountId;
    _requestGeneration++;
    input.clear();
    setState(() {
      messages.clear();
      busy = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
  }

  @override
  void didUpdateWidget(CoachScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_accountChanged);
      widget.store.addListener(_accountChanged);
      _accountChanged();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_accountChanged);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send([String? suggestion]) async {
    final question = (suggestion ?? input.text).trim();
    if (question.isEmpty || busy) return;
    final generation = ++_requestGeneration;
    final history = messages
        .skip(messages.length > 12 ? messages.length - 12 : 0)
        .map((m) => {'role': m.user ? 'user' : 'assistant', 'content': m.text})
        .toList();
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
        localContext: widget.store.localCoachContext,
        history: history,
        allowRemote:
            widget.store.profile.coachConsent &&
            FirebaseGateway.instance.currentUser != null,
      );
      if (mounted && generation == _requestGeneration) {
        setState(() => messages.add((text: reply, user: false)));
      }
    } catch (e) {
      if (mounted && generation == _requestGeneration) {
        setState(() => messages.add((text: _readableError(e), user: false)));
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final profile = widget.store.profile;
      final online =
          service.remoteConfigured &&
          profile.coachConsent &&
          FirebaseGateway.instance.currentUser != null;
      return Scaffold(
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
                        if (Navigator.of(context).canPop())
                          IconButton.filled(
                            onPressed: () => Navigator.maybePop(context),
                            tooltip: 'Înapoi',
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: PiColors.lime,
                              foregroundColor: const Color(0xFF172000),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PiColors.lime,
                              borderRadius: BorderRadius.circular(18),
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              Text(
                                online
                                    ? 'AI online · personalizat pentru tine'
                                    : 'Coach local · adaptat profilului',
                                style: TextStyle(
                                  color: PiColors.muted(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              editTrainingProfile(context, widget.store),
                          tooltip: 'Personalizează profilul',
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                      children: [
                        if (messages.isEmpty) ...[
                          Text(
                            'Un plan care\nține cont de tine.',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Obiectiv, timp, echipament și antrenamente reale. Începem cu ce ai, apoi ajustăm pas cu pas.',
                            style: TextStyle(color: PiColors.muted(context)),
                          ),
                          const SizedBox(height: 22),
                          PiCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _Eyebrow(
                                  icon: Icons.person_outline_rounded,
                                  text: 'CE FOLOSEȘTE COACH-UL',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.store.goal,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    _DetailPill(
                                      icon: Icons.bolt_rounded,
                                      text: profile.experience,
                                    ),
                                    _DetailPill(
                                      icon: Icons.calendar_today_outlined,
                                      text:
                                          '${profile.sessionsPerWeek} zile / săpt.',
                                    ),
                                    _DetailPill(
                                      icon: Icons.timer_outlined,
                                      text: '${profile.sessionMinutes} min',
                                    ),
                                    _DetailPill(
                                      icon: Icons.check_circle_outline_rounded,
                                      text:
                                          '${widget.store.history.where((s) => s.finishedAt != null).length} antrenamente',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  profile.equipment.isEmpty
                                      ? 'Ce echipament ai? Adaugă-l pentru un plan mai potrivit.'
                                      : 'Echipament: ${profile.equipment.join(', ')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PiColors.muted(context),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => editTrainingProfile(
                                    context,
                                    widget.store,
                                  ),
                                  child: const Text('Ajustează profilul meu'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ...[
                            'Fă-mi un plan de ${profile.sessionsPerWeek} zile, cu ședințe de ${profile.sessionMinutes} minute.',
                            widget.store.history.isEmpty
                                ? 'Cu ce greutăți și câte serii să încep?'
                                : 'Analizează jurnalul meu și recomandă următorul pas.',
                            'Cum adaptez antrenamentul la echipamentul meu?',
                          ].map(
                            (q) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: PiCard(
                                onTap: () => send(q),
                                padding: const EdgeInsets.all(16),
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
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.north_east_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (service.remoteConfigured &&
                              !profile.coachConsent) ...[
                            const SizedBox(height: 8),
                            PiCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Activează personalizarea AI online',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Dacă accepți, mesajele, profilul și un rezumat al jurnalului vor fi trimise serviciului AI când trimiți o întrebare. Până atunci primești sugestii locale.',
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () async {
                                      try {
                                        await widget.store.updateUserProfile(
                                          profile.copyWith(coachConsent: true),
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          toast(context, _readableError(e));
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'Permit personalizarea online',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (service.remoteConfigured &&
                              FirebaseGateway.instance.currentUser == null)
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AuthScreen(store: widget.store),
                                ),
                              ),
                              child: const Text(
                                'Conectează-te pentru Pi Coach online',
                              ),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            online
                                ? 'AI poate greși. Verifică recomandările și adaptează-le cu un antrenor; pentru durere sau afecțiuni, cere sfatul unui specialist.'
                                : 'Sugestiile locale folosesc reguli și datele profilului; nu sunt răspunsuri ale unui model AI online. Mesajele nu sunt trimise pe server. Pentru durere sau afecțiuni, consultă un specialist.',
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
                                left: m.user ? 26 : 0,
                                right: m.user ? 0 : 12,
                              ),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: m.user
                                    ? PiColors.lime
                                    : PiColors.surface(
                                        context,
                                      ).withValues(alpha: .8),
                                borderRadius: BorderRadius.circular(22),
                                border: m.user
                                    ? null
                                    : Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: .07),
                                      ),
                              ),
                              child: SelectableText(
                                m.text,
                                style: TextStyle(
                                  height: 1.55,
                                  color: m.user
                                      ? const Color(0xFF172000)
                                      : null,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text('Pi Coach pregătește răspunsul…'),
                                ),
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
                            key: const Key('coach-message'),
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
    },
  );
}
