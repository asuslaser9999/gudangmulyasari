import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DashboardMenuSection extends StatelessWidget {
  const DashboardMenuSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Material(
          color: scheme.surfaceContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppShapes.borderMedium,
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardMenuRow extends StatelessWidget {
  const DashboardMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = enabled ? color : AppColors.textMuted;

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: AppShapes.borderSmall,
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveColor.withValues(alpha: 0.28),
                    effectiveColor.withValues(alpha: 0.12),
                  ],
                )
              : null,
          color: enabled ? null : effectiveColor.withValues(alpha: 0.08),
        ),
        child: Icon(icon, color: effectiveColor, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enabled ? scheme.onSurface : AppColors.textMuted,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: enabled
                    ? scheme.onSurfaceVariant
                    : AppColors.textMuted,
              ),
            ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: enabled ? scheme.onSurfaceVariant : AppColors.textMuted,
      ),
    );
  }
}
