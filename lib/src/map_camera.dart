import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:latlong2/latlong.dart' as lat;
import 'package:map_camera_flutter/map_camera_flutter.dart';

class MapCameraLocation extends StatefulWidget {
  final CameraDescription camera;
  final ValueChanged<ImageAndLocationData>? onImageCaptured;

  const MapCameraLocation({
    super.key,
    required this.camera,
    this.onImageCaptured,
  });

  @override
  State<MapCameraLocation> createState() => _MapCameraLocationState();
}

class _OverlayView {
  const _OverlayView({
    required this.locationData,
    required this.dateTime,
    required this.followOnLocationUpdate,
  });

  final LocationData? locationData;
  final String dateTime;
  final AlignOnUpdate followOnLocationUpdate;
}

class _MapCameraLocationState extends State<MapCameraLocation> {
  static const _geocodeMinDistanceMeters = 25.0;
  static final _dateFormat = DateFormat.yMd().add_jm();
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 15,
  );

  late final CameraController _controller;
  late final Future<void> _initializeControllerFuture;
  final Geocoding _geocoding = Geocoding();
  final GlobalKey _boundaryKey = GlobalKey();
  final ValueNotifier<_OverlayView> _overlay = ValueNotifier(
    _OverlayView(
      locationData: null,
      dateTime: _formatNow(),
      followOnLocationUpdate: AlignOnUpdate.always,
    ),
  );

  Timer? _positionTimer;
  bool _positionUpdateInFlight = false;
  String? _documentsDirectory;
  bool? _locationServiceEnabled;
  double? _lastGeocodedLat;
  double? _lastGeocodedLng;
  LocationData? _cachedGeocodeData;

  static String _formatNow() => _dateFormat.format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();

    // Location + reverse geocode are expensive. Poll slowly and skip overlap.
    _positionTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_updatePosition());
    });
    unawaited(_updatePosition());
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _controller.dispose();
    _overlay.dispose();
    super.dispose();
  }

  void _updateOverlay({
    LocationData? locationData,
    String? dateTime,
    AlignOnUpdate? followOnLocationUpdate,
  }) {
    final current = _overlay.value;
    _overlay.value = _OverlayView(
      locationData: locationData ?? current.locationData,
      dateTime: dateTime ?? current.dateTime,
      followOnLocationUpdate:
          followOnLocationUpdate ?? current.followOnLocationUpdate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Stack(
                children: [
                  CameraPreview(_controller),
                  ValueListenableBuilder<_OverlayView>(
                    valueListenable: _overlay,
                    builder: (context, overlay, _) {
                      return Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: SizedBox(
                          height: 160,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: SizedBox(
                                    width: 120,
                                    child: Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: overlay.locationData == null
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : FlutterMap(
                                              options: MapOptions(
                                                initialCenter:
                                                    const lat.LatLng(0, 0),
                                                initialZoom: 13.0,
                                                onPositionChanged:
                                                    (position, hasGesture) {
                                                  if (hasGesture) {
                                                    _updateOverlay(
                                                      followOnLocationUpdate:
                                                          AlignOnUpdate.never,
                                                    );
                                                  }
                                                },
                                              ),
                                              children: [
                                                TileLayer(
                                                  urlTemplate:
                                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                  userAgentPackageName:
                                                      'com.example.app',
                                                  minZoom: 12,
                                                ),
                                                CurrentLocationLayer(
                                                  alignPositionOnUpdate: overlay
                                                      .followOnLocationUpdate,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: LocationDetailsWidget(
                                  locationData: overlay.locationData,
                                  dateTime: overlay.dateTime,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _initializeControllerFuture;
          await _takeScreenshot();
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      debugPrint('Screenshot boundary is not ready');
      return;
    }

    final image = await boundary.toImage(pixelRatio: 1.0);
    try {
      _documentsDirectory ??=
          (await getApplicationDocumentsDirectory()).path;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('Screenshot encode failed');
        return;
      }

      final imgFile = File(
        '$_documentsDirectory/screenshot${Random().nextInt(200)}.png',
      );
      await imgFile.writeAsBytes(byteData.buffer.asUint8List());

      widget.onImageCaptured?.call(
        ImageAndLocationData(
          imagePath: imgFile.path,
          locationData: _overlay.value.locationData,
        ),
      );
    } finally {
      image.dispose();
    }
  }

  bool _movedEnoughForGeocode(Position position) {
    final lastLat = _lastGeocodedLat;
    final lastLng = _lastGeocodedLng;
    if (lastLat == null || lastLng == null) {
      return true;
    }
    return Geolocator.distanceBetween(
          lastLat,
          lastLng,
          position.latitude,
          position.longitude,
        ) >=
        _geocodeMinDistanceMeters;
  }

  Future<void> _updatePosition() async {
    if (_positionUpdateInFlight || !mounted) {
      return;
    }
    _positionUpdateInFlight = true;
    try {
      final position = await _determinePosition();

      final LocationData next;
      if (!_movedEnoughForGeocode(position) && _cachedGeocodeData != null) {
        next = _cachedGeocodeData!.withCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        final placeMarks = await _geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placeMarks.isEmpty) {
          next = LocationData.unavailable('No Location Data');
        } else {
          next = LocationData.fromPlacemark(
            latitude: position.latitude,
            longitude: position.longitude,
            placeMark: placeMarks.first,
          );
        }
        _lastGeocodedLat = position.latitude;
        _lastGeocodedLng = position.longitude;
        _cachedGeocodeData = next;
      }

      if (next == _overlay.value.locationData) {
        return;
      }

      _updateOverlay(
        locationData: next,
        dateTime: _formatNow(),
      );
    } on Exception catch (e, st) {
      debugPrint('Location update failed: $e\n$st');
      _updateOverlay(
        locationData: LocationData.unavailable('Error Retrieving Location'),
      );
    } finally {
      _positionUpdateInFlight = false;
    }
  }

  Future<Position> _determinePosition() async {
    _locationServiceEnabled ??= await Geolocator.isLocationServiceEnabled();
    if (_locationServiceEnabled != true) {
      _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (_locationServiceEnabled != true) {
        throw Exception('Location services are disabled.');
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return Geolocator.getCurrentPosition(locationSettings: _locationSettings);
  }
}
