import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector;

  FaceDetectorService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
              enableClassification: true,
              enableLandmarks: false,
              enableContours: false,
              enableTracking: false,
              minFaceSize: 0.1,
              performanceMode: FaceDetectorMode.accurate),
        );

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  void dispose() {
    _faceDetector.close();
  }
}
