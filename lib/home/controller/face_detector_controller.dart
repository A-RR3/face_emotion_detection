import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../module/face_model.dart';

class FaceDetetorController {
  final FaceDetector _faceDetector;

  FaceDetetorController()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableLandmarks: true,
            enableContours: true,
          ),
        );

  Future<List<FaceModel>?> detectFaces(InputImage inputImage) async {
    print('now detecting---');
    final faces = await _faceDetector.processImage(inputImage);
    if (faces == null || faces.isEmpty) {
      print('No faces detected.');
      return null;
    }
    print('faces: $faces');
    return extractFaceInfo(faces);
  }

  List<FaceModel>? extractFaceInfo(List<Face>? faces) {
    List<FaceModel>? response = [];
    double? smile;
    double? leftYears;
    double? rightYears;

    for (Face face in faces!) {
      final rect = face.boundingBox;
      if (face.smilingProbability != null) {
        smile = face.smilingProbability;
      }

      leftYears = face.leftEyeOpenProbability;
      rightYears = face.rightEyeOpenProbability;

      final faceModel = FaceModel(
        smile: smile,
        leftYearsOpen: leftYears,
        rightYearsOpen: rightYears,
      );

      response.add(faceModel);
    }

    return response;
  }

  void dispose() {
    _faceDetector.close();
  }
}
