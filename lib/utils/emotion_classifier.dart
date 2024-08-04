import 'package:tflite_flutter/tflite_flutter.dart';

class EmotionClassifier {
  late Interpreter _interpreter;

  EmotionClassifier() {
    _loadModel();
  }

  void _loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/face_expression_model.tflite');
      print("Model loaded successfully");
    } catch (e) {
      print("Error loading model: $e");
    }
  }


//chatgpt
//   imglib.Image _convertYUV420(CameraImage image) {
//     var img = imglib.Image(
//       width: image.width,
//       height: image.height,
//     ); // Create Image buffer
//
//     final int width = image.width;
//     final int height = image.height;
//     final int uvRowStride = image.planes[1].bytesPerRow;
//     final int? uvPixelStride = image.planes[1].bytesPerPixel;
//     const shift = (0xFF << 24);
//
//     for (int x = 0; x < width; x++) {
//       for (int y = 0; y < height; y++) {
//         final int uvIndex =
//             uvPixelStride! * (x / 2).floor() + uvRowStride * (y / 2).floor();
//         final int index = y * width + x;
//
//         final yp = image.planes[0].bytes[index];
//         final up = image.planes[1].bytes[uvIndex];
//         final vp = image.planes[2].bytes[uvIndex];
//         // Calculate pixel color
//         int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
//         int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
//             .round()
//             .clamp(0, 255);
//         int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
//         // color: 0x FF  FF  FF  FF
//         //           A   B   G   R
//         img.data?[index] = shift | (b << 16) | (g << 8) | r;
//       }
//     }
//
//     return img;
//   }
/**
 * void processCameraImage(CameraImage cameraImage) async {
    // get image format
    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
    print('image format: $format');
    // final WriteBuffer allBytes = WriteBuffer();
    // for (final Plane plane in cameraImage.planes) {
    //   allBytes.putUint8List(plane.bytes);
    // }
    // final bytes = allBytes.done().buffer;
    //
    // Uint8List imageBytes =
    //     Uint8List.sublistView(allBytes.done().buffer.asUint8List());
    // print(imageBytes.length); // Ensure this gives you the correct byte length
    // if (imageBytes.lengthInBytes != 153600) {
    //   // Adjust the byte size to exactly 153600 by resizing or truncating
    //   imageBytes = Uint8List.fromList(imageBytes.sublist(0, 153600));
    // }
    // final ByteBuffer byteBuffer = imageBytes.buffer;
    // print(byteBuffer);
    // print(cameraImage.width);
    // print(cameraImage.height);

    final int width = cameraImage.width;
    final int height = cameraImage.height;

    // Debug prints
    print('Width: $width');
    print('Height: $height');
    // Extract the Y (luminance) plane data for grayscale conversion
    final Plane yPlane = cameraImage.planes[0];
    final Uint8List yBytes = yPlane.bytes;

    // Debug prints
    print('Y Plane bytes length: ${yBytes.length}');
    print('Expected length: ${width * height}');

    // if (yBytes.length != width * height) {
    //   throw Exception('Invalid byte array length for grayscale image');
    // }

    final WriteBuffer allBytes = WriteBuffer();
    // for (final Plane plane in cameraImage.planes) {
    //   allBytes.putUint8List(plane.bytes);
    // }
    allBytes.putUint8List(yPlane.bytes);
    final bytes = allBytes.done().buffer.asUint8List();

    // Debug prints
    // print('Bytes length: ${bytes.length}');
    // print('Expected length: ${width * height}');

    // if (bytes.length != width * height) {
    //   throw Exception('Invalid byte array length for grayscale image');
    // }

    // Ensure the byte array length matches the expected length
    final Uint8List adjustedYBytes = bytes.length > width * height
    ? bytes.sublist(0, width * height)
    : bytes;

    // Debug prints for adjusted bytes
    print('Adjusted Y Plane bytes length: ${adjustedYBytes.length}');

    if (adjustedYBytes.length != width * height) {
    throw Exception('Invalid byte array length for grayscale image');
    }

    final ByteBuffer byteBuffer = adjustedYBytes.buffer;
    print('byteBuffer${adjustedYBytes.lengthInBytes}');

    final img.Image image = img.Image.fromBytes(
    width: cameraImage.width,
    height: cameraImage.height,
    bytes: byteBuffer,
    format: img.Format
    .uint8 //each pixel is an 8-bit unsigned integer, suitable for grayscale images.
    );

    img.Image resizedImage = img.copyResize(image, width: 45, height: 45);
    img.Image grayscaleImage = img.grayscale(resizedImage);

    // Convert image to a Float32List for input to the TFLite model

    // each pixel value should be represented as a 32-bit floating-point number.in TensorFlow Lite models
    final input = Float32List(48 * 48);

    for (int i = 0; i < 48; i++) {
    for (int j = 0; j < 48; j++) {
    img.Pixel pixelValue = grayscaleImage.getPixel(j, i);
    num normalized = img.getLuminanceNormalized(pixelValue);
    input[i * 48 + j] = normalized / 255.0; // Normalize to [0, 1]
    }
    }

    // Load the TFLite model
    // final interpreter = await Interpreter.fromAsset('model.tflite');

    // Allocate output buffer
    final output = List.filled(1 * 7, 0).reshape([1, 7]);

    // Run the inference
    _interpreter.run(input.reshape([1, 48, 48, 1]), output);

    // Process the output (example: get the label with the highest probability)
    final int labelIndex =
    output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));
    print('Predicted label: $labelIndex');
    // _predict(inputBytes);
    }
 *
  void _predict(Uint8List input) {
    var inputShape = _interpreter.getInputTensor(0).shape;
    var outputShape = _interpreter.getOutputTensor(0).shape;

    var inputTensor =
        List.generate(inputShape.reduce((a, b) => a * b), (_) => 0.0);
    var outputTensor =
        List.generate(outputShape.reduce((a, b) => a * b), (_) => 0.0);

    inputTensor.setAll(0, input.map((e) => e / 255.0));

    _interpreter.run(inputTensor, outputTensor);

    // Process the output as needed
    print("Predicted Emotion: $outputTensor");
  }
**/

  void closeInterpreter() {
    _interpreter.close();
  }
}
