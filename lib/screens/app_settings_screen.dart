import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/staff_access_policy.dart';
import '../models/app_appearance.dart';
import '../models/app_settings.dart';
import '../models/staff_access_mode.dart';
import '../notifiers/app_settings_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/store_branding_header.dart';
import '../widgets/theme_preview_card.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _subtitle;
  late AppSettings _draft = AppSettings.defaults;
  var _didApplyDraft = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _subtitle = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyDraft(context.read<AppSettingsNotifier>().settings);
    });
  }

  void _applyDraft(AppSettings settings) {
    setState(() {
      _draft = settings;
      _name.text = settings.storeName;
      _subtitle.text = settings.storeSubtitle;
      _didApplyDraft = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickAccessTime({required bool isStart}) async {
    final initial = _parseTime(
      isStart ? _draft.staffAccessStart : _draft.staffAccessEnd,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Jam mulai akses staf' : 'Jam akhir akses staf',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _draft = _draft.copyWith(
        staffAccessStart: isStart ? _formatTime(picked) : null,
        staffAccessEnd: isStart ? null : _formatTime(picked),
      );
    });
  }

  Future<void> _selectAppearance(AppAppearance appearance) async {
    setState(() {
      _draft = _draft.copyWith(appearance: appearance);
    });
    await context.read<AppSettingsNotifier>().updateAppearance(appearance);
  }

  Future<void> _save() async {
    final current = context.read<AppSettingsNotifier>().settings;
    final isOwner = context.read<AuthNotifier>().isOwner;
    final notifier = context.read<AppSettingsNotifier>();
    notifier.clearError();
    var toSave = _draft.copyWith(appearance: current.appearance);
    if (!isOwner) {
      toSave = toSave.copyWith(
        staffAccessMode: current.staffAccessMode,
        staffAccessStart: current.staffAccessStart,
        staffAccessEnd: current.staffAccessEnd,
      );
    }
    final ok = await notifier.save(toSave, syncAccess: isOwner);
    if (!mounted) return;
    final message = !ok
        ? (notifier.errorMessage ?? 'Gagal menyimpan.')
        : (notifier.errorMessage != null
              ? 'Pengaturan disimpan di perangkat ini. ${notifier.errorMessage}'
              : (isOwner
                    ? 'Pengaturan berhasil disimpan dan disinkronkan.'
                    : 'Pengaturan berhasil disimpan.'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppSettingsNotifier>();
    final auth = context.watch<AuthNotifier>();
    if (!_didApplyDraft && notifier.settings != AppSettings.defaults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didApplyDraft) return;
        _applyDraft(notifier.settings);
      });
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tema Aplikasi',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Gelap, terang ala apple.com, atau kasir gelap hangat '
            'dengan palet navy–terracotta. Tersimpan di perangkat ini.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (index, appearance)
                  in AppAppearance.values.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: ThemePreviewCard(
                    appearance: appearance,
                    selected: notifier.settings.appearance == appearance,
                    onTap: () => _selectAppearance(appearance),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StoreBrandingHeader(
                settings: _draft,
                showSubtitle: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nama gudang',
              helperText: 'Dipakai di login dan menu utama.',
            ),
            onChanged: (value) {
              setState(() {
                _draft = _draft.copyWith(storeName: value);
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(
              labelText: 'Subtitle / Tagline',
              helperText: 'Contoh: Inventori Gudang',
            ),
            onChanged: (value) {
              setState(() {
                _draft = _draft.copyWith(storeSubtitle: value);
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan subtitle di menu utama'),
            subtitle: const Text('Subtitle selalu tampil di halaman login.'),
            value: _draft.showSubtitleOnDashboard,
            onChanged: (value) {
              setState(() {
                _draft = _draft.copyWith(showSubtitleOnDashboard: value);
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Icon',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: StoreIconRegistry.options.length,
            itemBuilder: (context, index) {
              final option = StoreIconRegistry.options[index];
              final selected = _draft.storeIconKey == option.key;
              return Material(
                color: selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _draft = _draft.copyWith(storeIconKey: option.key);
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option.icon,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Warna Icon',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in AvatarColorRegistry.options)
                Semantics(
                  label: option.label,
                  button: true,
                  selected: _draft.avatarColorKey == option.key,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        _draft = _draft.copyWith(avatarColorKey: option.key);
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: option.color,
                        border: Border.all(
                          color: _draft.avatarColorKey == option.key
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _draft.avatarColorKey == option.key
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          if (auth.isOwner) ...[
            const SizedBox(height: 24),
            Text(
              'Akses Staf',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Atur kapan staf dapat menggunakan menu utama. '
              'Owner selalu memiliki akses penuh.\n\n'
              'Pengaturan akses staf disinkronkan ke semua perangkat '
              'via server saat Anda simpan. Perangkat staf akan '
              'memperbarui otomatis saat login atau app dibuka kembali.\n\n'
              'Branding (nama, ikon, tema) tetap per perangkat.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<StaffAccessMode>(
              groupValue: _draft.staffAccessMode,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _draft = _draft.copyWith(staffAccessMode: value);
                });
              },
              child: Column(
                children: [
                  for (final mode in StaffAccessMode.values)
                    RadioListTile<StaffAccessMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(mode.label),
                      subtitle: switch (mode) {
                        StaffAccessMode.fullAccess => const Text(
                          'Staf dapat menggunakan aplikasi kapan saja.',
                        ),
                        StaffAccessMode.timeRestricted => Text(
                          'Staf hanya aktif pukul '
                          '${StaffAccessPolicy.formatAccessWindow(_draft.staffAccessStart, _draft.staffAccessEnd)}. '
                          'Di luar jam itu bisa login tetapi menu dinonaktifkan.',
                        ),
                        StaffAccessMode.blocked => const Text(
                          'Staf tidak dapat menggunakan aplikasi sama sekali.',
                        ),
                      },
                      value: mode,
                    ),
                ],
              ),
            ),
            if (_draft.staffAccessMode == StaffAccessMode.timeRestricted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAccessTime(isStart: true),
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        'Mulai ${StaffAccessPolicy.formatTime(_draft.staffAccessStart)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickAccessTime(isStart: false),
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        'Selesai ${StaffAccessPolicy.formatTime(_draft.staffAccessEnd)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: notifier.isSaving ? null : _save,
            child: Text(notifier.isSaving ? 'Menyimpan...' : 'Simpan'),
          ),
          if (notifier.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              notifier.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
