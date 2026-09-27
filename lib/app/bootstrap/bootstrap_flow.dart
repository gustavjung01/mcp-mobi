import 'package:flutter/material.dart';

import '../../core/installation/installation_profile.dart';
import '../../features/auth/login_page.dart';
import '../../features/bootstrap/system_setup_page.dart';

class BootstrapFlow extends StatefulWidget {
  const BootstrapFlow({super.key});

  @override
  State<BootstrapFlow> createState() => _BootstrapFlowState();
}

class _BootstrapFlowState extends State<BootstrapFlow> {
  InstallationProfile? _profile;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    if (profile == null) {
      return SystemSetupPage(
        onContinue: (value) {
          setState(() {
            _profile = value;
          });
        },
      );
    }

    return LoginPage(
      profile: profile,
      onChangeSystem: () {
        setState(() {
          _profile = null;
        });
      },
    );
  }
}
