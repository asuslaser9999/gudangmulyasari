import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_defaults.dart';
import '../domain/staff_access_policy.dart';
import '../models/app_settings.dart';
import '../models/staff_access_mode.dart';
import '../notifiers/app_settings_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/auth_actions.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/dark_background.dart';
import '../widgets/dashboard_menu_section.dart';
import '../widgets/store_branding_header.dart';
import '../widgets/store_hero_banner.dart';
import 'app_settings_screen.dart';
import 'item_list_screen.dart';
import 'location_list_screen.dart';
import 'receipt_recap_screen.dart';
import 'role_permission_screen.dart';
import 'stock_doc_form_screen.dart';
import 'stock_list_screen.dart';
import 'receipt_screen.dart';
import 'staff_access_screen.dart';
import 'transfer_recap_screen.dart';
import 'user_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _accessTimer;
  StaffAccessMode? _scheduledMode;
  String? _scheduledStart;
  String? _scheduledEnd;

  @override
  void dispose() {
    _accessTimer?.cancel();
    super.dispose();
  }

  void _maybeScheduleAccessRefresh(AppSettings settings) {
    if (_scheduledMode == settings.staffAccessMode &&
        _scheduledStart == settings.staffAccessStart &&
        _scheduledEnd == settings.staffAccessEnd &&
        _accessTimer != null) {
      return;
    }

    _scheduledMode = settings.staffAccessMode;
    _scheduledStart = settings.staffAccessStart;
    _scheduledEnd = settings.staffAccessEnd;
    _scheduleAccessRefresh(settings);
  }

  void _scheduleAccessRefresh(AppSettings settings) {
    _accessTimer?.cancel();
    final delay = StaffAccessPolicy.timeUntilNextBoundary(settings: settings);
    if (delay == null) return;

    _accessTimer = Timer(delay + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
      _scheduleAccessRefresh(settings);
    });
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final appSettings = context.watch<AppSettingsNotifier>().settings;
    final menuEnabled = StaffAccessPolicy.isMenuEnabled(
      isOwner: auth.isOwner,
      settings: appSettings,
    );
    final showOutsideHoursBanner =
        !auth.isOwner &&
        appSettings.staffAccessMode == StaffAccessMode.timeRestricted &&
        !menuEnabled;

    _maybeScheduleAccessRefresh(appSettings);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: AppNavigationDrawer(
        settings: appSettings,
        auth: auth,
        onAppSettings: () => _push(context, const AppSettingsScreen()),
        onSignOut: () => AuthActions.confirmAndSignOut(context),
      ),
      appBar: AppBar(
        title: Text(
          appSettings.storeName.trim().isEmpty
              ? AppDefaults.storeName
              : appSettings.storeName.trim(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: false,
      ),
      body: DarkBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (appSettings.hasHeroBanner)
                        ClipRRect(
                          borderRadius: AppShapes.borderMedium,
                          child: StoreHeroBanner(settings: appSettings),
                        )
                      else
                        StoreBrandingHeader(
                          settings: appSettings,
                          showSubtitle: appSettings.showSubtitleOnDashboard,
                        ),
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppShapes.full),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                auth.isOwner
                                    ? Icons.admin_panel_settings_outlined
                                    : Icons.person_outline,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                auth.isOwner
                                    ? 'Owner · Akses penuh'
                                    : StaffAccessPolicy.staffBadgeLabel(
                                        roleLabel: auth.roleLabel,
                                        settings: appSettings,
                                        menuEnabled: menuEnabled,
                                      ),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showOutsideHoursBanner) ...[
                        const SizedBox(height: 16),
                        StaffAccessBanner(settings: appSettings),
                      ],
                      const SizedBox(height: 28),
                      if (auth.canViewStock ||
                          auth.canReceipt ||
                          auth.canTransfer) ...[
                        DashboardMenuSection(
                          title: 'Stok',
                          subtitle: 'Gudang dan dapur (tempat produksi)',
                          children: [
                            if (auth.canViewStock)
                              DashboardMenuRow(
                                icon: Icons.inventory_2_outlined,
                                label: 'Cek stok',
                                subtitle: 'Qty per gudang dan dapur',
                                color: AppColors.accentBlue,
                                enabled: menuEnabled,
                                onTap: () =>
                                    _push(context, const StockListScreen()),
                              ),
                            if (auth.canReceipt)
                              DashboardMenuRow(
                                icon: Icons.move_to_inbox_outlined,
                                label: 'Barang datang',
                                subtitle: 'Masuk ke gudang atau dapur',
                                color: AppColors.accentGreen,
                                enabled: menuEnabled,
                                onTap: () =>
                                    _push(context, const ReceiptScreen()),
                              ),
                            if (auth.canViewStock || auth.canReceipt)
                              DashboardMenuRow(
                                icon: Icons.playlist_add_check_outlined,
                                label: 'Rekap barang datang',
                                subtitle:
                                    'Riwayat input, termasuk siapa yang mengisi',
                                color: AppColors.accentGreen,
                                enabled: menuEnabled,
                                onTap: () =>
                                    _push(context, const ReceiptRecapScreen()),
                              ),
                            if (auth.canTransfer)
                              DashboardMenuRow(
                                icon: Icons.swap_horiz_rounded,
                                label: 'Pengambilan',
                                subtitle: 'Dari gudang ke dapur',
                                color: AppColors.accentOrange,
                                enabled: menuEnabled,
                                onTap: () => _push(
                                  context,
                                  const StockDocFormScreen(docType: 'transfer'),
                                ),
                              ),
                            if (auth.canViewStock)
                              DashboardMenuRow(
                                icon: Icons.receipt_long_outlined,
                                label: 'Rekap pengambilan',
                                subtitle: 'Riwayat pindah ke dapur',
                                color: AppColors.accentTeal,
                                enabled: menuEnabled,
                                onTap: () => _push(
                                  context,
                                  const TransferRecapScreen(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (auth.canManageItems || auth.canManageLocations)
                        DashboardMenuSection(
                          title: 'Master data',
                          children: [
                            if (auth.canManageItems)
                              DashboardMenuRow(
                                icon: Icons.inventory_outlined,
                                label: 'Master barang',
                                color: AppColors.accentPurple,
                                enabled: menuEnabled,
                                onTap: () =>
                                    _push(context, const ItemListScreen()),
                              ),
                            if (auth.canManageLocations)
                              DashboardMenuRow(
                                icon: Icons.warehouse_outlined,
                                label: 'Gudang & dapur',
                                subtitle: 'Tambah tempat stok / produksi',
                                color: AppColors.accentPink,
                                enabled: menuEnabled,
                                onTap: () =>
                                    _push(context, const LocationListScreen()),
                              ),
                          ],
                        ),
                      if (auth.canManageUsers || auth.canManageRoles) ...[
                        const SizedBox(height: 22),
                        DashboardMenuSection(
                          title: 'Pengguna',
                          subtitle: 'Role, lokasi stok, dan hak akses',
                          children: [
                            if (auth.canManageUsers)
                              DashboardMenuRow(
                                icon: Icons.people_outline,
                                label: 'Kelola user',
                                subtitle:
                                    'Akun, role, dan stok yang bisa dilihat',
                                color: AppColors.accentIndigo,
                                enabled: menuEnabled,
                                onTap: () => _push(
                                  context,
                                  const UserManagementScreen(),
                                ),
                              ),
                            if (auth.canManageRoles)
                              DashboardMenuRow(
                                icon: Icons.verified_user_outlined,
                                label: 'Hak akses role',
                                subtitle:
                                    'Barang datang, pengambilan, master, hapus',
                                color: AppColors.accentRed,
                                enabled: menuEnabled,
                                onTap: () => _push(
                                  context,
                                  const RolePermissionScreen(),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Builder(
                        builder: (ctx) => Center(
                          child: TextButton.icon(
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            label: const Text('Pengaturan & akun'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
