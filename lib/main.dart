import 'package:camera/camera.dart';
import 'package:face_emotion_detector/utils/services/face_detector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'face_detection_page.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FaceDetectorService>(create: (_) => FaceDetectorService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FaceDetectionPage(),
      ),
    );
  }
}
