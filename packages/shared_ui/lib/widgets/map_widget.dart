import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_colors.dart';

class MapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final ArgumentCallback<LatLng>? onTap;
  final bool showMyLocation;

  const MapWidget({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onTap,
    this.showMyLocation = true,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;

  static const String _darkGreenMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#0a0f0a"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#81c784"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0a0f0a"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#1b5e20"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#111811"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#66bb6a"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1a231a"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#0a0f0a"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2e7d32"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#111811"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#051405"}]}
  ]
  ''';

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPosition != oldWidget.initialPosition && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(widget.initialPosition),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: GoogleMap(
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
        onMapCreated: (controller) {
          _mapController = controller;
          try {
            _mapController!.setMapStyle(_darkGreenMapStyle);
          } catch (_) {}
        },
      ),
    );
  }
}
