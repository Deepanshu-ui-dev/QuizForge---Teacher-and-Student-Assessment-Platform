import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../utils/app_role.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return ApiClient(
    storage,
    onUnauthorized: () async {
      // Read lazily: the session notifier depends on storage, not on the client.
      await ref.read(sessionProvider.notifier).signOut();
    },
  );
});

class SessionState {
  const SessionState({
    required this.isAuthenticated,
    required this.onboardingSeen,
    this.role,
    this.userId,
    this.name,
    this.email,
  });

  final bool isAuthenticated;
  final bool onboardingSeen;
  final AppRole? role;
  final int? userId;
  final String? name;
  final String? email;

  static const initial = SessionState(
    isAuthenticated: false,
    onboardingSeen: false,
  );

  String get firstName {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

/// Single source of truth for "who is signed in".
///
/// Transitions are applied synchronously via [signedIn], [signOut] and
/// [markOnboardingSeen] instead of invalidating and re-reading storage, so
/// the router never observes a stale value mid-transition (which used to
/// flash the auth screen right after a successful login).
class SessionController extends AsyncNotifier<SessionState> {
  SecureStorageService get _storage => ref.read(secureStorageServiceProvider);

  @override
  Future<SessionState> build() async {
    final storage = ref.watch(secureStorageServiceProvider);
    try {
      final onboardingSeen = await storage.onboardingSeen;
      final token = await storage.token;

      if (token == null || token.isEmpty) {
        return SessionState(isAuthenticated: false, onboardingSeen: onboardingSeen);
      }

      return SessionState(
        isAuthenticated: true,
        onboardingSeen: onboardingSeen,
        role: AppRole.fromBackendRole(await storage.userRole),
        userId: await storage.userId,
        name: await storage.userName,
        email: await storage.userEmail,
      );
    } catch (_) {
      // Corrupted keystore entries (common after Android backups/restores)
      // must not leave the app stuck on the splash screen.
      try {
        await storage.clearSession();
      } catch (_) {}
      return SessionState.initial;
    }
  }

  bool get _onboardingSeen => state.valueOrNull?.onboardingSeen ?? true;

  void signedIn(AppUser user) {
    state = AsyncData(
      SessionState(
        isAuthenticated: true,
        onboardingSeen: true,
        role: AppRole.fromBackendRole(user.backendRole),
        userId: user.id,
        name: user.name,
        email: user.email,
      ),
    );
  }

  Future<void> signOut() async {
    final wasAuthenticated = state.valueOrNull?.isAuthenticated ?? false;
    await _storage.clearSession();
    if (!wasAuthenticated && state.hasValue) return;
    state = AsyncData(SessionState(isAuthenticated: false, onboardingSeen: _onboardingSeen));
  }

  Future<void> markOnboardingSeen() async {
    await _storage.setOnboardingSeen();
    final current = state.valueOrNull ?? SessionState.initial;
    state = AsyncData(
      SessionState(
        isAuthenticated: current.isAuthenticated,
        onboardingSeen: true,
        role: current.role,
        userId: current.userId,
        name: current.name,
        email: current.email,
      ),
    );
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final stored = await ref.read(secureStorageServiceProvider).themeMode;
      final mode = ThemeMode.values.where((m) => m.name == stored).firstOrNull;
      if (mode != null) state = mode;
    } catch (_) {}
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await ref.read(secureStorageServiceProvider).setThemeMode(mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
