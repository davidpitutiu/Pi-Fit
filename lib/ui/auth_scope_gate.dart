import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_gateway.dart';
import '../state/app_store.dart';
import 'theme.dart';

/// Keep the previous account's screens covered until its local data has been
/// replaced by the authenticated account's isolated profile.
class AuthScopeGate extends StatefulWidget {
  const AuthScopeGate({
    super.key,
    required this.store,
    required this.navigatorKey,
    required this.child,
    this.gateway,
  });
  final AppStore store;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final FirebaseGateway? gateway;
  @override
  State<AuthScopeGate> createState() => _AuthScopeGateState();
}

class _AuthScopeGateState extends State<AuthScopeGate> {
  StreamSubscription<User?>? _subscription;
  Future<void> _pending = Future<void>.value();
  int _generation = 0;
  bool _switching = false;
  String? _error;
  FirebaseGateway get _gateway => widget.gateway ?? FirebaseGateway.instance;

  @override
  void initState() {
    super.initState();
    _switching = _gateway.currentUser?.uid != widget.store.accountId;
    _subscription = _gateway.authStateChanges.listen(
      _changed,
      onError: (Object error) {
        if (mounted) {
          setState(
            () =>
                _error = 'Your account status could not be checked. Try again.',
          );
        }
      },
    );
  }

  void _changed(User? user) {
    final uid = user?.uid;
    final shouldSetName =
        user?.displayName?.trim().isNotEmpty == true &&
        widget.store.name == 'Athlete';
    if (uid == widget.store.accountId &&
        !_switching &&
        _error == null &&
        !shouldSetName) {
      return;
    }
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _switching = true;
        _error = null;
      });
    }
    _pending = _pending.then((_) async {
      if (!mounted || generation != _generation) return;
      final changed = uid != widget.store.accountId;
      try {
        await widget.store.switchAccount(uid);
        if (generation != _generation || !mounted) return;
        if (user?.displayName?.trim().isNotEmpty == true &&
            widget.store.name == 'Athlete') {
          await widget.store.updateProfile(
            user!.displayName!,
            widget.store.goal,
          );
        }
        // Name persistence is another asynchronous boundary: an older
        // account's continuation must never reset the newer account's routes.
        if (!mounted ||
            generation != _generation ||
            _gateway.currentUser?.uid != uid ||
            widget.store.accountId != uid) {
          return;
        }
        if (changed) {
          widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      } catch (error) {
        if (mounted && generation == _generation) {
          _error =
              'Your profile could not be opened. Your existing data is preserved. ${error.toString().replaceFirst('Bad state: ', '')}';
        }
      } finally {
        if (mounted && generation == _generation) {
          setState(() => _switching = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked =
        _switching ||
        _error != null ||
        _gateway.currentUser?.uid != widget.store.accountId;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: locked,
          child: ExcludeFocus(excluding: locked, child: widget.child),
        ),
        if (locked)
          Positioned.fill(
            child: Material(
              color: PiColors.dark(context)
                  ? const Color(0xFF0C1912)
                  : const Color(0xFFF0F6EC),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error == null) ...[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            const Text('Opening your profile…'),
                          ] else ...[
                            const Icon(Icons.person_outline_rounded, size: 42),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => _changed(_gateway.currentUser),
                              child: const Text('Try again'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await _gateway.signOut();
                                  _changed(null);
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => _error =
                                          'Sign-out failed. Please try again.',
                                    );
                                  }
                                }
                              },
                              child: const Text('Return to guest profile'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
