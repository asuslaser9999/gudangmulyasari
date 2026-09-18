import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_defaults.dart';
import '../theme/app_theme.dart';
import 'app_appearance.dart';
import 'hero_banner_fit.dart';
import 'staff_access_mode.dart';

class StoreIconOption {
  const StoreIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}

class AvatarColorOption {
  const AvatarColorOption({
    required this.key,
    required this.color,
    required this.label,
  });

  final String key;
  final Color color;
  final String label;
}

class AppSettings {
  const AppSettings({
    this.storeName = AppDefaults.storeName,
    this.storeSubtitle = AppDefaults.storeSubtitle,
    this.storeIconKey = 'food_bank',
    this.avatarColorKey = 'orange',
    this.showSubtitleOnDashboard = true,
    this.appearance = AppAppearance.pos,
    this.staffAccessMode = StaffAccessMode.timeRestricted,
    this.staffAccessStart = '05:30',
    this.staffAccessEnd = '16:30',
    this.heroBannerPath,
    this.heroBannerVersion = 0,
    this.heroBannerFit = HeroBannerFit.cover,
  });

  final String storeName;
  final String storeSubtitle;
  final String storeIconKey;
  final String avatarColorKey;
  final bool showSubtitleOnDashboard;
  final AppAppearance appearance;
  final StaffAccessMode staffAccessMode;
  final String staffAccessStart;
  final String staffAccessEnd;
  final String? heroBannerPath;
  final int heroBannerVersion;
  final HeroBannerFit heroBannerFit;

  static const defaults = AppSettings();

  IconData get storeIcon => StoreIconRegistry.resolve(storeIconKey);

  Color get avatarColor => AvatarColorRegistry.resolve(avatarColorKey);

  bool get hasHeroBanner {
    final path = heroBannerPath?.trim();
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  AppSettings copyWith({
    String? storeName,
    String? storeSubtitle,
    String? storeIconKey,
    String? avatarColorKey,
    bool? showSubtitleOnDashboard,
    AppAppearance? appearance,
    StaffAccessMode? staffAccessMode,
    String? staffAccessStart,
    String? staffAccessEnd,
    String? heroBannerPath,
    int? heroBannerVersion,
    HeroBannerFit? heroBannerFit,
    bool clearHeroBanner = false,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      storeSubtitle: storeSubtitle ?? this.storeSubtitle,
      storeIconKey: storeIconKey ?? this.storeIconKey,
      avatarColorKey: avatarColorKey ?? this.avatarColorKey,
      showSubtitleOnDashboard:
          showSubtitleOnDashboard ?? this.showSubtitleOnDashboard,
      appearance: appearance ?? this.appearance,
      staffAccessMode: staffAccessMode ?? this.staffAccessMode,
      staffAccessStart: staffAccessStart ?? this.staffAccessStart,
      staffAccessEnd: staffAccessEnd ?? this.staffAccessEnd,
      heroBannerPath: clearHeroBanner
          ? null
          : (heroBannerPath ?? this.heroBannerPath),
      heroBannerVersion: heroBannerVersion ?? this.heroBannerVersion,
      heroBannerFit: heroBannerFit ?? this.heroBannerFit,
    );
  }
}

class StoreIconRegistry {
  StoreIconRegistry._();

  static const options = <StoreIconOption>[
    StoreIconOption(
      key: 'food_bank',
      icon: Icons.food_bank_rounded,
      label: 'Gudang',
    ),
    StoreIconOption(
      key: 'warehouse',
      icon: Icons.warehouse_rounded,
      label: 'Warehouse',
    ),
    StoreIconOption(
      key: 'storefront',
      icon: Icons.storefront_rounded,
      label: 'Toko',
    ),
    StoreIconOption(key: 'cafe', icon: Icons.local_cafe_rounded, label: 'Kafe'),
    StoreIconOption(
      key: 'restaurant',
      icon: Icons.restaurant_rounded,
      label: 'Dapur',
    ),
    StoreIconOption(key: 'domain', icon: Icons.domain_rounded, label: 'Bisnis'),
  ];

  static IconData resolve(String? key) {
    for (final option in options) {
      if (option.key == key) return option.icon;
    }
    return options.first.icon;
  }
}

class AvatarColorRegistry {
  AvatarColorRegistry._();

  static const options = <AvatarColorOption>[
    AvatarColorOption(
      key: 'orange',
      color: AppColors.accentOrange,
      label: 'Oranye',
    ),
    AvatarColorOption(key: 'blue', color: AppColors.accentBlue, label: 'Biru'),
    AvatarColorOption(
      key: 'purple',
      color: AppColors.accentPurple,
      label: 'Ungu',
    ),
    AvatarColorOption(
      key: 'green',
      color: AppColors.accentGreen,
      label: 'Hijau',
    ),
    AvatarColorOption(key: 'pink', color: AppColors.accentPink, label: 'Pink'),
    AvatarColorOption(key: 'teal', color: AppColors.accentTeal, label: 'Teal'),
  ];

  static Color resolve(String? key) {
    for (final option in options) {
      if (option.key == key) return option.color;
    }
    return options.first.color;
  }
}
