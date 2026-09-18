import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../notifiers/auth_notifier.dart';
import 'store_branding_header.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.settings,
    required this.auth,
    required this.onAppSettings,
    required this.onSignOut,
  });

  final AppSettings settings;
  final AuthNotifier auth;
  final VoidCallback onAppSettings;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.scaleDown,
                        child: StoreBrandingHeader(
                          settings: settings,
                          avatarSize: 48,
                          iconSize: 24,
                          nameFontSize: 16,
                          showSubtitle: false,
                          center: false,
                        ),
                      ),
                    ),
                  ),
                  Chip(label: Text(auth.roleLabel)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Pengaturan Aplikasi'),
                    onTap: onAppSettings,
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Keluar', style: theme.textTheme.bodyLarge),
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}
