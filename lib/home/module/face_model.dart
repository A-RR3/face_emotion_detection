import 'dart:ui';

class FaceModel {
  double? smile;
  double? rightEyesOpenOpen;
  double? leftEyesOpenOpen;
  bool? isTeethVisible;
  Rect? boundingBox;

  FaceModel(
      {this.smile,
      this.rightEyesOpenOpen,
      this.leftEyesOpenOpen,
      this.isTeethVisible,
      this.boundingBox});
}
