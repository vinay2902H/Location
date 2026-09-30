import 'package:flutter/material.dart';

class CoordinateCard extends StatelessWidget {
  final String username;
  final String email;
  final String dbId;
  final String? userId;
  final String latitude;
  final String longitude;
  final String accuracy;
  final String lastUpdated;
  final String? isoTimestamp;
  final bool isOffline;
  final VoidCallback? onTapUser;

  const CoordinateCard({
    super.key,
    this.username = 'User',
    this.email = '',
    this.dbId = 'X',
    this.userId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.lastUpdated,
    this.isoTimestamp,
    this.isOffline = false,
    this.onTapUser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── USER NAME COLUMN WITH ARROW ─────────────────────────────
            InkWell(
              onTap: onTapUser,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEFF6FF),
                      Color(0xFFDBEAFE),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'SENDER USERNAME',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 14),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Visual Arrow Button
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── DATABASE METRICS & DATA ─────────────────────────────────
            // 2-Column Coordinates
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'Latitude',
                    value: latitude,
                    icon: Icons.explore_outlined,
                  ),
                ),
                Container(width: 1, height: 42, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildMetricItem(
                    label: 'Longitude',
                    value: longitude,
                    icon: Icons.navigation_outlined,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // Accuracy & Last Updated
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'GPS Accuracy',
                    value: accuracy,
                    icon: Icons.my_location_rounded,
                  ),
                ),
                Container(width: 1, height: 42, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: _buildMetricItem(
                    label: isOffline ? 'Last Known Time' : 'Last Updated',
                    value: lastUpdated,
                    icon: Icons.access_time_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
