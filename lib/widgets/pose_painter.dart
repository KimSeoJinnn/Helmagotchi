import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isGoodForm;

  PosePainter(this.pose, this.imageSize, this.isGoodForm);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = isGoodForm ? Colors.greenAccent : Colors.orangeAccent;

    final double absoluteImageWidth = imageSize.width > imageSize.height ? imageSize.height : imageSize.width;
    final double absoluteImageHeight = imageSize.width > imageSize.height ? imageSize.width : imageSize.height;

    Offset translatePoint(double x, double y) {
      return Offset(size.width - (x * size.width / absoluteImageWidth), y * size.height / absoluteImageHeight);
    }

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = pose.landmarks[type1];
      final p2 = pose.landmarks[type2];
      if (p1 != null && p2 != null && p1.likelihood > 0.5 && p2.likelihood > 0.5) {
        canvas.drawLine(translatePoint(p1.x, p1.y), translatePoint(p2.x, p2.y), paint);
      }
    }

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}