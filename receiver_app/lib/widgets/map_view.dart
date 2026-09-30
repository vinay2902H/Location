import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_data.dart';

class LiveMapView extends StatefulWidget {
  final LocationDataModel? location;
  final bool isLoading;
  final Function(GoogleMapController)? onMapCreated;
  final double height;

  const LiveMapView({
    super.key,
    required this.location,
    required this.isLoading,
    this.onMapCreated,
    this.height = 280,
  });

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  GoogleMapController? _controller;
  MapType _currentMapType = MapType.normal;

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(17.385044, 78.486671),
    zoom: 15,
  );

  @override
  void didUpdateWidget(covariant LiveMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != null &&
        (oldWidget.location == null ||
            oldWidget.location!.latitude != widget.location!.latitude ||
            oldWidget.location!.longitude != widget.location!.longitude)) {
      _animateToLocation(widget.location!.latitude, widget.location!.longitude);
    }
  }

  void _animateToLocation(double lat, double lng, {double zoom = 16}) {
    if (_controller != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: zoom,
          ),
        ),
      );
    }
  }

  Set<Marker> _buildMarkers() {
    if (widget.location == null) return {};
    final displayName = widget.location!.username.isNotEmpty
        ? widget.location!.username
        : 'Sender';
    return {
      Marker(
        markerId: MarkerId('sender_${widget.location!.id}_${widget.location!.username}'),
        position: LatLng(widget.location!.latitude, widget.location!.longitude),
        infoWindow: InfoWindow(
          title: "📍 $displayName",
          snippet: "Accuracy: ${widget.location!.accuracy.toStringAsFixed(1)} m",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
  }

  Set<Circle> _buildCircles() {
    if (widget.location == null) return {};
    return {
      Circle(
        circleId: const CircleId('accuracy_circle'),
        center: LatLng(widget.location!.latitude, widget.location!.longitude),
        radius: widget.location!.accuracy > 0 ? widget.location!.accuracy : 15,
        fillColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
        strokeColor: const Color(0xFF2563EB).withValues(alpha: 0.6),
        strokeWidth: 1,
      ),
    };
  }

  Future<void> _openExternalMaps() async {
    if (widget.location == null) return;
    final urlStr =
        'https://www.google.com/maps?q=${widget.location!.latitude},${widget.location!.longitude}';
    final uri = Uri.parse(urlStr);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.location != null;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── GOOGLE MAP WITH EAGER GESTURE RECOGNIZERS ───────────────────
          GoogleMap(
            initialCameraPosition: hasLocation
                ? CameraPosition(
                    target: LatLng(widget.location!.latitude, widget.location!.longitude),
                    zoom: 16,
                  )
                : _defaultCameraPosition,
            mapType: _currentMapType,
            onMapCreated: (ctrl) {
              _controller = ctrl;
              if (widget.onMapCreated != null) {
                widget.onMapCreated!(ctrl);
              }
              if (hasLocation) {
                _animateToLocation(widget.location!.latitude, widget.location!.longitude);
              }
            },
            markers: _buildMarkers(),
            circles: _buildCircles(),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: false, // We provide modern floating controls
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),

          // ── TOP-LEFT SENDER BADGE ───────────────────────────────────────
          if (hasLocation)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      widget.location!.username,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.location!.latitude.toStringAsFixed(4)}, ${widget.location!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── TOP-RIGHT MAP CONTROLS (MAP TYPE TOGGLE) ─────────────────────
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _currentMapType = _currentMapType == MapType.normal
                        ? MapType.hybrid
                        : MapType.normal;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(7.0),
                  child: Icon(
                    _currentMapType == MapType.normal
                        ? Icons.satellite_alt_rounded
                        : Icons.map_rounded,
                    size: 20,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),

          // ── BOTTOM-RIGHT RE-CENTER & ZOOM BUTTONS ────────────────────────
          Positioned(
            bottom: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasLocation)
                  FloatingActionButton.small(
                    heroTag: 'map_center_${widget.key ?? hashCode}',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    elevation: 2,
                    tooltip: 'Center on sender',
                    onPressed: () {
                      _animateToLocation(widget.location!.latitude, widget.location!.longitude);
                    },
                    child: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                const SizedBox(height: 6),
                Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  elevation: 2,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _controller?.animateCamera(CameraUpdate.zoomIn()),
                        child: const Padding(
                          padding: EdgeInsets.all(7.0),
                          child: Icon(Icons.add_rounded, size: 20, color: Color(0xFF1E293B)),
                        ),
                      ),
                      Container(height: 1, width: 24, color: const Color(0xFFE2E8F0)),
                      InkWell(
                        onTap: () => _controller?.animateCamera(CameraUpdate.zoomOut()),
                        child: const Padding(
                          padding: EdgeInsets.all(7.0),
                          child: Icon(Icons.remove_rounded, size: 20, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM-LEFT EXTERNAL MAPS LAUNCHER ───────────────────────────
          if (hasLocation)
            Positioned(
              bottom: 10,
              left: 10,
              child: Material(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _openExternalMaps,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text(
                          'Open in Maps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── LOADING OVERLAY ──────────────────────────────────────────────
          if (widget.isLoading)
            Container(
              color: Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
