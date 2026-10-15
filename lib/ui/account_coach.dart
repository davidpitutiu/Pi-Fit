export 'coach_screen.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/user_profile.dart';
import '../services/firebase_gateway.dart';
import '../state/app_store.dart';
import 'body_measurements_screen.dart';
import 'export_screen.dart';
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
        'Your account is not ready yet. Sign in again before restoring.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore your backup?'),
        content: const Text(
          'The backup will replace the local data for this account. Export it first if you want to keep a copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Restore'),
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
        throw StateError('The account changed. Try restoring again.');
      }
      final data = await gateway.loadBackup();
      if (gateway.currentUser?.uid != authUid ||
          widget.store.accountId != accountId) {
        throw StateError('The account changed. Try restoring again.');
      }
      if (data == null) {
        throw StateError('There is no backup in this account yet.');
      }
      await widget.store.restoreBackup(data, expectedAccountId: authUid);
    }, 'Backup restored on this device.');
  }

  Future<void> saveBackup() => run(() async {
    final authUid = gateway.currentUser?.uid;
    if (authUid == null || widget.store.accountId != authUid) {
      throw StateError(
        'Your account is not ready yet. Sign in again before backing up.',
      );
    }
    final data = widget.store.exportData();
    await gateway.saveBackup(data);
  }, 'Backup saved to your account.');

  Future<void> deleteAccount() async {
    final authUid = gateway.currentUser?.uid;
    final accountId = widget.store.accountId;
    if (authUid == null || accountId != authUid) return;
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your Pi Fit account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Firebase account and cloud backup will be permanently deleted. Export your journal first: its local copy cannot be reopened by signing in after deletion. Confirm with your account password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    // The dialog route may still be yearsmating with its controller attached.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (password == null ||
        !mounted ||
        gateway.currentUser?.uid != authUid ||
        widget.store.accountId != accountId) {
      return;
    }
    if (password.isEmpty) {
      toast(context, 'Enter your current password to confirm.');
      return;
    }
    await run(
      () => gateway.deleteAccount(password),
      'Your account and cloud backup have been deleted.',
    );
  }

  Future<void> importGuestJournal() async {
    final authUid = gateway.currentUser?.uid;
    final accountId = widget.store.accountId;
    if (authUid == null || accountId != authUid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import guest journal'),
        content: const Text(
          'Guest workout history, routines, calendar, favorites and saved body measurements will be added to this account. Existing data and the guest copy are kept. Your profile and active workout remain unchanged. Cloud backup is a separate action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Import journal'),
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
      'Guest journal imported into your account.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.embedded,
      title: const Text('Your profile'),
    ),
    body: StreamBuilder<User?>(
      stream: gateway.authStateChanges,
      builder: (context, snapshot) {
        final user = gateway.currentUser ?? snapshot.data;
        return AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final profile = widget.store.profile;
            final completedWorkouts = widget.store.totalCompletedWorkouts;
            final weights = widget.store.bodyMeasurements
                .where((m) => m.weightKg != null)
                .toList();
            final latestWeight =
                weights.firstOrNull?.weightKg ?? profile.weightKg;
            final latestHeight =
                widget.store.bodyMeasurements
                    .where((m) => m.heightCm != null)
                    .firstOrNull
                    ?.heightCm ??
                profile.heightCm;
            final weightChange = weights.length < 2
                ? null
                : weights.first.weightKg! - weights[1].weightKg!;
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
                                  'Guest profile · saved on this device',
                              style: TextStyle(
                                fontSize: 12,
                                color: PiColors.muted(context),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '$completedWorkouts ${completedWorkouts == 1 ? 'workout' : 'workouts'} completed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
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
                              'Health and activity',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Steps, measurements and heart rate',
                              style: TextStyle(
                                fontSize: 12,
                                color: PiColors.muted(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Local access · only with your permission',
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
                          text: 'YOUR PI FIT ACCOUNT',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your progress deserves\na safe place.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in for cloud backup and Pi Coach online when the service is available.',
                          style: TextStyle(color: PiColors.muted(context)),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _openAuth(false),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign in'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _openAuth(true),
                          child: const Text('Create an account'),
                        ),
                        if (!gateway.configured) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Sign-in has not started yet. Firebase configuration is included; check your connection and restart the app. Your local journal is available.',
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
                              ? 'SIGNED IN'
                              : 'VERIFY YOUR EMAIL',
                        ),
                        if (!user.emailVerified) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Check your inbox for the verification email.',
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => run(
                                    gateway.resendVerification,
                                    'Verification email sent again.',
                                  ),
                            child: const Text('Resend verification email'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => run(
                                    user.reload,
                                    'Email verification status refreshed.',
                                  ),
                            child: const Text('I verified my email'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Backup is manual. Uploading replaces your cloud backup; restoring replaces the local data for this account.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: busy ? null : saveBackup,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Save cloud backup'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : restore,
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('Restore from cloud'),
                        ),
                        if (widget.store.hasGuestJournal) ...[
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Have workouts in your guest profile? Add a copy to this account.',
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: busy ? null : importGuestJournal,
                            icon: const Icon(Icons.move_to_inbox_outlined),
                            label: const Text('Import guest journal'),
                          ),
                        ],
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  gateway.signOut,
                                  'Signed out. Your guest profile is active; the account journal is kept separately.',
                                ),
                          child: const Text('Sign out'),
                        ),
                        if (busy) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ],
                SectionHeading(
                  title: 'Training profile',
                  action: 'Edit',
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
                            text: '${profile.sessionsPerWeek} days / week',
                          ),
                          _DetailPill(
                            icon: Icons.timer_outlined,
                            text: '${profile.sessionMinutes} min / workout',
                          ),
                          if (profile.age != null)
                            _DetailPill(
                              icon: Icons.person_outline,
                              text: '${profile.age} years',
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
                            ? 'Add your available equipment for more relevant suggestions.'
                            : 'Equipment: ${profile.equipment.join(', ')}',
                        style: TextStyle(color: PiColors.muted(context)),
                      ),
                      if (profile.limitations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Preferences and limitations: ${profile.limitations}',
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Body details are optional and do not affect your consistency score.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PiColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionHeading(
                  title: 'Body measurements',
                  action: 'View',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BodyMeasurementsScreen(store: widget.store),
                    ),
                  ),
                ),
                PiCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BodyMeasurementsScreen(store: widget.store),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _DetailPill(
                            icon: Icons.monitor_weight_outlined,
                            text: latestWeight == null
                                ? 'Add weight'
                                : '${_number(latestWeight)} kg',
                          ),
                          _DetailPill(
                            icon: Icons.height_rounded,
                            text: latestHeight == null
                                ? 'Add height'
                                : '${_number(latestHeight)} cm',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        weightChange == null
                            ? 'Save measurements to see your change over time.'
                            : '${weightChange > 0 ? '+' : ''}${_number(double.parse(weightChange.toStringAsFixed(1)))} kg since your previous weight record.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PiColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                BodyMeasurementsScreen(store: widget.store),
                          ),
                        ),
                        icon: const Icon(Icons.show_chart_rounded),
                        label: const Text('Track measurements'),
                      ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Preferences'),
                PiCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.contrast_rounded),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Appearance',
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
                                child: Text('System'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                run(
                                  () => widget.store.setTheme(v),
                                  'Appearance updated.',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 26),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Personalize Pi Coach online'),
                        subtitle: const Text(
                          'Allow your profile and a journal summary to be sent to the AI service when you send a message. You can withdraw permission at any time.',
                        ),
                        value: profile.coachConsent,
                        onChanged: busy
                            ? null
                            : (v) => run(
                                () => widget.store.updateUserProfile(
                                  profile.copyWith(coachConsent: v),
                                ),
                                v
                                    ? 'Online AI personalization enabled.'
                                    : 'Pi Coach will use local suggestions.',
                              ),
                      ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Data and privacy'),
                PiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Guest profiles and accounts have separate local journals. Signing in opens only that account; guest data is never imported automatically. Sign out to return to the guest profile, or import a copy into your account. Signing out preserves your account journal for your next sign-in.',
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ExportScreen(store: widget.store),
                          ),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Export a progress report'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => run(
                          () => Clipboard.setData(
                            ClipboardData(
                              text: const JsonEncoder.withIndent(
                                '  ',
                              ).convert(widget.store.exportData()),
                            ),
                          ),
                          'JSON backup copied. Save it somewhere safe.',
                        ),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Copy JSON backup'),
                      ),
                      if (user != null)
                        TextButton(
                          onPressed: busy ? null : deleteAccount,
                          child: Text(
                            'Delete account and cloud backup',
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
    name.text = widget.store.name == 'Athlete' ? '' : widget.store.name;
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
    if (busy) return;
    if (!form.currentState!.validate()) return;
    if (!gateway.configured) {
      setState(
        () => error =
            gateway.configurationIssue ??
            'Firebase could not start. Configuration is included; check your connection and restart the app. Local mode is available.',
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
              'Account created. Your name could not be saved locally; update it in Profile. Check your verification email too.';
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
                  ? 'Account created. Check your verification email.'
                  : 'Welcome back to Pi Fit.'),
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
    if (busy) return;
    if (_validateEmail(email.text) != null) {
      setState(() => error = 'Enter a valid email address first.');
      return;
    }
    if (!gateway.configured) {
      setState(
        () => error =
            'Firebase is temporarily unavailable. Check your connection and restart the app to reset your password.',
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
          'If an account exists for this address, you will receive password reset instructions.',
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
                      text: 'STRONGER. TOGETHER.',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      register ? 'It starts with you.' : 'Welcome\nback.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      register
                          ? 'One account for the progress you build, workout by workout.'
                          : 'Sign in and keep your training close.',
                      style: TextStyle(color: PiColors.muted(context)),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in')),
                        ButtonSegment(value: true, label: Text('New account')),
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
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your name.'
                            : v.trim().length > 60
                            ? 'Use at most 60 characters.'
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
                        labelText: 'Password',
                        helperText: register ? 'At least 8 characters.' : null,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Enter your password.'
                          : v.length < 8
                          ? 'Your password must contain at least 8 characters.'
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
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) =>
                            v != password.text || v == null || v.isEmpty
                            ? 'Passwords must match.'
                            : null,
                        onFieldSubmitted: (_) => submit(),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy ? null : resetPassword,
                          child: const Text('Forgot password?'),
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
                          : Text(register ? 'Create account' : 'Sign in'),
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
                                'Local mode is active. Firebase configuration is included. If sign-in does not start, check your connection and restart the app.',
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
                      'Each account has its own local journal. Guest data is never imported automatically. Create a cloud backup explicitly from Profile.',
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
    ? 'Enter a valid email address.'
    : null;

String _readableError(Object error) {
  if (error is! FirebaseAuthException) {
    if (error.toString().contains('permission-denied')) {
      return 'Access to cloud data was denied. Check the Firestore rules for your account before trying again.';
    }
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
  return switch (error.code) {
    'invalid-email' => 'The email address is invalid.',
    'weak-password' => 'Use a password with at least 8 characters.',
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The email or password is incorrect.',
    'too-many-requests' => 'Too many attempts. Try again in a few minutes.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'operation-not-allowed' =>
      'Enable Email/Password in Firebase Authentication.',
    'requires-recent-login' => 'Sign in again to confirm this action.',
    'app-not-authorized' || 'invalid-api-key' =>
      'Check the app registration and Firebase configuration.',
    _ => 'The action failed (${error.code}).',
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
    if (busy) return;
    bool sameScope() =>
        mounted &&
        widget.store.accountId == _editingAccountId &&
        FirebaseGateway.instance.currentUser?.uid == _editingAuthUid;
    if (!sameScope()) return;
    if (!form.currentState!.validate()) {
      toast(context, 'Check the highlighted values.');
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
        toast(context, 'Training profile saved.');
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
                    'Your plan starts with you',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
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
                      'Share only what you want Pi Coach to use. You can edit or clear these details any time.',
                      style: TextStyle(color: PiColors.muted(context)),
                    ),
                    const SectionHeading(title: 'You and your goal'),
                    TextFormField(
                      key: const Key('profile-name'),
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a name.'
                          : v.trim().length > 60
                          ? 'At most 60 characters.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: goal,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Goal'),
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
                        labelText: 'Experience',
                      ),
                      items: UserProfile.experiences
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => experience = v!),
                    ),
                    const SectionHeading(title: 'Your training rhythm'),
                    _StepperRow(
                      label: 'Workouts / week',
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
                      label: 'Minutes / workout',
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
                      'Preferred days',
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
                            const [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ][i],
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
                      'Preferences do not schedule workouts automatically. Use Calendar for dates and reminders.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                    const SectionHeading(title: 'Available equipment'),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children:
                          {
                                ...equipment,
                                'Full gym',
                                'Dumbbells',
                                'Barbell',
                                'Machines',
                                'Cable',
                                'Bodyweight',
                                'Resistance bands',
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
                    const SectionHeading(title: 'Optional details'),
                    _optionalNumber(
                      age,
                      'Age (years)',
                      13,
                      100,
                      integer: true,
                      keyName: 'profile-age',
                    ),
                    const SizedBox(height: 12),
                    _optionalNumber(
                      height,
                      'Height (cm)',
                      100,
                      250,
                      keyName: 'profile-height',
                    ),
                    const SizedBox(height: 12),
                    _optionalNumber(
                      weight,
                      'Weight (kg)',
                      25,
                      350,
                      keyName: 'profile-weight',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Changing weight or height saves a dated measurement automatically. Clearing a field keeps the measurement history.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PiColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('profile-limitations'),
                      controller: limitations,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1500,
                      decoration: const InputDecoration(
                        labelText: 'Preferences or limitations',
                        hintText:
                            'For example: I prefer machines and avoid overhead movements.',
                      ),
                      validator: (v) => (v?.length ?? 0) > 1500
                          ? 'At most 1,500 characters.'
                          : null,
                    ),
                    Text(
                      'Pi Coach cannot diagnose conditions. For pain or injury recovery, consult a qualified professional.',
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
                  child: Text(busy ? 'Saving…' : 'Save profile'),
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
      helperText: 'Optional · $min–$max',
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return null;
      final n = _decimal(v);
      if (n == null ||
          !n.isFinite ||
          n < min ||
          n > max ||
          (integer && n != n.roundToDouble())) {
        return 'Enter ${integer ? 'a whole number' : 'a value'} between $min and $max.';
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
        tooltip: 'Decrease $label',
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      IconButton(
        onPressed: plus,
        tooltip: 'Increase $label',
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
