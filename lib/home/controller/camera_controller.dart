import 'dart:io';
import 'package:camera/camera.dart';

class CameraManager {
  List<CameraDescription>? cameras;
  CameraController? _controller;

  Future<CameraController?> load() async {
    try {
      cameras = await availableCameras();

      //Set front camera if available or back if not available
      int position = cameras!.isNotEmpty ? 1 : 0;
      _controller = CameraController(
        cameras![position],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 // for Android
            : ImageFormatGroup.bgra8888,
      );
      await _controller?.initialize();
      return _controller;
    } catch (e) {
      print('Error initializing camera: $e');
    }
    return null;
  }

  CameraController? get controller => _controller;
}
