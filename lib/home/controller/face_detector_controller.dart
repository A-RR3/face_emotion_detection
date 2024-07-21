import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../module/face_model.dart';

class FaceDetetorController {
  final FaceDetector _faceDetector;

  FaceDetetorController()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
              enableClassification: true,
              enableLandmarks: true,
              enableContours: true,
              enableTracking: true,
              performanceMode: FaceDetectorMode.fast),
        );

  Future<List<FaceModel>?> detectFaces(InputImage inputImage) async {
    print('now detecting---');
    final faces = await _faceDetector.processImage(inputImage);
    if (faces == null || faces.isEmpty) {
      print('No faces detected.');
      return null;
    }
    print('faces: ${faces.first?.rightEyeOpenProbability}');
    List<FaceModel>? faceModels = extractFaceInfo(faces);
    print(faceModels?.first.smile);
    return faceModels;
  }

  static List<FaceModel>? extractFaceInfo(List<Face>? faces) {
    List<FaceModel>? response = [];
    double? smile;
    double? leftEyesOpen;
    double? rightEyesOpen;
    bool? isTeethVisible;

    for (Face face in faces!) {
      final rect = face.boundingBox;
      if (face.smilingProbability != null) {
        smile = face.smilingProbability;
      }

      bool isTeethVisible = isSmilingWithTeeth(face);

      leftEyesOpen = face.leftEyeOpenProbability;
      rightEyesOpen = face.rightEyeOpenProbability;

      final faceModel = FaceModel(
          smile: smile,
          leftEyesOpenOpen: leftEyesOpen,
          rightEyesOpenOpen: rightEyesOpen,
          isTeethVisible: isTeethVisible);

      response.add(faceModel);
    }

    return response;
  }

  static bool isSmilingWithTeeth(Face face) {
    var leftMouthCorner = face.landmarks[FaceLandmarkType.leftMouth];
    var rightMouthCorner = face.landmarks[FaceLandmarkType.rightMouth];
    var noseTip = face.landmarks[FaceLandmarkType.noseBase];

    // Calculate distance between mouth corners and nose tip
    var distance = sqrt(
        pow(leftMouthCorner!.position.x - rightMouthCorner!.position.x, 2) +
            pow(leftMouthCorner!.position.y - rightMouthCorner!.position.y, 2));

    // Check if distance is greater than threshold
    if (distance > 10) {
      // Check if teeth are visible
      var teethVisible = (distance /
              (leftMouthCorner!.position.x - rightMouthCorner!.position.x)) >
          0.5;

      // Return true if both conditions are met
      return teethVisible;
    }
    return false;
  }

  void dispose() {
    _faceDetector.close();
  }
}
