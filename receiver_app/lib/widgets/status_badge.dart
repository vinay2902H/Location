import 'package:flutter/material.dart';

class ReceiverStatusBadge extends StatelessWidget {
  final bool isLive;
  final bool isOffline;

  const ReceiverStatusBadge({
    super.key,
    required this.isLive,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            boxShadow: [
              BoxShadow(
                color: (isLive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withValues(alpha: 0.4),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isLive
              ? 'Sender is online (Internet active)'
              : (isOffline
                  ? 'Server unreachable (Offline)'
                  : 'Sender is offline (No Internet)'),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isLive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          ),
        ),
      ],
    );
  }
}
