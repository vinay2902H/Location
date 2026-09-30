import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Network & server configuration dialog.
/// Business logic is completely unchanged — only the visual layer is updated.
class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _intervalController;
  late int _selectedSeconds;

  final List<int> _presetIntervals = [3, 5, 10, 30, 60, 300];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConfig.baseUrl);
    _selectedSeconds = AppConfig.updateIntervalSeconds;
    _intervalController =
        TextEditingController(text: _selectedSeconds.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  String _formatInterval(int sec) {
    if (sec == 10) return '10s ★';
    if (sec < 60) return '${sec}s';
    final mins = (sec / 60).round();
    return '$mins min${mins > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WinzoColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        side: BorderSide(
            color: WinzoColors.primary.withAlpha(80), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WinzoDimens.spaceXL),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: WinzoColors.primary.withAlpha(35),
                      borderRadius:
                          BorderRadius.circular(WinzoDimens.radiusSM),
                      border: Border.all(
                          color: WinzoColors.primary.withAlpha(100)),
                    ),
                    child: const Icon(Icons.settings_input_antenna_rounded,
                        color: WinzoColors.accentAlt, size: 20),
                  ),
                  const SizedBox(width: WinzoDimens.spaceSM),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Link Settings',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: WinzoColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Configure server & update pulse',
                          style: TextStyle(
                              fontSize: 11,
                              color: WinzoColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WinzoDimens.spaceXL),

              // ── URL Field ─────────────────────────────────────────────────
              const Text(
                'BACKEND SERVER URL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: WinzoColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                style: const TextStyle(
                    color: WinzoColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: WinzoColors.bgElevated,
                  prefixIcon: const Icon(Icons.link_rounded,
                      color: WinzoColors.textMuted, size: 18),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(WinzoDimens.radiusSM),
                    borderSide: const BorderSide(
                        color: WinzoColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(WinzoDimens.radiusSM),
                    borderSide: const BorderSide(
                        color: WinzoColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(WinzoDimens.radiusSM),
                    borderSide: const BorderSide(
                        color: WinzoColors.primary, width: 1.5),
                  ),
                  hintText: 'https://your-backend.onrender.com',
                  hintStyle:
                      const TextStyle(color: WinzoColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: WinzoDimens.spaceLG),

              // ── Interval Selector ─────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'UPDATE INTERVAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: WinzoColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: WinzoColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(
                          WinzoDimens.radiusFull),
                      border: Border.all(
                          color: WinzoColors.primary.withAlpha(80)),
                    ),
                    child: Text(
                      _formatInterval(_selectedSeconds),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: WinzoColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _presetIntervals.map((sec) {
                  final isSelected = _selectedSeconds == sec;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSeconds = sec;
                        _intervalController.text = sec.toString();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? WinzoColors.primary.withAlpha(40)
                            : WinzoColors.bgElevated,
                        borderRadius: BorderRadius.circular(
                            WinzoDimens.radiusSM),
                        border: Border.all(
                          color: isSelected
                              ? WinzoColors.primary
                              : WinzoColors.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        _formatInterval(sec),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? WinzoColors.primaryLight
                              : WinzoColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: WinzoDimens.spaceXL),

              // ── Action Buttons ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              WinzoDimens.radiusSM),
                          side: const BorderSide(
                              color: WinzoColors.borderSubtle),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(false),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: WinzoColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: WinzoDimens.spaceSM),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: WinzoColors.primary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              WinzoDimens.radiusSM),
                        ),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Save & Apply',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      onPressed: () async {
                        final newUrl = _urlController.text.trim();
                        final newIntervalSec =
                            int.tryParse(_intervalController.text.trim()) ??
                                _selectedSeconds;
                        if (newUrl.isNotEmpty) {
                          await AppConfig.setBaseUrl(newUrl);
                        }
                        await AppConfig.setUpdateIntervalSeconds(newIntervalSec);
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
