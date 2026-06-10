import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/trip_stop.dart';

class MapView extends StatefulWidget {
  final List<TripStop> stops;
  final List<LatLng> routePoints;
  final int selectedIndex;
  final Function(int) onMarkerTap;

  const MapView({
    super.key,
    required this.stops,
    required this.routePoints,
    required this.selectedIndex,
    required this.onMarkerTap,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;

  Set<Marker> get _markers {
    return widget.stops
        .where((s) => s.latLng != null)
        .map((s) {
          final isSelected =
              widget.stops.indexOf(s) == widget.selectedIndex;
          return Marker(
            markerId: MarkerId('stop_${s.stopNumber}'),
            position: s.latLng!,
            infoWindow: InfoWindow(title: s.name, snippet: s.time),
            icon: isSelected
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet)
                : BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
            onTap: () {
              final idx = widget.stops.indexOf(s);
              widget.onMarkerTap(idx);
            },
          );
        })
        .toSet();
  }

  Set<Polyline> get _polylines {
    if (widget.routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.routePoints,
        color: AppColors.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(8)],
      ),
    };
  }

  void _fitBounds() {
    final coords = widget.stops
        .where((s) => s.latLng != null)
        .map((s) => s.latLng!)
        .toList();
    if (coords.isEmpty || _mapController == null) return;

    double minLat = coords.first.latitude;
    double maxLat = coords.first.latitude;
    double minLng = coords.first.longitude;
    double maxLng = coords.first.longitude;

    for (final c in coords) {
      minLat = math.min(minLat, c.latitude);
      maxLat = math.max(maxLat, c.latitude);
      minLng = math.min(minLng, c.longitude);
      maxLng = math.max(maxLng, c.longitude);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        60,
      ),
    );
  }

  LatLng get _initialTarget {
    final valid = widget.stops.where((s) => s.latLng != null).toList();
    if (valid.isEmpty) return const LatLng(12.9716, 77.5946);
    return valid.first.latLng!;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _initialTarget,
        zoom: 12,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        Future.delayed(
            const Duration(milliseconds: 500), _fitBounds);
      },
    );
  }
}
