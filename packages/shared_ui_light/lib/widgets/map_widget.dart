import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  final void Function(double zoom)? onZoomChanged;

  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onTap,
    this.showMyLocation = true,
    this.fitMarkers = true,
    this.onCameraMove,
    this.onCameraIdleLatLng,
    this.isSelectorMode = false,
    this.onZoomChanged,
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

  // Premium minimal light map style
  static const String _lightMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f5f5f5"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#dadada"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
    {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"color": "#e5e5e5"}]},
    {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c9c9c9"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]}
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
        50.0,
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      color: const Color(0xFFF7F9FC), // Light map background
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(),
            ),
          ),
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: Container(
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBD5E1),
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
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
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
                      color: const Color(0xFFEDF2F7),
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
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 15.0,
            ),
            markers: widget.markers,
            polylines: widget.polylines,
            onTap: widget.onTap,
            myLocationEnabled: widget.showMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onCameraMove: (position) {
              _currentCameraTarget = position.target;
              if (widget.onCameraMove != null) {
                widget.onCameraMove!(position);
              }
              if (widget.onZoomChanged != null) {
                widget.onZoomChanged!(position.zoom);
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
                _mapController!.setMapStyle(_lightMapStyle);
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
                padding: const EdgeInsets.only(bottom: 24),
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
      ..color = const Color(0xFFE2E8F0) // light grid line
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.35), paint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.45, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.65), paint);
    
    paint.strokeWidth = 2;
    paint.color = const Color(0xFFE2E8F0).withValues(alpha: 0.5);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
