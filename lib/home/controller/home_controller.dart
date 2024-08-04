import 'package:camera/camera.dart';
import 'package:face_emotion_detector/utils/emotion_classifier.dart';
import 'package:face_emotion_detector/utils/functions.dart';
import 'package:face_emotion_detector/utils/tflite_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../module/face_model.dart';
import 'camera_controller.dart';
import 'face_detector_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class HomeController extends GetxController {
  CameraManager? _cameraManager;
  CameraController? cameraController;
  FaceDetetorController? _faceDetect;
  EmotionClassifier? _emotionClassifier;
  bool _isDetecting = false;
  List<FaceModel>? faces;
  int _frameCount = 0;
  TFLiteModel? _tfliteModel;

  //camera zoom variables
  double currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseZoomLevel = 1.0;

  //progress indicator variable
  double happinessPercentage = 0.5;
  double previousPerc = 0.0;

  Uint8List? imageData;

  final List<String> _labels = [
    "Angry",
    "Disgust",
    "Fear",
    "Happy",
    "Sad",
    "Surprise",
    "Neutral"
  ];

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final String _result = "";

  // HomeController() {
  //
  // }

  InputImageRotation? rotation;

  @override
  Future<void> onInit() async {
    _cameraManager = CameraManager();
    _faceDetect = FaceDetetorController();
    _emotionClassifier = EmotionClassifier();
    _tfliteModel = TFLiteModel();
    print('---------loaded interpreter-----');
    loadCamera().then((_) async {
      await startImageStream();
    });
    super.onInit();
  }

  @override
  void onClose() {
    cameraController?.dispose();
    _tfliteModel?.closeInterpreter();

    super.onClose();
  }

  // Future<void> loadTfliteModel() async {
  //   print('----start------');
  //   await _tfliteModel?.loadModel();
  //   print('loaded--------');
  // }

  Future<void> loadCamera() async {
    cameraController = await _cameraManager?.load();
    if (cameraController != null) {
      _minZoomLevel = await cameraController!.getMinZoomLevel();
      _maxZoomLevel = await cameraController!.getMaxZoomLevel();
    }
    update();
  }

  Future<void> startImageStream() async {
    await cameraController!.startImageStream(
      (image) async {
        if (!_isDetecting) {
          // _isDetecting = true;
          _frameCount++;
          print('----frameCount-------$_frameCount');
          if (_frameCount % 50 == 0) {
            print('-----------entered frame------');
            _frameCount = 0;
            Float32List? lists = await processCameraImage(
                image); //ImageFormatGroup.yuv420//height: 480//width: 720
            print('lists: ---\n $lists');
            Float32List? list = lists;
            if (list != null) {
              print('float list is not null');
              _tfliteModel?.runModel(list);
            }
            _isDetecting = false;
            // _processCameraImage(image);
          }
        }
      },
    );
  }

  Future<Float32List?> processCameraImage(CameraImage cameraImage) async {
    // if (_isDetecting) return null;
    _isDetecting = true;

    CameraDescription camera = cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    var rotationCompensation =
        _orientations[cameraController!.value.deviceOrientation];
    print(sensorOrientation); //270
    print(rotationCompensation); //0

    if (rotationCompensation == null) {
      throw Exception('sensor orientation is null ');
    }

    if (camera.lensDirection == CameraLensDirection.front) {
      // front-facing
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // back-facing
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    print(rotationCompensation); //270

    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    print('image rotation: $rotation'); //InputImageRotation.rotation270deg

    // get image format
    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
    print('image format: $format'); //InputImageFormat.yuv_420_888

    Face? face = await detectFaces(cameraImage); //
    if (face == null) {
      // throw Exception('No face is Detected');
    }

    final img.Image resizedFace;

    final croppedFace = cropFaceRegion(cameraImage, face!,
        rotationCompensation); // Image(287,236,uint8,channels:3)  data size 203196
    final grayscaleFace = convertToSingleChannelGrayscale(croppedFace);
    // final grayscaleFace = convertToGrayscale(croppedFace);

    resizedFace = resizeImage(grayscaleFace);
    /////////////////////////////////////////////////
    // Function to convert img.Image to Uint8List
    Uint8List convertImageToUint8List(img.Image image) {
      return Uint8List.fromList(img.encodePng(image));
    }

    imageData = convertImageToUint8List(resizedFace);
    update();

    ////////////////////////////////////////////////////////

    print('Resized face size: ${resizedFace.width} x ${resizedFace.height}');

    // final WriteBuffer allBytes = WriteBuffer();

    // for (final Plane plane in cameraImage.planes) {
    //   allBytes.putUint8List(plane.bytes);
    // }

    // allBytes.putUint8List(yPlane.bytes);

    // final bytes =
    //     allBytes.done().buffer.asUint8List(); //.asUint8List(0, width * height);

    // Ensure the byte array length matches the expected length
    // final Uint8List adjustedYBytes = bytes.length > width * height
    //     ? bytes.sublist(0, width * height)
    //     : bytes;

    // Debug prints for adjusted bytes
    //print('Adjusted Y Plane bytes length: ${adjustedYBytes.length}'); 76800

    // if (adjustedYBytes.length != width * height) {
    //   throw Exception('Invalid byte array length for grayscale image');
    // }

    // final ByteBuffer byteBuffer = bytes.buffer;
    //
    // // final ByteBuffer byteBuffer = adjustedYBytes.buffer.asUint8List(0, width * height).buffer;
    //
    // print(
    //     'adjustedYBytes.buffer length: ${byteBuffer.lengthInBytes}'); // 76800 / 76835
    // print(
    //     'adjustedYBytes.buffer type: ${byteBuffer.runtimeType}'); //_ByteBuffer
    //
    try {
      //   final img.Image image = img.Image.fromBytes(
      //       width: cameraImage.width,
      //       height: cameraImage.height,
      //       bytes: byteBuffer,
      //       format: img.Format
      //           .uint8 //each pixel is an 8-bit unsigned integer, suitable for grayscale images.
      //       );

      // img.Image resizedImage = img.copyResize(image, width: 45, height: 45);
      // img.Image grayscaleImage = img.grayscale(resizedImage);

      // Convert image to a Float32List for input to the TFLite model
      // Float32List inputBytes = Float32List(1 * 48 * 48 * 1);
      // int pixelIndex = 0;

      // each pixel value should be represented as a 32-bit floating-point number.in TensorFlow Lite models
      // for (int i = 0; i < 48; i++) {
      //   for (int j = 0; j < 48; j++) {
      //     img.Pixel? pixelValue = resizedFace?.getPixel(j, i);
      //     num normalized = img.getLuminanceNormalized(pixelValue);
      //     input[i * 48 + j] = normalized / 255.0; // Normalize to [0, 1]
      //   }
      // }
      print('resized face: ${resizedFace.data!.numChannels}');
      print('resized face: ${resizedFace.data!.first}');
      print('resized face: ${resizedFace.buffer}');
      print('resized face: ${resizedFace.first}');
      Float32List? normalizedPixels = Float32List(48 * 48);

      int index = 0;
      for (int y = 0; y < resizedFace.height; y++) {
        for (int x = 0; x < resizedFace.width; x++) {
          img.Pixel? pixel = resizedFace.getPixel(x, y);
          // Get the luminance value of the pixel
          //only need to normalize the single luminance channel.(since gray scale)
          double normalizedPixel =
              img.getLuminance(pixel) / 255.0; //img.getLuminanceNormalized
          // normalizedPixels[y * 48 + x] = normalizedPixel;
          normalizedPixels[index++] = normalizedPixel;
        }
      }
          print('----------------Image successfully created---------------');
      return normalizedPixels;
    } catch (e) {
      print('Error creating image: $e');
    }
    return null;

    // Allocate output buffer
    // final output = List.filled(1 * 7, 0).reshape([1, 7]);
    //
    // // Run the inference
    // _interpreter.run(input.reshape([1, 48, 48, 1]), output);

    // Process the output (example: get the label with the highest probability)
    // final int labelIndex =
    // output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));
    // print('Predicted label: $labelIndex');
    // _predict(inputBytes);
    // _isDetecting = false;
  }

  Future<Face?> detectFaces(CameraImage cameraImage) async {
    // _isDetecting= true;

    print('--------start detecting faces-------');
    print('image planes size: ${cameraImage.planes.length}'); //3

    try {
      CameraDescription camera = cameraController!.description;

// -------convert to input image-----
      final inputImage = Functions.inputImageFromCameraImage(
          cameraImage, camera, cameraController);
      print('2--'); //3 planes nv21Bytes length : 518400
      if (inputImage == null) {
        throw Exception('Failed to create InputImage.');
        // _isDetecting = false;
        return null;
      }
      // Log byte array after conversion
      print('InputImage bytes after: ${inputImage.bytes}');

      print('3--');
      print('---------- camera image details ------------');
      Functions.logInputImageDetails(inputImage); // Size(720.0, 480.0)

      Face? face = await _faceDetect?.detectFace(inputImage);
      if (face != null) {
        final Rect boundingBox = face.boundingBox;
        print('----boundingBox details height/width/size/type--------');
        print(boundingBox.height); //142
        print(boundingBox.width); //141
        print(boundingBox.size); //Size(142,141)
        print(boundingBox.runtimeType); //Rect

        // final croppedFace = cropFaceRegion(cameraImage, face);
        // final grayscaleFace = convertToGrayscale(croppedFace);
        // final resizedFace = resizeImage(grayscaleFace);

        return face;
      } else {
        return null;
        print('----ops-----Not face detected------');
      }

      print('4--  print faces length');
      // print(faces?.length);

      update();
    } catch (e) {
      print('Error detecting face in camera image: $e');
    }
    return null;
  }

  img.Image cropFaceRegion(
      CameraImage cameraImage, Face face, int rotationCompensation) {
    final img.Image originalImage = Functions.convertYUV420ToImage(cameraImage);
    final originalImageRotated =
        img.copyRotate(originalImage, angle: rotationCompensation);
    final boundingBox = face.boundingBox;

    return img.copyCrop(
      originalImageRotated,
      x: boundingBox.left.toInt(),
      y: boundingBox.top.toInt(),
      width: boundingBox.width.toInt(),
      height: boundingBox.height.toInt(),
    );
  }

  img.Image convertToSingleChannelGrayscale(img.Image image) {
    // img.Image singleChannelImage =
    //     img.Image(width: image.width, height: image.height, numChannels: 1);
    //
    // // Populate the single channel image
    // for (int y = 0; y < image.height; y++) {
    //   for (int x = 0; x < image.width; x++) {
    //     // Get the pixel from the grayscale (which currently has 3 channels)
    //     img.Pixel pixel = image.getPixel(x, y);
    //
    //     // Extract the luminance (since it's grayscale, all channels are the same)
    //     // num luminance = img.getLuminance(pixel);
    //     num luminance = img.getLuminanceRgb(pixel.r, pixel.g, pixel.b);
    //     // num luminance = img.getLuminanceNormalized(c);
    //
    //     // Create a Color object with the luminance value
    //     final intColor = ui.Color.fromRGBO(pixel.r.toInt(), pixel.g.toInt(),
    //             pixel.b.toInt(), pixel.a.toDouble())
    //         .value;
    //     // Set the luminance value in the single-channel image
    //     singleChannelImage.setPixelR(x, y, luminance);
    //   }
    // }
    // return singleChannelImage;
    img.Image grayscaleImage =
        img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        num luminance = img.getLuminance(pixel);
        num grayscalePixel = img.getLuminance(pixel);

        grayscaleImage.setPixelRgb(
            x, y, grayscalePixel, grayscalePixel, grayscalePixel);
      }
    }

    // Convert the image to a single channel

    return img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: grayscaleImage.getBytes().buffer);
  }

  img.Image convertToGrayscale(img.Image image) {
    return img.grayscale(image);
  }

  img.Image resizeImage(img.Image image) {
    return img.copyResize(image, width: 48, height: 48);
  }

  Uint8List generateBytes(
      int width, int height, int bytesPerRow, Plane yPlane) {
    bool hasPadding = bytesPerRow > width;
    print(hasPadding);

    Uint8List bytesList = Uint8List(width * height);

    // If there is padding, create a new byte array without padding
    if (hasPadding) {
      // Create a new buffer to store the image data without padding

      int bufferIndex = 0;
      for (int row = 0; row < height; row++) {
        // Copy each row excluding the padding

        bytesList.setRange(
          bufferIndex,
          bufferIndex + width,
          yPlane.bytes,
          row * bytesPerRow,
        );
        bufferIndex += width;
      }
    } else {
      // No padding, use the bytes directly
      bytesList = Uint8List.fromList(yPlane.bytes.sublist(0, width * height));
    }
    return bytesList;
  }

  /**
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;

    print('1--');

    print('--------processing-------');
    print('image.planes.length: ${image.planes.length}');

    _isDetecting = true;

    try {
      CameraDescription camera = cameraController!.description;

      final inputImage =
          Functions.inputImageFromCameraImage(image, camera, cameraController);
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
      Functions.logInputImageDetails(inputImage);

      List<FaceModel>? faces = await _faceDetect?.detectFaces(inputImage);
      print('4--');
      print(faces?.first.smile);
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
**/

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
    if (smileProb > 0.89) {
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
