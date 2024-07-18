import 'package:camera/camera.dart';
import 'package:face_emotion_detector/home/controller/face_detector_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:provider/provider.dart';
import 'face_detection_page.dart';

// List<CameraDescription> cameras = [];

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: FaceDetectionPage(),
    );
  }
}
