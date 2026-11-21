import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_platform/core/models/user.dart';
import 'package:quiz_platform/core/providers/core_providers.dart';
import 'package:quiz_platform/core/storage/secure_storage.dart';
import 'package:quiz_platform/core/utils/app_role.dart';

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage({this.throwOnRead = false}) : super(const FlutterSecureStorage());
  final bool throwOnRead;
  final Map<String, String> data = {};
  bool cleared = false;

  @override
  Future<String?> get token async {
    if (throwOnRead) throw Exception('keystore corrupted');
    return data['token'];
  }

  @override
  Future<bool> get onboardingSeen async => data['onboarding'] == 'true';
  @override
  Future<String?> get userRole async => data['role'];
  @override
  Future<String?> get userName async => data['name'];
  @override
  Future<String?> get userEmail async => data['email'];
  @override
  Future<int?> get userId async => int.tryParse(data['id'] ?? '');

  @override
  Future<void> setOnboardingSeen() async => data['onboarding'] = 'true';

  @override
  Future<void> clearSession() async {
    cleared = true;
    data.removeWhere((k, _) => k != 'onboarding');
  }
}

void main() {
  ProviderContainer make(_MemoryStorage storage) {
    final c = ProviderContainer(overrides: [secureStorageServiceProvider.overrideWithValue(storage)]);
    addTearDown(c.dispose);
    return c;
  }

  test('restores an authenticated teacher session from storage', () async {
    final storage = _MemoryStorage()
      ..data.addAll({'token': 't', 'role': 'ADMIN', 'name': 'Ada Lovelace', 'id': '7', 'onboarding': 'true'});
    final s = await make(storage).read(sessionProvider.future);
    expect(s.isAuthenticated, isTrue);
    expect(s.role, AppRole.teacher);
    expect(s.firstName, 'Ada');
  });

  test('storage failure falls back to signed-out instead of hanging', () async {
    final storage = _MemoryStorage(throwOnRead: true);
    final s = await make(storage).read(sessionProvider.future);
    expect(s.isAuthenticated, isFalse);
    expect(storage.cleared, isTrue);
  });

  test('signedIn and signOut transition synchronously', () async {
    final storage = _MemoryStorage()..data['onboarding'] = 'true';
    final c = make(storage);
    await c.read(sessionProvider.future);

    c.read(sessionProvider.notifier).signedIn(
          const AppUser(id: 1, name: 'Sam', email: 's@x.io', backendRole: 'USER'),
        );
    expect(c.read(sessionProvider).requireValue.isAuthenticated, isTrue);
    expect(c.read(sessionProvider).requireValue.role, AppRole.student);

    await c.read(sessionProvider.notifier).signOut();
    final s = c.read(sessionProvider).requireValue;
    expect(s.isAuthenticated, isFalse);
    expect(s.onboardingSeen, isTrue, reason: 'logging out must not replay onboarding');
  });

  test('markOnboardingSeen persists and updates state', () async {
    final storage = _MemoryStorage();
    final c = make(storage);
    expect((await c.read(sessionProvider.future)).onboardingSeen, isFalse);
    await c.read(sessionProvider.notifier).markOnboardingSeen();
    expect(c.read(sessionProvider).requireValue.onboardingSeen, isTrue);
    expect(storage.data['onboarding'], 'true');
  });
}
