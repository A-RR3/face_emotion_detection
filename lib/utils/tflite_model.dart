import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class TFLiteModel {
  late Interpreter _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;
  late List<dynamic> _output;
  String emotion = 'Unknown';
  late TfLiteType inputType;
  late TfLiteType outputType;

  TFLiteModel() {
    loadModel();
  }

  Interpreter get interpreter => _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/face_expression_model.tflite',
          options: InterpreterOptions()..threads = 4);
      _interpreter.allocateTensors();
      _prepareModelInfo();
    } catch (e) {
      print("Error while creating interpreter: $e");
    }
  }

  void _prepareModelInfo() {
    //model information
    _inputShape = _interpreter.getInputTensor(0).shape;
    _outputShape = _interpreter.getOutputTensor(0).shape;
    print('Input shape: $_inputShape'); //Input shape: [1, 48, 48, 1]
    print('Output shape: $_outputShape'); //Output shape: [1, 7]
    // #3

    final inputType = _interpreter.getInputTensor(0).type;
    final outputType = _interpreter.getOutputTensor(0).type;

    print('Input type: $inputType'); //Input type: float32
    print('Output type: $outputType'); // float32

    // Output container
    _output = Float32List(1 * 7).reshape([1, 7]);

    // final output1 = List.filled(7, 0.0).reshape([1, 7]);
    // print(output1);
    // final output2 = List.filled(
    //     _outputShape.reduce((value, element) => value * element), 0);
    // var output3 = List.filled(1 * 7, 0).reshape([1, 7]);
  }

  void runModel(Float32List inputBytes) {
    final input = inputBytes.reshape([1, 48, 48, 1]);
    print('output----$_output');
    _interpreter.run(input, _output);

    print(_output[0]);
    final predictionResult = _output[0] as List<double>;
    // Find the index with the highest probability
    final maxIndex = predictionResult.indexWhere((e) =>
        e ==
        predictionResult.reduce((curr, next) => curr > next ? curr : next));
    final emotionIndex = predictionResult[maxIndex];

    //.fold( 0, max);

    emotion = _getEmotionFromIndex(emotionIndex);
  }

  String _getEmotionFromIndex(num index) {
    switch (index) {
      case 0:
        return 'Angry';
      case 1:
        return 'Disgusted';
      case 2:
        return 'Fearful';
      case 3:
        return 'Happy';
      case 4:
        return 'Sad';
      case 5:
        return 'Neutral';
      case 6:
        return 'Surprised';
      default:
        return 'Unknown';
    }
  }

  void closeInterpreter() {
    _interpreter.close();
  }
}
