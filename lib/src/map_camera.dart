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
  const _OverlayView({required this.locationData, required this.dateTime});

  final LocationData? locationData;
  final String dateTime;
}

class _MarkerFeed {
  final StreamController<LocationMarkerPosition?> _controller =
      StreamController<LocationMarkerPosition?>.broadcast();
  LocationMarkerPosition? latest;

  late final Stream<LocationMarkerPosition?> stream =
      Stream<LocationMarkerPosition?>.multi((listener) {
        final value = latest;
        if (value != null) {
          listener.add(value);
        }
        final subscription = _controller.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = subscription.cancel;
      });

  void add(Position position) {
    latest = LocationMarkerPosition.unchecked(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
    if (!_controller.isClosed) {
      _controller.add(latest);
    }
  }

  void close() {
    _controller.close();
  }
}

class _MapCameraLocationState extends State<MapCameraLocation>
    with WidgetsBindingObserver {
  static const _geocodeMinDistanceMeters = 25.0;
  static const _locationAccuracy = LocationAccuracy.medium;
  static const _distanceFilter = 15;
  static final _dateFormat = DateFormat.yMd().add_jm();
  static const _oneShotFixLimit = Duration(seconds: 10);

  CameraController? _controller;
  var _shooting = false;
  final Geocoding _geocoding = Geocoding();
  final GlobalKey _overlayKey = GlobalKey();
  final _MarkerFeed _markerFeed = _MarkerFeed();
  final ValueNotifier<lat.LatLng?> _mapCenter = ValueNotifier(null);
  final ValueNotifier<_OverlayView> _overlay = ValueNotifier(
    _OverlayView(locationData: null, dateTime: _formatNow()),
  );

  StreamSubscription<Position>? _positionSub;
  bool _disposed = false;
  bool _geocodeBusy = false;
  Position? _queuedPosition;
  String? _documentsDirectory;
  lat.LatLng? _lastGeocoded;
  LocationData? _cachedGeocodeData;

  static String _formatNow() => _dateFormat.format(DateTime.now());

  static LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: _locationAccuracy,
        distanceFilter: _distanceFilter,
        intervalDuration: const Duration(seconds: 5),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: _locationAccuracy,
        distanceFilter: _distanceFilter,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
      );
    }
    return const LocationSettings(
      accuracy: _locationAccuracy,
      distanceFilter: _distanceFilter,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_openCamera());
    unawaited(_startLocationUpdates());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The shade and the permission prompt also mark the app inactive.
    // CameraX releases the camera when the app is paused.
    if (state == AppLifecycleState.paused) {
      final controller = _controller;
      _controller = null;
      _shooting = false;
      if (controller != null) {
        unawaited(controller.dispose());
      }
      if (mounted) {
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        !_disposed) {
      unawaited(_openCamera());
    }
  }

  Future<void> _openCamera() async {
    final controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
    } on CameraException catch (error, stackTrace) {
      debugPrint('Camera open failed: $error\n$stackTrace');
      if (identical(_controller, controller)) {
        _controller = null;
      }
      unawaited(controller.dispose());
      return;
    }
    if (!mounted || !identical(_controller, controller)) {
      unawaited(controller.dispose());
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _markerFeed.close();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    _overlay.dispose();
    _mapCenter.dispose();
    super.dispose();
  }

  void _showLocationError() {
    if (_disposed || _overlay.value.locationData != null) {
      return;
    }
    _updateOverlay(
      locationData: LocationData.unavailable('Error Retrieving Location'),
    );
  }

  void _updateOverlay({LocationData? locationData, String? dateTime}) {
    if (_disposed) {
      return;
    }
    final current = _overlay.value;
    _overlay.value = _OverlayView(
      locationData: locationData ?? current.locationData,
      dateTime: dateTime ?? current.dateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ready
            ? Stack(
                children: [
                  CameraPreview(controller),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: RepaintBoundary(
                      key: _overlayKey,
                      child: SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: ValueListenableBuilder<lat.LatLng?>(
                                valueListenable: _mapCenter,
                                builder: (context, center, _) {
                                  return Card(
                                    elevation: 3,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                    child: SizedBox(
                                      width: 120,
                                      child: center == null
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : _LiveMap(
                                              initialCenter: center,
                                              positionStream:
                                                  _markerFeed.stream,
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              child: ValueListenableBuilder<_OverlayView>(
                                valueListenable: _overlay,
                                builder: (context, overlay, _) {
                                  return LocationDetailsWidget(
                                    locationData: overlay.locationData,
                                    dateTime: overlay.dateTime,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ready ? () => unawaited(_shoot()) : null,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (_shooting ||
        _disposed ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    _shooting = true;
    try {
      final photo = await controller.takePicture();
      if (_disposed) {
        return;
      }
      final path = await _savePhoto(photo.path);
      if (_disposed) {
        return;
      }
      widget.onImageCaptured?.call(
        ImageAndLocationData(
          imagePath: path,
          locationData: _overlay.value.locationData,
        ),
      );
    } on CameraException catch (error, stackTrace) {
      debugPrint('Camera shot failed: $error\n$stackTrace');
    } finally {
      _shooting = false;
    }
  }

  Future<ui.Image?> _captureOverlay(int photoWidth) async {
    final boundary =
        _overlayKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || _disposed || !mounted) {
      return null;
    }
    final logicalWidth = boundary.size.width;
    final deviceRatio = MediaQuery.devicePixelRatioOf(context);
    final fitRatio = logicalWidth > 0 ? photoWidth / logicalWidth : deviceRatio;
    final pixelRatio = fitRatio < deviceRatio ? fitRatio : deviceRatio;
    if (pixelRatio <= 0) {
      return null;
    }
    if (boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || !mounted || boundary.debugNeedsPaint) {
        return null;
      }
    }
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  Future<String> _savePhoto(String sourcePath) async {
    final directory = _documentsDirectory ??=
        (await getApplicationDocumentsDirectory()).path;
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    ui.Image? overlay;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final photo = frame.image;
      codec.dispose();
      try {
        overlay = await _captureOverlay(photo.width);
        if (overlay != null && !_disposed) {
          final stamped = await _writeStampedPhoto(
            directory,
            stamp,
            photo,
            overlay,
          );
          if (stamped != null) {
            return stamped;
          }
        }
      } finally {
        photo.dispose();
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Screenshot encode failed: $error\n$stackTrace');
    } finally {
      overlay?.dispose();
      if (await source.exists()) {
        await source.delete();
      }
    }
    final dest = File('$directory/screenshot$stamp.jpg');
    await dest.writeAsBytes(bytes);
    return dest.path;
  }

  Future<String?> _writeStampedPhoto(
    String directory,
    int stamp,
    ui.Image photo,
    ui.Image overlay,
  ) async {
    final composed = await _stampOverlay(photo, overlay);
    try {
      final byteData = await composed.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        debugPrint('Screenshot encode failed');
        return null;
      }
      final dest = File('$directory/screenshot$stamp.png');
      await dest.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      return dest.path;
    } finally {
      composed.dispose();
    }
  }

  Future<ui.Image> _stampOverlay(ui.Image photo, ui.Image overlay) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(photo, Offset.zero, Paint());
    final width = photo.width.toDouble();
    final scale = width / overlay.width;
    final height = overlay.height * scale;
    canvas.drawImageRect(
      overlay,
      Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
      Rect.fromLTWH(0, photo.height - height, width, height),
      Paint(),
    );
    final picture = recorder.endRecording();
    return picture
        .toImage(photo.width, photo.height)
        .whenComplete(picture.dispose);
  }

  bool _movedEnoughForGeocode(Position position) {
    final last = _lastGeocoded;
    if (last == null) {
      return true;
    }
    return Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        ) >=
        _geocodeMinDistanceMeters;
  }

  Future<void> _startLocationUpdates() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (_disposed) {
        return;
      }
      if (!serviceEnabled) {
        _showLocationError();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (_disposed) {
        return;
      }
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (_disposed) {
          return;
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationError();
        return;
      }

      final settings = _locationSettings();
      final last = await Geolocator.getLastKnownPosition();
      if (_disposed) {
        return;
      }
      if (last != null) {
        _onPosition(last);
      }

      _positionSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            _onPosition,
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Location update failed: $error\n$stackTrace');
              _showLocationError();
            },
          );
      if (_disposed) {
        await _positionSub?.cancel();
        _positionSub = null;
        return;
      }

      if (last != null) {
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: _locationAccuracy,
          timeLimit: _oneShotFixLimit,
        ),
      );
      if (_disposed) {
        return;
      }
      _onPosition(current);
    } on Exception catch (e, st) {
      debugPrint('Location update failed: $e\n$st');
      _showLocationError();
    }
  }

  void _onPosition(Position position) {
    if (_disposed) {
      return;
    }
    _markerFeed.add(position);
    _mapCenter.value ??= lat.LatLng(position.latitude, position.longitude);
    _queuedPosition = position;
    if (_geocodeBusy) {
      return;
    }
    unawaited(_drainGeocode());
  }

  Future<void> _drainGeocode() async {
    _geocodeBusy = true;
    try {
      while (!_disposed && _queuedPosition != null) {
        final position = _queuedPosition!;
        _queuedPosition = null;
        await _applyGeocode(position);
      }
    } finally {
      _geocodeBusy = false;
      if (!_disposed && _queuedPosition != null) {
        unawaited(_drainGeocode());
      }
    }
  }

  Future<void> _applyGeocode(Position position) async {
    if (_disposed) {
      return;
    }
    try {
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
        if (_disposed) {
          return;
        }
        if (placeMarks.isEmpty) {
          next = LocationData.unavailable('No Location Data');
        } else {
          next = LocationData.fromPlacemark(
            latitude: position.latitude,
            longitude: position.longitude,
            placeMark: placeMarks.first,
          );
        }
        _lastGeocoded = lat.LatLng(position.latitude, position.longitude);
        _cachedGeocodeData = next;
      }

      if (next == _overlay.value.locationData) {
        return;
      }

      _updateOverlay(locationData: next, dateTime: _formatNow());
    } on Exception catch (e, st) {
      debugPrint('Location update failed: $e\n$st');
      _showLocationError();
    }
  }
}

class _LiveMap extends StatefulWidget {
  const _LiveMap({required this.initialCenter, required this.positionStream});

  final lat.LatLng initialCenter;
  final Stream<LocationMarkerPosition?> positionStream;

  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  static final Stream<LocationMarkerHeading?> _noHeading =
      Stream<LocationMarkerHeading?>.multi((_) {});

  final NetworkTileProvider _tiles = NetworkTileProvider(
    abortObsoleteRequests: true,
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      overrideFreshAge: const Duration(days: 30),
    ),
  );

  static const _mapFlags =
      InteractiveFlag.drag |
      InteractiveFlag.pinchMove |
      InteractiveFlag.pinchZoom;

  static const _markerStyle = LocationMarkerStyle(
    showHeadingSector: false,
    showAccuracyCircle: false,
  );

  static const _snap = Duration(microseconds: 1);

  AlignOnUpdate _follow = AlignOnUpdate.always;
  var _followChangeScheduled = false;

  void _stopFollowing() {
    if (_follow == AlignOnUpdate.never || _followChangeScheduled) {
      return;
    }
    _followChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _follow = AlignOnUpdate.never);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: 13,
          minZoom: 12,
          maxZoom: 16,
          interactionOptions: const InteractionOptions(flags: _mapFlags),
          onPositionChanged: (position, hasGesture) {
            if (hasGesture) {
              _stopFollowing();
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
            tileProvider: _tiles,
            minZoom: 12,
            keepBuffer: 0,
            panBuffer: 0,
          ),
          CurrentLocationLayer(
            positionStream: widget.positionStream,
            headingStream: _noHeading,
            style: _markerStyle,
            alignPositionOnUpdate: _follow,
            alignPositionAnimationDuration: _snap,
            moveAnimationDuration: _snap,
          ),
        ],
      ),
    );
  }
}
