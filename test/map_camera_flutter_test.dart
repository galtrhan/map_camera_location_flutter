import 'package:flutter_test/flutter_test.dart';
import 'package:map_camera_flutter/map_camera_flutter.dart';

void main() {
  test('LocationData equality and factories', () {
    final a = LocationData(
      latitude: '1',
      longitude: '2',
      locationName: 'Riga',
      subLocation: 'Center',
    );
    final b = LocationData(
      latitude: '1',
      longitude: '2',
      locationName: 'Riga',
      subLocation: 'Center',
    );
    final c = LocationData.unavailable('No Location Data');
    final coords = LocationData.fromCoordinates(
      latitude: 56.9,
      longitude: 24.1,
    );
    final unknown = LocationData.unknownPlace(
      latitude: 56.9,
      longitude: 24.1,
    );
    final fromPlace = LocationData.fromPlacemark(
      latitude: 56.9,
      longitude: 24.1,
      placeMark: const Placemark(
        locality: 'Riga',
        administrativeArea: 'Riga',
        country: 'Latvia',
        street: 'Brivibas',
        thoroughfare: 'iela',
      ),
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
    expect(c.latitude, isNull);
    expect(c.subLocation, '');
    expect(coords.latitude, '56.9');
    expect(coords.locationName, isNull);
    expect(unknown.locationName, LocationData.unknownLocationName);
    expect(unknown.subLocation, '');
    expect(
      coords.withCoordinates(latitude: 57.0, longitude: 24.2).latitude,
      '57.0',
    );
    expect(fromPlace.locationName, contains('Riga'));
    expect(
      fromPlace.withCoordinates(latitude: 57.0, longitude: 24.2).latitude,
      '57.0',
    );
  });
}
