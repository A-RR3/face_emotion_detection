import 'dart:io';
import 'package:camera/camera.dart';
import 'package:face_emotion_detector/utils/services/face_detector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class FaceDetectionPage extends StatefulWidget {
  @override
  _FaceDetectionPageState createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  CameraController? _controller;
  bool _isDetecting = false;
  CameraDescription camera = cameras[1];

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  //camera zoom variables
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseZoomLevel = 1.0;

  //progress indicator variable
  double happinessPercentage = 0.5;
  double _previousPerc = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeCamera() async {
    //TargetPlatform.iOS/.Android?
    try {
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 // for Android
            : ImageFormatGroup.bgra8888,
      ); // for iOS
      await _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      setState(() {});
      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    print('1--');

    print('--------processing-------');
    print('camera image details ------------');
    print(image.height.toString());

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
      final faces =
          await Provider.of<FaceDetectorService>(context, listen: false)
              .detectFaces(inputImage!);
      print(inputImage.type); //InputImageType.bytes
      print(inputImage.bytes);
      print(inputImage.metadata?.bytesPerRow); //720
      print(inputImage.metadata?.size); //Size(720.0, 480.0)
      print(inputImage.metadata?.format); //InputImageFormat.nv21
      print(inputImage.filePath); //null
      print('4--');
      print(faces);
      print('detected');

      for (Face face in faces) {
        print('5--');
        final smilingProbability =
            face.smilingProbability ?? happinessPercentage;
        final double tenthDigitSmilingProp =
            (smilingProbability * 10).toInt() / 10;
        print('tenthDigitSmilingProp: $tenthDigitSmilingProp');
        final double? leftEyeOpen = face.leftEyeOpenProbability;
        final double? rightEyeOpen = face.rightEyeOpenProbability;

        print('smilingProp: $smilingProbability');
        print('leftEye: $leftEyeOpen rightEyeOpen: $rightEyeOpen');
        print('${(smilingProbability * 10).round()}');
        final happiness = (smilingProbability * 100).toStringAsFixed(2); //35.6
        final sadness = ((1 - smilingProbability) * 100).toStringAsFixed(2);

        if (tenthDigitSmilingProp > 0.2 && tenthDigitSmilingProp < .7) {
          happinessPercentage = .5;
        } else {
          //divide the line to 10
          int steps = 10;
          happinessPercentage = (smilingProbability * steps).round() / 10;
          print(happinessPercentage);
        }

        setState(() {});
        print('Happiness: $happiness');
        print('Sadness: $sadness');
      }
    } catch (e) {
      print('Error processing camera image: $e');
    }
    _isDetecting = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
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
    if (Platform.isAndroid && image.planes.length != 1) {
      print('ssssssssss');
      final nv21Bytes = _convertYUV420ToNV21(image);
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
    // print('Y plane bytes: ${image.planes[0].bytes}');
    // print('U plane bytes: ${image.planes[1].bytes}');
    // print('V plane bytes: ${image.planes[2].bytes}');

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

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = _currentZoomLevel;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _currentZoomLevel =
          (_baseZoomLevel * details.scale).clamp(_minZoomLevel, _maxZoomLevel);
      _controller?.setZoomLevel(_currentZoomLevel);
    });
  }

  // double _getDiscretePercentage(double percentage) {
  //   // Convert to discrete steps (e.g., 10% increments)
  //   int steps = 10;
  //   return (percentage * steps).round() / steps;
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        centerTitle: true,
      ),
      body: (_controller == null || !_controller!.value.isInitialized)
          ? Center(child: CircularProgressIndicator())
          : SizedBox.expand(
              child: Stack(
                children: [
                  GestureDetector(
                      onScaleStart: _handleScaleStart,
                      onScaleUpdate: _handleScaleUpdate,
                      child: Align(
                        alignment: Alignment.center,
                        child: CameraPreview(_controller!),
                      )),
                  Positioned(
                    top: 10,
                    child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: _previousPerc,
                            end: happinessPercentage,
                          ),
                          duration: Duration(milliseconds: 200),
                          builder: (context, value, child) =>
                              LinearPercentIndicator(
                            barRadius: Radius.circular(10),
                            width: MediaQuery.of(context).size.width / 1.3,
                            animation: true,
                            lineHeight: 20.0,
                            leading: Icon(
                              Icons.sentiment_dissatisfied_outlined,
                              color: Colors.red,
                            ),
                            trailing: Icon(
                              Icons.mood,
                              color: Colors.green,
                            ),
                            percent: value,
                            center: Text(""), //${happinessPercentage * 100}%
                            linearStrokeCap: LinearStrokeCap.round,
                            animateFromLastPercent: true,
                            clipLinearGradient: true,
                            linearGradient: LinearGradient(colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellowAccent,
                              Colors.green
                            ]),
                            onAnimationEnd: () {
                              _previousPerc = happinessPercentage;
                            },
                          ),
                        )),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 30,
                    child: Column(
                      children: [
                        Text('Zoom: ${_currentZoomLevel.toStringAsFixed(1)}x'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
