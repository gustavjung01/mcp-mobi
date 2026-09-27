import 'package:flutter/material.dart';

import 'bootstrap/bootstrap_flow.dart';
import 'theme/app_theme.dart';

class McpFieldApp extends StatelessWidget {
  const McpFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Field',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const BootstrapFlow(),
    );
  }
}
