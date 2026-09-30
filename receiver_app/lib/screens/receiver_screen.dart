import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/location_data.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/map_view.dart';
import '../widgets/coordinate_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/server_config_dialog.dart';
import '../widgets/username_record_card.dart';
import 'receiver_login_screen.dart';
import 'record_detail_screen.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final SocketService _socketService = SocketService();
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  LocationDataModel? _location;
  List<LocationDataModel> _allSenders = [];
  String? _selectedUsername;
  String _searchQuery = '';

  String? _receiverIdentity;
  List<String>? _adminAllowedSenders;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;

  final Map<String, DateTime> _senderLastPacketTimes = {};
  Timer? _livenessTimer;

  @override
  void initState() {
    super.initState();
    _socketService.addListener(_onSocketUpdated);
    _socketService.connect();
    _loadSavedReceiverIdentity();
    _livenessTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _livenessTimer?.cancel();
    _searchController.dispose();
    _socketService.removeListener(_onSocketUpdated);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadSavedReceiverIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('mapped_receiver_username')?.trim().toLowerCase();
    if (saved == null || saved.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReceiverLoginScreen()),
        );
      }
      return;
    }
    setState(() {
      _receiverIdentity = saved;
    });
    _fetchInitialLocation();
  }

  Future<void> _fetchInitialLocation() async {
    if (_receiverIdentity == null || _receiverIdentity!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('mapped_receiver_username')?.trim().toLowerCase();
      if (saved == null || saved.isEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReceiverLoginScreen()),
          );
        }
        return;
      }
      _receiverIdentity = saved;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mappingRes = await ApiService.fetchReceiverMapping(_receiverIdentity!);
      if (mappingRes != null && mappingRes['isMapped'] == true) {
        final mappingData = mappingRes['mapping'] as Map<String, dynamic>?;
        final rawList = mappingData?['senderUsernames'] as List?;
        _adminAllowedSenders = rawList?.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList() ?? [];
      } else {
        _adminAllowedSenders = [];
      }

      final loc = await ApiService.fetchLatestLocation(
        username: _selectedUsername,
        receiverUsername: _receiverIdentity,
      );
      final allLocs = await ApiService.fetchAllLocations(
        receiverUsername: _receiverIdentity,
      );
      final acts = await ApiService.fetchUserActivities(username: _selectedUsername);

      // Clean filter: strictly senders mapped to this receiver by admin
      var cleanSenders = allLocs
          .where((s) => s.username.isNotEmpty && s.username != 'User' && s.username != 'Player_777')
          .where((s) => _adminAllowedSenders!.contains(s.username))
          .toList();

      if (loc.username.isNotEmpty && loc.username != 'User' && loc.username != 'Player_777' && _adminAllowedSenders!.contains(loc.username)) {
        if (!cleanSenders.any((s) => s.username == loc.username)) {
          cleanSenders.insert(0, loc);
        }
      }

      for (final a in acts) {
        if (a.username.isNotEmpty && a.username != 'User' && a.username != 'Player_777' && _adminAllowedSenders!.contains(a.username)) {
          if (!cleanSenders.any((s) => s.username == a.username)) {
            cleanSenders.add(
              LocationDataModel(
                id: 'hist_${a.username}',
                username: a.username,
                email: a.email,
                latitude: a.latitude,
                longitude: a.longitude,
                accuracy: a.accuracy,
                timestamp: a.timestamp,
              ),
            );
          }
        }
      }

      // Determine active sender location
      LocationDataModel? activeLoc;
      if (_selectedUsername != null) {
        final match = cleanSenders.where((s) => s.username == _selectedUsername);
        activeLoc = match.isNotEmpty ? match.first : (loc.username == _selectedUsername && _adminAllowedSenders!.contains(loc.username) ? loc : null);
      } else {
        if (loc.username.isNotEmpty && loc.username != 'User' && loc.username != 'Player_777' && _adminAllowedSenders!.contains(loc.username)) {
          activeLoc = loc;
        } else if (cleanSenders.isNotEmpty) {
          activeLoc = cleanSenders.first;
        }
      }

      if (!mounted) return;
      setState(() {
        _location = activeLoc;
        _allSenders = cleanSenders;
        _isLoading = false;
        _isOffline = false;
        _errorMessage = null;
      });
      if (activeLoc != null) {
        _socketService.updateLocationManually(activeLoc);
        _animateToLocation(activeLoc.latitude, activeLoc.longitude);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.isNetworkError) {
          _isOffline = true;
          _errorMessage = 'Unable to connect to server.';
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load location: $e';
      });
    }
  }

  void _onSocketUpdated() {
    if (!mounted) return;

    final newLoc = _socketService.latestLocation;
    final socketConnected = _socketService.isConnected;

    setState(() {
      if (_socketService.errorMessage != null && !socketConnected) {
        _isOffline = true;
      } else if (socketConnected) {
        _isOffline = false;
        _errorMessage = null;
      }

      if (newLoc != null && newLoc.username.isNotEmpty && newLoc.username != 'User' && newLoc.username != 'Player_777') {
        _senderLastPacketTimes[newLoc.username] = DateTime.now();

        // STRICT ENFORCEMENT: Ignore any sender not mapped to this receiver by admin
        if (_adminAllowedSenders == null || !_adminAllowedSenders!.contains(newLoc.username)) {
          return;
        }

        // If a specific sender is selected, only switch if matches
        if (_selectedUsername == null || newLoc.username == _selectedUsername) {
          _location = newLoc;
          _isOffline = false;
          _errorMessage = null;
        }

        // Keep sender list updated
        final existingIdx = _allSenders.indexWhere((s) => s.username == newLoc.username);
        if (existingIdx >= 0) {
          _allSenders[existingIdx] = newLoc;
        } else {
          _allSenders.insert(0, newLoc);
        }
      }
    });

    if (newLoc != null && newLoc.username.isNotEmpty && newLoc.username != 'User' && newLoc.username != 'Player_777') {
      if (_adminAllowedSenders != null && _adminAllowedSenders!.contains(newLoc.username)) {
        if (_selectedUsername == null || newLoc.username == _selectedUsername) {
          _animateToLocation(newLoc.latitude, newLoc.longitude);
        }
      }
    }
  }

  bool _isSenderOnline(LocationDataModel sender) {
    if (_isOffline) return false;
    final now = DateTime.now();
    final lastPacket = _senderLastPacketTimes[sender.username];
    if (lastPacket != null && now.difference(lastPacket).inSeconds < 90) {
      return true;
    }
    final diff = now.difference(sender.timestamp.toLocal());
    return diff.inSeconds.abs() < 120;
  }

  void _animateToLocation(double lat, double lng) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 16),
        ),
      );
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_location == null) return;
    final urlStr = 'https://www.google.com/maps?q=${_location!.latitude},${_location!.longitude}';
    final uri = Uri.parse(urlStr);

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Google Maps: $e')),
        );
      }
    }
  }

  void _openConfigDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerConfigDialog(),
    );
    if (updated == true && mounted) {
      _socketService.connect();
      _fetchInitialLocation();
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Switch Receiver Account'),
        content: Text('Do you want to log out of receiver account @$_receiverIdentity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mapped_receiver_username');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReceiverLoginScreen()),
      );
    }
  }

  void _selectSender(String? username) {
    setState(() {
      _selectedUsername = username;
    });
    _fetchInitialLocation();
  }

  void _navigateToRecordDetails(LocationDataModel record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordDetailScreen(record: record),
      ),
    ).then((_) {
      if (mounted) {
        _fetchInitialLocation();
      }
    });
  }

  List<LocationDataModel> get _filteredRecords {
    var records = _allSenders
        .where((s) => s.username.isNotEmpty && s.username != 'User' && s.username != 'Player_777')
        .toList();

    // Fallback: if list is empty but current _location exists and is genuine, include it
    if (records.isEmpty && _location != null && _location!.username.isNotEmpty && _location!.username != 'User' && _location!.username != 'Player_777') {
      records = [_location!];
    }

    // Filter by selected sender tab if specified
    if (_selectedUsername != null && _selectedUsername!.isNotEmpty) {
      records = records.where((s) => s.username == _selectedUsername).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      records = records.where((s) {
        final matchesUser = s.username.toLowerCase().contains(q);
        final matchesEmail = s.email.toLowerCase().contains(q);
        final matchesId = s.id.toLowerCase().contains(q);
        return matchesUser || matchesEmail || matchesId;
      }).toList();
    }

    return records;
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _location != null;
    final isSelectedSenderOnline = _location != null && _isSenderOnline(_location!);
    final latStr = hasLocation ? _location!.latitude.toStringAsFixed(6) : '—';
    final lngStr = hasLocation ? _location!.longitude.toStringAsFixed(6) : '—';
    final accStr = hasLocation ? '${_location!.accuracy.toStringAsFixed(1)} m' : '—';
    final lastUpdatedStr = hasLocation
        ? DateFormat('hh:mm:ss a').format(_location!.timestamp.toLocal())
        : '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icons/winzowin.png',
                width: 32,
                height: 32,
                errorBuilder: (_, _, _) => const Icon(Icons.location_on, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WinzoWin',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  'Live Location Receiver',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_receiverIdentity != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      '@$_receiverIdentity',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Switch Receiver Account',
            onPressed: _handleLogout,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Location & DB',
            onPressed: _fetchInitialLocation,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Configuration',
            onPressed: _openConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Google Map View Widget
              LiveMapView(
                location: _location,
                isLoading: _isLoading,
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (hasLocation) {
                    _animateToLocation(_location!.latitude, _location!.longitude);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Offline Warning Banner
              if (_isOffline || _errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Unable to connect to server.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Last known location: $lastUpdatedStr',
                          style: const TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── SECTION: RECORDS BASED ON USERNAME ───────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text(
                        'SENDERS SHARING LOCATION',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '${_filteredRecords.length} records',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search Bar by Username
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search senders by username or email...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: const Color(0xFF94A3B8),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Active Senders Filter Chips (if multiple senders)
              if (_allSenders.length > 1) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text('All Senders'),
                          selected: _selectedUsername == null,
                          onSelected: (_) => _selectSender(null),
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: _selectedUsername == null
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ..._allSenders.map((s) {
                        final isSelected = _selectedUsername == s.username;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            avatar: const Icon(Icons.person_rounded, size: 16),
                            label: Text(s.username),
                            selected: isSelected,
                            onSelected: (_) => _selectSender(s.username),
                            selectedColor: const Color(0xFF2563EB),
                            labelStyle: TextStyle(
                              color: isSelected
                                   ? Colors.white
                                  : const Color(0xFF1E293B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── LIST OF RECORDS BASED ON USERNAME ─────────────────────────
              if (_filteredRecords.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.person_search_rounded,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          (_adminAllowedSenders != null && _adminAllowedSenders!.isEmpty)
                              ? 'No senders mapped to @$_receiverIdentity'
                              : (_searchQuery.isNotEmpty
                                  ? 'No records found for "$_searchQuery"'
                                  : 'Waiting for mapped senders...'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_adminAllowedSenders != null && _adminAllowedSenders!.isEmpty)
                              ? 'Ask the administrator to assign senders (e.g. a, b) to @$_receiverIdentity in the Admin Panel.'
                              : 'Records appear automatically when your assigned senders transmit coordinates.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _fetchInitialLocation,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Refresh Records'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._filteredRecords.map((sender) {
                  final isSenderLive = _isSenderOnline(sender);
                  final isSenderSelected = _selectedUsername == sender.username;
                  return UsernameRecordCard(
                    record: sender,
                    isLive: isSenderLive,
                    isSelected: isSenderSelected,
                    onTap: () => _navigateToRecordDetails(sender),
                  );
                }),
              const SizedBox(height: 14),

              // ── ACTIVE SENDER OVERVIEW CARD (with arrow navigating to details) ──
              if (hasLocation) ...[
                const Row(
                  children: [
                    Icon(Icons.radar_rounded, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(
                      'ACTIVE SENDER LIVE METRICS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CoordinateCard(
                  username: (_location != null && _location!.username.isNotEmpty && _location!.username != 'User')
                      ? _location!.username
                      : (_location?.email.isNotEmpty == true ? _location!.email.split('@')[0] : 'Sender'),
                  email: _location?.email ?? '',
                  dbId: _location?.id ?? '—',
                  userId: _location?.userId,
                  latitude: latStr,
                  longitude: lngStr,
                  accuracy: accStr,
                  lastUpdated: lastUpdatedStr,
                  isoTimestamp: _location?.timestamp.toIso8601String(),
                  isOffline: !isSelectedSenderOnline,
                  onTapUser: () => _navigateToRecordDetails(_location!),
                ),
                const SizedBox(height: 14),
              ],

              // Status Indicator Badge Widget
              ReceiverStatusBadge(
                isLive: isSelectedSenderOnline,
                isOffline: _isOffline || !isSelectedSenderOnline,
              ),
              const SizedBox(height: 16),

              // VIEW USER DETAILS & HISTORY BUTTON
              OutlinedButton.icon(
                onPressed: hasLocation
                    ? () => _navigateToRecordDetails(_location!)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No sender location available yet'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF2563EB)),
                label: const Text(
                  'VIEW SENDER LOCATION DETAILS',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF2563EB),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // OPEN IN GOOGLE MAPS Button
              FilledButton.icon(
                onPressed: hasLocation ? _openInGoogleMaps : null,
                icon: const Icon(Icons.map_outlined),
                label: const Text(
                  'OPEN IN GOOGLE MAPS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Server: ${AppConfig.baseUrl}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
