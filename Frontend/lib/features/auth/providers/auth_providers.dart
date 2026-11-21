import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/models/user.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/repositories/repository_providers.dart';

/// Coordinates the auth repository with the session state machine.
///
/// Deliberately stateless: each screen owns its own loading/error state, so
/// an error on Login no longer leaks into Register (they used to share one
/// AsyncNotifier). Navigation is driven by the router reacting to
/// [sessionProvider]; callers never navigate after sign-in/out themselves.
class AuthService {
  AuthService(this._ref);
  final Ref _ref;

  /// Throws a `Failure` on error.
  Future<AppUser> login({required String email, required String password}) async {
    try {
      final user = await _ref.read(authRepositoryProvider).login(email: email, password: password);
      _ref.read(sessionProvider.notifier).signedIn(user);
      return user;
    } catch (e) {
      throw FailureMapper.fromException(e);
    }
  }

  /// Registers then signs in, since the register endpoint returns no token.
  /// Throws a `Failure` on error.
  Future<AppUser> registerAndLogin({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      await _ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password, role: role);
    } catch (e) {
      throw FailureMapper.fromException(e);
    }
    return login(email: email, password: password);
  }

  Future<void> logout() => _ref.read(sessionProvider.notifier).signOut();
}

final authServiceProvider = Provider<AuthService>(AuthService.new);
