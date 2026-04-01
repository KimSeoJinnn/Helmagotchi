import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseResult {
  final double? leftKneeAngle;
  final double? rightKneeAngle;
  final double? leftHipAngle;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final double confidence;

  const PoseResult({
    required this.leftKneeAngle,
    required this.rightKneeAngle,
    required this.leftHipAngle,
    required this.landmarks,
    required this.confidence,
  });

  bool get isValid => confidence > 0.6;
}