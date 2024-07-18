import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../module/face_model.dart';
import 'camera_controller.dart';
import 'face_detector_controller.dart';

class HomeController extends GetxController {
  CameraManager? _cameraManager;
  CameraController? cameraController;
  FaceDetetorController? _faceDetect;
  bool _isDetecting = false;
  List<FaceModel>? faces;

  //camera zoom variables
  double currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseZoomLevel = 1.0;

  //progress indicator variable
  double happinessPercentage = 0.5;
  double previousPerc = 0.0;

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // HomeController() {
  //
  // }
  @override
  Future<void> onInit() async {
    _cameraManager = CameraManager();
    _faceDetect = FaceDetetorController();
    loadCamera().then((_) async {
      await startImageStream();
    });
    super.onInit();
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }

  Future<void> loadCamera() async {
    cameraController = await _cameraManager?.load();
    if (cameraController != null) {
      _minZoomLevel = await cameraController!.getMinZoomLevel();
      _maxZoomLevel = await cameraController!.getMaxZoomLevel();
    }
    update();
  }

  Future<void> startImageStream() async {
    await cameraController!.startImageStream(_processCameraImage);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    print('1--');

    print('--------processing-------');
    print('image.planes.length: ${image.planes.length}');

    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      print('2--');
      // if (inputImage == null) return;
      if (inputImage == null) {
        print('Failed to create InputImage.');
        _isDetecting = false;
        return;
      }
      // Log byte array after conversion
      // print('InputImage bytes after: ${inputImage.bytes}');

      print('3--');
      print('camera image details ------------');

      print(inputImage.type); //InputImageType.bytes
      print(inputImage.bytes);
      print(inputImage.metadata?.bytesPerRow); //720
      print(inputImage.metadata?.size); //Size(720.0, 480.0)
      print(inputImage.metadata?.format); //InputImageFormat.nv21
      print(inputImage.filePath); //null

      List<FaceModel>? faces = await _faceDetect?.detectFaces(inputImage);
      print('4--');
      print(faces);
      print('detected');

      if (faces != null && faces!.isNotEmpty) {
        FaceModel? face = faces?.first;
        detectSmile(face?.smile);
      } else {
        print('---------Not face detected------');
      }
      update();
    } catch (e) {
      print('Error processing camera image: $e');
      _isDetecting = false;
    }
    _isDetecting = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    CameraDescription camera = cameraController!.description;

    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    print('----------rotation: $rotation');
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    print('----------format: $format');
    final plane = image.planes.first;

    print('${image.planes.length}');
    if (Platform.isAndroid && image.planes.length > 1) {
      print('converting image');
      final nv21Bytes = _convertYUV420ToNV21(image);
      print('${nv21Bytes.length}');

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    } else if (Platform.isIOS && format == InputImageFormat.bgra8888) {
      // iOS doesn't need conversion if format is already bgra8888
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format!,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format!, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );

    // compose InputImage using bytes
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;

    final nv21Bytes = Uint8List(ySize + uvSize);
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    int index = 0;

    for (int i = 0; i < ySize; i++) {
      nv21Bytes[index++] = yPlane.bytes[i];
    }

    for (int i = 0; i < uvSize; i += 2) {
      nv21Bytes[index++] = vPlane.bytes[i];
      nv21Bytes[index++] = uPlane.bytes[i];
    }

    return nv21Bytes;
  }

  void handleScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = currentZoomLevel;
  }

  void handleScaleUpdate(ScaleUpdateDetails details) {
    currentZoomLevel =
        (_baseZoomLevel * details.scale).clamp(_minZoomLevel, _maxZoomLevel);
    cameraController?.setZoomLevel(currentZoomLevel);
    update();
  }

  void detectSmile(smileProb) {
    if (smileProb > 0.86) {
      happinessPercentage = 1.0;
      // return 'Big smile with teeth';
    } else if (smileProb > 0.8) {
      happinessPercentage = 0.8;
      // return 'Big Smile';
    } else if (smileProb > 0.3) {
      happinessPercentage = 0.45;
      // return 'Smile';
    } else {
      happinessPercentage = (smileProb * 10).floor() / 10;
      // return 'Sad';
    }
  }
}
