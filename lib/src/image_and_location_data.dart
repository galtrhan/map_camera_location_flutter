import 'package:geocoding/geocoding.dart';

class ImageAndLocationData {
  final String? imagePath;
  final LocationData? locationData;
  String? get latitude => locationData?.latitude;
  String? get longitude => locationData?.longitude;
  String? get locationName => locationData?.locationName;
  String? get subLocation => locationData?.subLocation;

  ImageAndLocationData({
    required this.imagePath,
    required this.locationData,
  });

  @override
  String toString() =>
      'ImageAndLocationData(imagePath: $imagePath, latitude: $latitude, '
      'longitude: $longitude, locationName: $locationName, '
      'subLocation: $subLocation)';
}

class LocationData {
  static const unknownLocationName = 'Unknown location';

  final String? latitude;
  final String? longitude;
  final String? locationName;
  final String? subLocation;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.subLocation,
  });

  factory LocationData.unavailable(String locationName) => LocationData(
        latitude: null,
        longitude: null,
        locationName: locationName,
        subLocation: '',
      );

  /// Coordinates only. Place names stay null until geocoding finishes.
  factory LocationData.fromCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return LocationData(
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      locationName: null,
      subLocation: null,
    );
  }

  /// Coordinates with a soft-fail place name when geocoding finds nothing.
  factory LocationData.unknownPlace({
    required double latitude,
    required double longitude,
  }) {
    return LocationData(
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      locationName: unknownLocationName,
      subLocation: '',
    );
  }

  factory LocationData.fromPlacemark({
    required double latitude,
    required double longitude,
    required Placemark placeMark,
  }) {
    return LocationData(
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      locationName:
          '${placeMark.locality ?? ''}, ${placeMark.administrativeArea ?? ''}, ${placeMark.country ?? ''}',
      subLocation:
          '${placeMark.street ?? ''}, ${placeMark.thoroughfare ?? ''} ${placeMark.administrativeArea ?? ''}',
    );
  }

  LocationData withCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return LocationData(
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      locationName: locationName,
      subLocation: subLocation,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocationData &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        locationName == other.locationName &&
        subLocation == other.subLocation;
  }

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, locationName, subLocation);
}
