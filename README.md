# map_camera_flutter

Flutter package that captures camera images with map and location data.

![Interface preview](assets/Screenshot_2.png)

## Features

- Capture images with the device camera and an attached map
- Read latitude, longitude, location name, and sub-location
- Pass a callback to receive the captured image and location data

## Install

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  map_camera_flutter: ^1.0.0
```

Import it:

```dart
import 'package:map_camera_flutter/map_camera_flutter.dart';
```

## Permissions

Add location permission to Android `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Also grant camera permission for your target platforms.

## Usage

```dart
MapCameraLocation(
  camera: yourCameraDescription,
  onImageCaptured: yourCallbackFunction,
)
```

`camera` is required. Get a `CameraDescription` from the `camera` package.

`onImageCaptured` is optional. Signature:

```dart
void yourCallbackFunction(ImageAndLocationData data) {
  // Use data.imagePath, latitude, longitude, locationName, subLocation
}
```

See `example/` for a full app.

## Development

Flutter SDK is pinned with FVM. After clone, run `fvm use`.

```bash
make get
make analyze
make test
make emulator-start
make run              # install+launch, then exit (Cursor-safe)
# make run-attach     # hot reload: use an external terminal
```

## License

MIT. See `LICENSE`.
