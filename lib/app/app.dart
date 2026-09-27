import 'package:flutter/material.dart';

import '../core/auth/mobile_auth_client.dart';
import '../core/session/session_store.dart';
import 'bootstrap/bootstrap_flow.dart';
import 'theme/app_theme.dart';

class McpFieldApp extends StatelessWidget {
  const McpFieldApp({
    super.key,
    this.authClient,
    this.sessionStore,
  });

  final MobileAuthClient? authClient;
  final SessionStore? sessionStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Field',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: BootstrapFlow(
        authClient: authClient ?? HttpMobileAuthClient(),
        sessionStore: sessionStore ?? SecureSessionStore(),
      ),
    );
  }
}
