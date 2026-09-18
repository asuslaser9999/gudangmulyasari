import '../models/app_settings.dart';
import '../models/staff_access_mode.dart';

/// Evaluates whether warehouse staff may use the app based on owner settings.
class StaffAccessPolicy {
  StaffAccessPolicy._();

  static bool isFullyBlocked({
    required bool isOwner,
    required AppSettings settings,
  }) {
    if (isOwner) return false;
    return settings.staffAccessMode == StaffAccessMode.blocked;
  }

  static bool isMenuEnabled({
    required bool isOwner,
    required AppSettings settings,
    DateTime? now,
  }) {
    if (isOwner) return true;

    switch (settings.staffAccessMode) {
      case StaffAccessMode.fullAccess:
        return true;
      case StaffAccessMode.blocked:
        return false;
      case StaffAccessMode.timeRestricted:
        return isWithinAccessWindow(
          now ?? DateTime.now(),
          settings.staffAccessStart,
          settings.staffAccessEnd,
        );
    }
  }

  static bool isWithinAccessWindow(DateTime now, String start, String end) {
    final startMinutes = parseTimeToMinutes(start);
    final endMinutes = parseTimeToMinutes(end);
    final currentMinutes = now.hour * 60 + now.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }

    return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
  }

  static int parseTimeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  static String formatTime(String hhmm) => hhmm.replaceAll(':', '.');

  static String formatAccessWindow(String start, String end) {
    return '${formatTime(start)} – ${formatTime(end)}';
  }

  static String staffBadgeLabel({
    required String roleLabel,
    required AppSettings settings,
    required bool menuEnabled,
  }) {
    switch (settings.staffAccessMode) {
      case StaffAccessMode.fullAccess:
        return '$roleLabel · Akses penuh';
      case StaffAccessMode.blocked:
        return '$roleLabel · Akses diblokir';
      case StaffAccessMode.timeRestricted:
        if (menuEnabled) {
          return '$roleLabel · Jam operasional '
              '${formatAccessWindow(settings.staffAccessStart, settings.staffAccessEnd)}';
        }
        return '$roleLabel · Di luar jam operasional';
    }
  }

  static Duration? timeUntilNextBoundary({
    required AppSettings settings,
    DateTime? now,
  }) {
    if (settings.staffAccessMode != StaffAccessMode.timeRestricted) {
      return null;
    }

    final current = now ?? DateTime.now();
    final startMinutes = parseTimeToMinutes(settings.staffAccessStart);
    final endMinutes = parseTimeToMinutes(settings.staffAccessEnd);
    final currentMinutes = current.hour * 60 + current.minute;
    final currentSecondOffset = currentMinutes * 60 + current.second;

    final boundaries = <int>[startMinutes * 60, endMinutes * 60];
    if (startMinutes > endMinutes) {
      boundaries.add(24 * 60 * 60);
    }

    for (final boundary in boundaries) {
      if (boundary > currentSecondOffset) {
        return Duration(seconds: boundary - currentSecondOffset);
      }
    }

    final nextDayStart =
        (24 * 60 * 60) - currentSecondOffset + startMinutes * 60;
    return Duration(seconds: nextDayStart);
  }
}
