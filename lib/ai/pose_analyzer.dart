import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../core/models/pose_result.dart';

class PoseAnalyzer {
  /// 세 관절 좌표로 꼭짓점(B)의 각도를 계산 (0~180도)
  /// atan2 방식 — acos보다 수치적으로 안정적
  static double? calculateAngle(
    PoseLandmark? a, // 위쪽 관절 (hip)
    PoseLandmark? b, // 꼭짓점   (knee) ← 각도 중심
    PoseLandmark? c, // 아래쪽 관절 (ankle)
  ) {
    if (a == null || b == null || c == null) return null;

    if (a.likelihood < 0.5 || b.likelihood < 0.5 || c.likelihood < 0.5) {
      return null;
    }

    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;

    final cross = (baX * bcY - baY * bcX).abs();
    final dot   = baX * bcX + baY * bcY;

    final radians = math.atan2(cross, dot);
    return radians * 180 / math.pi;
  }

  /// Pose → PoseResult 변환
  static PoseResult? analyze(Pose pose) {
    final lm = pose.landmarks;
    if (lm.isEmpty) return null;

    final leftKneeAngle = calculateAngle(
      lm[PoseLandmarkType.leftHip],
      lm[PoseLandmarkType.leftKnee],
      lm[PoseLandmarkType.leftAnkle],
    );

    final rightKneeAngle = calculateAngle(
      lm[PoseLandmarkType.rightHip],
      lm[PoseLandmarkType.rightKnee],
      lm[PoseLandmarkType.rightAnkle],
    );

    // 상체 숙임 감지용 고관절 각도
    final leftHipAngle = calculateAngle(
      lm[PoseLandmarkType.leftShoulder],
      lm[PoseLandmarkType.leftHip],
      lm[PoseLandmarkType.leftKnee],
    );

    final avgConfidence =
        lm.values.map((l) => l.likelihood).reduce((a, b) => a + b) /
        lm.length;

    return PoseResult(
      leftKneeAngle: leftKneeAngle,
      rightKneeAngle: rightKneeAngle,
      leftHipAngle: leftHipAngle,
      landmarks: lm,
      confidence: avgConfidence,
    );
  }
}