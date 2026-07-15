import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_colors.dart';

class MapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final ArgumentCallback<LatLng>? onTap;
  final bool showMyLocation;
  final bool fitMarkers;
  final ArgumentCallback<CameraPosition>? onCameraMove;
  final ArgumentCallback<LatLng>? onCameraIdleLatLng;
  final bool isSelectorMode;

  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onTap,
    this.showMyLocation = true,
    this.fitMarkers = true, // Default to true to fit all pins nicely
    this.onCameraMove,
    this.onCameraIdleLatLng,
    this.isSelectorMode = false,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  bool _hasFittedMarkers = false;
  late LatLng _currentCameraTarget;

  @override
  void initState() {
    super.initState();
    _currentCameraTarget = widget.initialPosition;
  }

  static const String _darkSlateMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#0f172a"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#94a3b8"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0f172a"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#10b981"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#0f172a"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#334155"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0b0f19"}]}
  ]
  ''';

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPosition != oldWidget.initialPosition) {
      _currentCameraTarget = widget.initialPosition;
    }
    if (_mapController != null) {
      if (widget.fitMarkers && widget.markers.isNotEmpty && !_hasFittedMarkers) {
        _hasFittedMarkers = true;
        _zoomToFitMarkers();
      } else if (!widget.fitMarkers && widget.initialPosition != oldWidget.initialPosition) {
        // Only animate if the camera is not already at the initialPosition (e.g. from search/current location clicks)
        final double latDiff = (widget.initialPosition.latitude - _currentCameraTarget.latitude).abs();
        final double lngDiff = (widget.initialPosition.longitude - _currentCameraTarget.longitude).abs();
        if (latDiff > 0.00001 || lngDiff > 0.00001) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(widget.initialPosition),
          );
        }
      }
    }
  }

  void _zoomToFitMarkers() {
    if (_mapController == null || widget.markers.isEmpty) return;

    if (widget.markers.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(widget.markers.first.position, 13.5),
      );
      return;
    }

    double minLat = widget.markers.first.position.latitude;
    double maxLat = widget.markers.first.position.latitude;
    double minLng = widget.markers.first.position.longitude;
    double maxLng = widget.markers.first.position.longitude;

    for (final marker in widget.markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding in pixels
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      color: const Color(0xFF0F172A), // Slate 900 (Map dark bg)
      child: Stack(
        children: [
          // Simulated grid/lines for map
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(),
            ),
          ),
          // Top search skeleton bar
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Slate 800
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF475569),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom skeleton card
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: Container(
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF475569),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 15.0, // Zoom closer for better address accuracy
            ),
            markers: widget.markers,
            polylines: widget.polylines,
            onTap: widget.onTap,
            myLocationEnabled: widget.showMyLocation,
            myLocationButtonEnabled: false, // Hide default to avoid layout conflict
            zoomControlsEnabled: false,
            compassEnabled: true,
            onCameraMove: (position) {
              _currentCameraTarget = position.target;
              if (widget.onCameraMove != null) {
                widget.onCameraMove!(position);
              }
            },
            onCameraIdle: () {
              if (widget.onCameraIdleLatLng != null) {
                widget.onCameraIdleLatLng!(_currentCameraTarget);
              }
            },
            onMapCreated: (controller) {
              _mapController = controller;
              try {
                _mapController!.setMapStyle(_darkSlateMapStyle);
              } catch (_) {}

              if (widget.initialPosition != _currentCameraTarget) {
                _currentCameraTarget = widget.initialPosition;
                try {
                  _mapController!.moveCamera(
                    CameraUpdate.newLatLng(widget.initialPosition),
                  );
                } catch (_) {}
              }
              
              if (widget.fitMarkers && widget.markers.isNotEmpty && !widget.isSelectorMode) {
                _hasFittedMarkers = true;
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _zoomToFitMarkers();
                });
              }

              // Safely open info windows for drawn markers after a short delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!mounted || _mapController == null || widget.isSelectorMode) return;
                try {
                  for (final marker in widget.markers) {
                    if (marker.markerId == const MarkerId('my_current_position') ||
                        marker.markerId == const MarkerId('driver_current_position') ||
                        marker.markerId == const MarkerId('pickup')) {
                      _mapController!.showMarkerInfoWindow(marker.markerId);
                    }
                  }
                } catch (_) {}
              });

              if (mounted) {
                setState(() {
                  _isMapReady = true;
                });
              }
            },
          ),
          if (widget.isSelectorMode && _isMapReady)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24), // Center offset
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car_filled,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 10,
                      color: AppColors.primary,
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isMapReady)
            Positioned.fill(
              child: _buildSkeletonLoader(),
            ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B) // Slate 800 line
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Draw some horizontal/vertical/diagonal roads
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.35), paint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.45, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.65), paint);
    
    // Draw some smaller streets
    paint.strokeWidth = 2;
    paint.color = const Color(0xFF1E293B).withValues(alpha: 0.5);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
