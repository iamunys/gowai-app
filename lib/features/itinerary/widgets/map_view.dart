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

  /// When provided these override the internally-built default markers,
  /// allowing the parent to supply custom numbered/styled markers.
  final Set<Marker>? externalMarkers;

  /// Called once the GoogleMapController is available so the parent can
  /// animate the camera (zoom-to-stop, etc.).
  final void Function(GoogleMapController)? onMapReady;

  const MapView({
    super.key,
    required this.stops,
    required this.routePoints,
    required this.selectedIndex,
    required this.onMarkerTap,
    this.externalMarkers,
    this.onMapReady,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;

  /// Fallback markers — used when the parent hasn't supplied externalMarkers yet.
  Set<Marker> get _defaultMarkers {
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
    // Follow the device theme: night style in dark mode, default light map
    // in day mode. MediaQuery rebuilds this widget when brightness changes,
    // so the map switches automatically with day/night.
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _initialTarget,
        zoom: 12,
      ),
      style: isDark ? _nightMapStyle : null,
      // Prefer external markers (custom numbered circles) if available.
      markers: widget.externalMarkers ?? _defaultMarkers,
      polylines: _polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        // Expose controller to parent for camera animation.
        widget.onMapReady?.call(ctrl);
        Future.delayed(const Duration(milliseconds: 500), _fitBounds);
      },
    );
  }
}

// ─── Map styles ───────────────────────────────────────────────────────────────

/// Google Maps "Night" style JSON. Applied only when the device is in dark
/// mode; in light mode the style is cleared (null) to show the default light map.
const String _nightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';
