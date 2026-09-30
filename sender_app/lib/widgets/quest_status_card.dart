import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A compact status indicator card used on the Home tab.
/// API is unchanged — existing callers work without modification.
class QuestStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String statusText;
  final bool isConnected;
  final Color accentColor;

  const QuestStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.statusText,
    this.isConnected = true,
    this.accentColor = WinzoColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: WinzoDimens.spaceSM, vertical: WinzoDimens.spaceMD),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
        border: Border.all(
          color: isConnected
              ? accentColor.withAlpha(65)
              : WinzoColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          if (isConnected)
            BoxShadow(
              color: accentColor.withAlpha(22),
              blurRadius: 14,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(25),
              borderRadius: BorderRadius.circular(WinzoDimens.radiusXS),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isConnected ? accentColor : WinzoColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),

          // Label
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: WinzoColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),

          // Status dot + value
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? WinzoColors.success
                      : WinzoColors.error,
                  boxShadow: isConnected
                      ? [
                          const BoxShadow(
                            color: WinzoColors.success,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isConnected
                        ? WinzoColors.textPrimary
                        : WinzoColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
