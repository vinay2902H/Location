import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/location_data.dart';

class UsernameRecordCard extends StatelessWidget {
  final LocationDataModel record;
  final bool isLive;
  final bool isSelected;
  final VoidCallback onTap;

  const UsernameRecordCard({
    super.key,
    required this.record,
    this.isLive = false,
    this.isSelected = false,
    required this.onTap,
  });

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatted =
        DateFormat('hh:mm:ss a').format(record.timestamp.toLocal());
    final relativeTime = _formatRelativeTime(record.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
          highlightColor: const Color(0xFF2563EB).withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── USERNAME HEADER WITH ARROW ─────────────────────────────
                Row(
                  children: [
                    // Avatar with user's initial & live dot
                    Stack(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isLive
                                  ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
                                  : const [Color(0xFF64748B), Color(0xFF475569)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              record.username.isNotEmpty
                                  ? record.username[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        if (isLive)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Username & Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  record.username,
                                  style: const TextStyle(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF2563EB),
                                size: 15,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (record.email.isNotEmpty)
                            Text(
                              record.email,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            const Text(
                              'Sender • GPS Active',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // THE ARROW BUTTON
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFBFDBFE),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── SUMMARY METRICS CHIPS ──────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Coordinates pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.explore_outlined,
                            size: 13,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Accuracy pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            size: 13,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '±${record.accuracy.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Timestamp pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$timeFormatted ($relativeTime)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── HINT FOOTER ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLive ? '● Live broadcasting' : '● Recorded location',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
