import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp_field/app/app.dart';
import 'package:mcp_field/app/navigation/app_shell.dart';
import 'package:mcp_field/core/auth/mobile_auth_client.dart';
import 'package:mcp_field/core/installation/installation_profile.dart';
import 'package:mcp_field/core/installation/system_endpoint_probe.dart';
import 'package:mcp_field/core/session/session_store.dart';

final testProfile = InstallationProfile(
  name: 'Hưng Phát',
  baseUrl: Uri.parse('https://mcp.example.vn'),
);

final testSession = MobileSession(
  token: 'nppusr.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.tokenvalue',
  employeeId: '11111111-1111-4111-8111-111111111111',
  loginName: 'staff.test',
  displayName: 'Nguyễn Văn A',
  expiresAt: DateTime.utc(2026, 9, 28),
  permissions: const ['mcp.session.write'],
);

class FakeSystemEndpointProbe implements SystemEndpointProbe {
  @override
  Future<void> verify(Uri baseUrl) async {}
}

class MemorySessionStore implements SessionStore {
  InstallationProfile? profile;
  String? token;

  @override
  Future<void> clearAll() async {
    profile = null;
    token = null;
  }

  @override
  Future<void> clearSession({bool keepProfile = true}) async {
    token = null;
    if (!keepProfile) profile = null;
  }

  @override
  Future<InstallationProfile?> readProfile() async => profile;

  @override
  Future<String?> readToken(InstallationProfile profile) async {
    return this.profile?.installationKey == profile.installationKey
        ? token
        : null;
  }

  @override
  Future<void> saveProfile(InstallationProfile profile) async {
    if (this.profile?.installationKey != profile.installationKey) {
      token = null;
    }
    this.profile = profile;
  }

  @override
  Future<void> saveSession(
    InstallationProfile profile,
    String token,
  ) async {
    this.profile = profile;
    this.token = token;
  }
}

class FakeAuthClient implements MobileAuthClient {
  MobileSession session = testSession;
  AuthFailure? nextLoginFailure;
  AuthFailure? meFailure;
  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<MobileSession> login({
    required InstallationProfile profile,
    required String loginName,
    required String password,
    String ownerCode = '',
  }) async {
    loginCalls += 1;
    final failure = nextLoginFailure;
    nextLoginFailure = null;
    if (failure != null) throw failure;
    return session;
  }

  @override
  Future<void> logout({
    required InstallationProfile profile,
    required String token,
  }) async {
    logoutCalls += 1;
  }

  @override
  Future<MobileSession> me({
    required InstallationProfile profile,
    required String token,
  }) async {
    final failure = meFailure;
    if (failure != null) throw failure;
    return session;
  }
}

Finder navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> openLogin(
  WidgetTester tester,
  FakeAuthClient auth,
  MemorySessionStore store,
) async {
  await tester.pumpWidget(
    McpFieldApp(
      authClient: auth,
      sessionStore: store,
      endpointProbe: FakeSystemEndpointProbe(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('system-name-field')),
    'Hưng Phát',
  );
  await tester.enterText(
    find.byKey(const Key('system-url-field')),
    'https://mcp.example.vn',
  );
  await tester.tap(find.byKey(const Key('system-continue-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app starts with system selection', (
    WidgetTester tester,
  ) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(
      McpFieldApp(
        authClient: FakeAuthClient(),
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('system-setup-screen')), findsOneWidget);
    expect(find.text('Chọn hệ thống'), findsOneWidget);
  });

  testWidgets('valid system profile opens login screen', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthClient();
    final store = MemorySessionStore();
    await openLogin(tester, auth, store);

    expect(find.byKey(const Key('login-screen')), findsOneWidget);
    expect(find.text('Hưng Phát'), findsWidgets);
    expect(find.text('mcp.example.vn'), findsOneWidget);
    expect(store.profile?.installationKey, testProfile.installationKey);
  });

  testWidgets('invalid system address stays on setup', (
    WidgetTester tester,
  ) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(
      McpFieldApp(
        authClient: FakeAuthClient(),
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('system-name-field')),
      'Hưng Phát',
    );
    await tester.enterText(
      find.byKey(const Key('system-url-field')),
      'http://public-insecure.example.vn',
    );
    await tester.tap(find.byKey(const Key('system-continue-button')));
    await tester.pump();

    expect(find.byKey(const Key('system-setup-screen')), findsOneWidget);
    expect(find.text('Địa chỉ máy chủ chưa hợp lệ'), findsOneWidget);
  });

  testWidgets('successful login stores the session and opens today', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthClient();
    final store = MemorySessionStore();
    await openLogin(tester, auth, store);

    await tester.enterText(
      find.byKey(const Key('login-user-field')),
      'staff.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'password-value',
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-screen')), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(store.token, testSession.token);
  });

  testWidgets('owner challenge reveals verification code field', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthClient()
      ..nextLoginFailure = const AuthFailure(
        code: 'INTERNAL_AUTH_OWNER_CHALLENGE_REQUIRED',
        message: 'Nhập mã xác nhận đã gửi để tiếp tục.',
      );
    final store = MemorySessionStore();
    await openLogin(tester, auth, store);

    await tester.enterText(
      find.byKey(const Key('login-user-field')),
      'owner.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'password-value',
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-owner-code-field')), findsOneWidget);
    expect(find.text('Xác nhận'), findsOneWidget);
  });

  testWidgets('saved valid session restores directly to the business shell', (
    WidgetTester tester,
  ) async {
    final store = MemorySessionStore()
      ..profile = testProfile
      ..token = testSession.token;

    await tester.pumpWidget(
      McpFieldApp(
        authClient: FakeAuthClient(),
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-screen')), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
  });

  testWidgets('expired saved session returns to login and clears token', (
    WidgetTester tester,
  ) async {
    final store = MemorySessionStore()
      ..profile = testProfile
      ..token = testSession.token;
    final auth = FakeAuthClient()
      ..meFailure = const AuthFailure(
        code: 'INTERNAL_AUTH_SESSION_EXPIRED',
        message: 'Phiên đăng nhập không còn hiệu lực.',
      );

    await tester.pumpWidget(
      McpFieldApp(
        authClient: auth,
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-screen')), findsOneWidget);
    expect(store.token, isNull);
  });

  testWidgets('logout clears local session and returns to login', (
    WidgetTester tester,
  ) async {
    final store = MemorySessionStore()
      ..profile = testProfile
      ..token = testSession.token;
    final auth = FakeAuthClient();

    await tester.pumpWidget(
      McpFieldApp(
        authClient: auth,
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Thêm'));
    await tester.pumpAndSettle();

    final moreList = find.descendant(
      of: find.byKey(const Key('more-screen')),
      matching: find.byType(ListView),
    );
    await tester.drag(moreList, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-screen')), findsOneWidget);
    expect(store.token, isNull);
    expect(auth.logoutCalls, 1);
  });

  testWidgets('business shell keeps five primary destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(session: testSession),
      ),
    );

    expect(find.byKey(const Key('today-screen')), findsOneWidget);
    expect(navLabel('Hôm nay'), findsOneWidget);
    expect(navLabel('Đi tuyến'), findsOneWidget);
    expect(navLabel('Điểm bán'), findsOneWidget);
    expect(navLabel('Đơn hàng'), findsOneWidget);
    expect(navLabel('Thêm'), findsOneWidget);
  });

  testWidgets('today primary action opens route screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(session: testSession),
      ),
    );

    await tester.tap(find.byKey(const Key('today-open-routes-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routes-screen')), findsOneWidget);
  });

  testWidgets('today next outlet action stays in route context', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(session: testSession),
      ),
    );

    final outletAction = find.byKey(
      const Key('today-next-outlet-button'),
    );
    await tester.ensureVisible(outletAction);
    await tester.tap(outletAction);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routes-screen')), findsOneWidget);
  });
}
