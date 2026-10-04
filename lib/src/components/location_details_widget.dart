import 'package:map_camera_flutter/map_camera_flutter.dart';

class LocationDetailsWidget extends StatelessWidget {
  const LocationDetailsWidget({
    super.key,
    required this.locationData,
    required this.dateTime,
  });

  final LocationData? locationData;
  final String dateTime;

  static const _panelDecoration = BoxDecoration(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    color: Color(0x80000000),
  );
  static const _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
  static const _detailStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(locationData?.locationName ?? "Loading...", _titleStyle),
          const SizedBox(height: 5),
          _line(locationData?.subLocation ?? "Loading ..", _detailStyle),
          const SizedBox(height: 5),
          _line("Lat ${locationData?.latitude ?? "Loading.."}", _detailStyle),
          const SizedBox(height: 5),
          _line("Long ${locationData?.longitude ?? "Loading.."}", _detailStyle),
          const SizedBox(height: 5),
          _line(dateTime, _detailStyle),
        ],
      ),
    );
  }

  Widget _line(String text, TextStyle style) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: style,
    );
  }
}
