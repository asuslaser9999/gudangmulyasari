import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_defaults.dart';
import '../models/app_appearance.dart';
import '../models/app_settings.dart';
import '../models/hero_banner_fit.dart';
import '../models/staff_access_mode.dart';

class AppSettingsService {
  static const _storeNameKey = 'gm_app_store_name';
  static const _storeSubtitleKey = 'gm_app_store_subtitle';
  static const _storeIconKey = 'gm_app_store_icon';
  static const _avatarColorKey = 'gm_app_avatar_color';
  static const _showSubtitleKey = 'gm_app_show_subtitle_dashboard';
  static const _appearanceKey = 'gm_app_theme_mode';
  static const _heroBannerPathKey = 'gm_hero_banner_path';
  static const _heroBannerVersionKey = 'gm_hero_banner_version';
  static const _heroBannerFitKey = 'gm_hero_banner_fit';
  static const _staffAccessModeKey = 'gm_staff_access_mode';
  static const _staffAccessStartKey = 'gm_staff_access_start';
  static const _staffAccessEndKey = 'gm_staff_access_end';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString(_storeNameKey)?.trim();
    final storeName = (storedName == null ||
            storedName.isEmpty ||
            storedName == 'Gudang Mulyasari')
        ? AppDefaults.storeName
        : storedName;
    return AppSettings(
      storeName: storeName,
      storeSubtitle:
          prefs.getString(_storeSubtitleKey) ?? AppDefaults.storeSubtitle,
      storeIconKey:
          prefs.getString(_storeIconKey) ?? AppSettings.defaults.storeIconKey,
      avatarColorKey:
          prefs.getString(_avatarColorKey) ??
          AppSettings.defaults.avatarColorKey,
      showSubtitleOnDashboard:
          prefs.getBool(_showSubtitleKey) ??
          AppSettings.defaults.showSubtitleOnDashboard,
      appearance: AppAppearance.fromStorageKey(prefs.getString(_appearanceKey)),
      staffAccessMode: StaffAccessMode.fromStorageKey(
        prefs.getString(_staffAccessModeKey),
      ),
      staffAccessStart:
          prefs.getString(_staffAccessStartKey) ??
          AppSettings.defaults.staffAccessStart,
      staffAccessEnd:
          prefs.getString(_staffAccessEndKey) ??
          AppSettings.defaults.staffAccessEnd,
      heroBannerPath: prefs.getString(_heroBannerPathKey),
      heroBannerVersion: prefs.getInt(_heroBannerVersionKey) ?? 0,
      heroBannerFit: HeroBannerFit.fromStorageKey(
        prefs.getString(_heroBannerFitKey),
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeNameKey, settings.storeName.trim());
    await prefs.setString(_storeSubtitleKey, settings.storeSubtitle.trim());
    await prefs.setString(_storeIconKey, settings.storeIconKey);
    await prefs.setString(_avatarColorKey, settings.avatarColorKey);
    await prefs.setBool(_showSubtitleKey, settings.showSubtitleOnDashboard);
    await prefs.setString(_appearanceKey, settings.appearance.storageKey);
    await prefs.setString(
      _staffAccessModeKey,
      settings.staffAccessMode.storageKey,
    );
    await prefs.setString(_staffAccessStartKey, settings.staffAccessStart);
    await prefs.setString(_staffAccessEndKey, settings.staffAccessEnd);
    final bannerPath = settings.heroBannerPath?.trim();
    if (bannerPath == null || bannerPath.isEmpty) {
      await prefs.remove(_heroBannerPathKey);
    } else {
      await prefs.setString(_heroBannerPathKey, bannerPath);
    }
    await prefs.setInt(_heroBannerVersionKey, settings.heroBannerVersion);
    await prefs.setString(_heroBannerFitKey, settings.heroBannerFit.storageKey);
  }
}
