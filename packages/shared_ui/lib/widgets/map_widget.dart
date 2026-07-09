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

  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onTap,
    this.showMyLocation = true,
    this.fitMarkers = true, // Default to true to fit all pins nicely
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;

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
    if (_mapController != null) {
      if (widget.fitMarkers && widget.markers.isNotEmpty) {
        _zoomToFitMarkers();
      } else if (widget.initialPosition != oldWidget.initialPosition) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(widget.initialPosition),
        );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialPosition,
          zoom: 12.5,
        ),
        markers: widget.markers,
        polylines: widget.polylines,
        onTap: widget.onTap,
        myLocationEnabled: widget.showMyLocation,
        myLocationButtonEnabled: widget.showMyLocation,
        zoomControlsEnabled: false,
        compassEnabled: true,
        onMapCreated: (controller) {
          _mapController = controller;
          try {
            _mapController!.setMapStyle(_darkSlateMapStyle);
          } catch (_) {}
          
          if (widget.fitMarkers && widget.markers.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _zoomToFitMarkers();
            });
          }

          // Safely open info windows for drawn markers after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted || _mapController == null) return;
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
        },
      ),
    );
  }
}
