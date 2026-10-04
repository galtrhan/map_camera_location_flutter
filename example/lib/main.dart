import 'package:map_camera_flutter/map_camera_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(camera: cameras.first));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Camera Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(
        title: 'Camera With Map Location',
        camera: camera,
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title, required this.camera});

  final CameraDescription camera;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: MapCameraLocation(
        camera: camera,
        onImageCaptured: (data) => debugPrint('$data'),
      ),
    );
  }
}
