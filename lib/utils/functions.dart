import 'dart:io';
import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class Functions {
  static void logInputImageDetails(InputImage inputImage) {
    print(inputImage.type); //InputImageType.bytes
    print(inputImage.bytes);
    // saveImageBytesToFile(inputImage.bytes!);
    print(inputImage.metadata?.bytesPerRow); //720
    print(inputImage.metadata?.size); //Size(720.0, 480.0)
    print(inputImage.metadata?.format); //InputImageFormat.nv21
    print(inputImage.filePath); //null
  }

  static Uint8List convertYUV420ToNV21(CameraImage image) {
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

  static InputImage? inputImageFromCameraImage(CameraImage image,
      CameraDescription camera, CameraController? cameraController) {
    final sensorOrientation = camera.sensorOrientation;

    //camera image width and height
    final int width = image.width;
    final int height = image.height;
    print('CameraImage Width: $width'); //720
    print('CameraImage Height: $height'); //480

    final Plane yPlane = image.planes[0];
    final Uint8List yBytes = yPlane.bytes;
    print('Y Plane bytes length: ${yBytes.length}'); //345600//368592
    print('Expected length: ${width * height}'); //345600 //345600

    if (yBytes.length != width * height) {
      // throw Exception('Invalid byte array length for grayscale image');
    }

    // Check for padding
    final int bytesPerRow = yPlane.bytesPerRow;
    final int? bytesPerP = yPlane.bytesPerPixel;
    print('bytesPerRow: $bytesPerRow'); //720//768
    print('bytesPerPixel: $bytesPerP'); //bytesPerPixel: 1

    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          orientations[cameraController!.value.deviceOrientation];
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
    // final plane = image.planes.first;//y plane

    print('${image.planes.length}');
    if (Platform.isAndroid && image.planes.length > 1) {
      print('converting image');
      final nv21Bytes = convertYUV420ToNV21(image);
      print('3 planes nv21Bytes length : ${nv21Bytes.length}'); //115200
      print('here--1');
      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: yPlane.bytesPerRow, //image.width,
        ),
      );
    } else if (Platform.isIOS && format == InputImageFormat.bgra8888) {
      // iOS doesn't need conversion if format is already bgra8888
      return InputImage.fromBytes(
        bytes: yPlane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format!,
          bytesPerRow: yPlane.bytesPerRow,
        ),
      );
    }
    print(
        '${image.width.toDouble()}//${image.height.toDouble()}//$rotation//$format//${yPlane.bytesPerRow}');
    print('here--2');
    return InputImage.fromBytes(
      bytes: yPlane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format!, // used only in iOS
        bytesPerRow: yPlane.bytesPerRow, // used only in iOS
      ),
    );

    // compose InputImage using bytes
  }

  Future<List<int>?> convertImagetoPng(CameraImage image) async {
    try {
      imglib.Image img;
      print(image.format.group);

      img = convertYUV420ToImage(image);

      imglib.PngEncoder pngEncoder = imglib.PngEncoder();

      // Convert to png
      List<int> png = pngEncoder.encode(img);
      //Uint8List.fromList(png);
      return png;
    } catch (e) {
      print(">>>>>>>>>>>> ERROR:$e");
    }
    return null;
  }

// https://gist.github.com/Alby-o/fe87e35bc21d534c8220aed7df028e03
  static imglib.Image convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final imglib.Image img = imglib.Image(width: width, height: height);

    final plane0 = cameraImage.planes[0];
    final plane1 = cameraImage.planes[1];
    final plane2 = cameraImage.planes[2];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            (y >> 1) * plane1.bytesPerRow + (x >> 1) * plane1.bytesPerPixel!;
        final int index = y * width + x;

        final int yValue = plane0.bytes[index];
        final int uValue = plane1.bytes[uvIndex] - 128;
        final int vValue = plane2.bytes[uvIndex] - 128;

        final int r = (yValue + vValue * 1.402).clamp(0, 255).toInt();
        final int g = (yValue - uValue * 0.344136 - vValue * 0.714136)
            .clamp(0, 255)
            .toInt();
        final int b = (yValue + uValue * 1.772).clamp(0, 255).toInt();
        img.setPixelRgb(x, y, r, g, b);
      }
    }

    return img;
  }

  static imglib.Image convertYUV420ToGrayscaleImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final imglib.Image grayscaleImage =
        imglib.Image(width: width, height: height, numChannels: 1);

    final plane0 = cameraImage.planes[0];

    // img.Pixel pixel = image.getPixel(x, y);
    // num luminance = img.getLuminance(pixel);
    // num grayscalePixel = img.getLuminance(pixel);
    //
    // grayscaleImage.setPixelRgb(
    //     x, y, grayscalePixel, grayscalePixel, grayscalePixel);
    //
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = y * width + x;
        final int yValue = plane0.bytes[index];
        // imglib.Pixel pixl = imglib.getPixel(x,y);
        //  num grayscaleColor = imglib.getLuminance(yValue);
        // grayscaleImage.setPixel(x, y, grayscaleColor);
      }
    }

    return grayscaleImage;
  }
}
