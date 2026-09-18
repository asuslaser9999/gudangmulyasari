import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/staff_access_policy.dart';
import '../models/app_settings.dart';
import '../notifiers/app_settings_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/auth_actions.dart';
import '../widgets/dark_background.dart';
import '../widgets/store_branding_header.dart';

/// Shown when staff access mode is fully blocked.
class StaffBlockedScreen extends StatelessWidget {
  const StaffBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettingsNotifier>().settings;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => AuthActions.confirmAndSignOut(context),
          ),
        ],
      ),
      body: DarkBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                StoreBrandingHeader(
                  settings: appSettings,
                  showSubtitle: appSettings.showSubtitleOnDashboard,
                ),
                const Spacer(),
                Icon(
                  Icons.lock_clock_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  'Akses Staf Diblokir',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aplikasi tidak dapat digunakan oleh staf saat ini. '
                  'Hubungi owner untuk mengubah pengaturan akses.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => AuthActions.confirmAndSignOut(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner on dashboard when staff is outside allowed hours.
class StaffAccessBanner extends StatelessWidget {
  const StaffAccessBanner({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final window = StaffAccessPolicy.formatAccessWindow(
      settings.staffAccessStart,
      settings.staffAccessEnd,
    );

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.schedule_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Di luar jam operasional',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Menu utama dinonaktifkan. Staf hanya dapat mengakses '
                    'aplikasi pukul $window.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
