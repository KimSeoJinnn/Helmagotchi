import '../../../core/models/pose_result.dart';

enum SquatPhase { standing, descending, bottom, ascending }

class SquatJudgement {
  final bool isGoodForm;
  final String? feedback;
  const SquatJudgement({required this.isGoodForm, this.feedback});
}

class SquatRepCounter {
  // 각도 임계값
  static const double _descendingEntry   = 130.0; // 내려가기 시작
  static const double _bottomThreshold   = 100.0; // 완전히 앉음
  static const double _standingThreshold = 160.0; // 서 있는 상태
  static const double _ascendingExit     = 155.0; // 올라와서 Rep 완료
  static const double _maxHipLeanAngle   = 70.0;  // 과도한 상체 숙임 경고

  SquatPhase _phase = SquatPhase.standing;
  int _reps = 0;
  SquatJudgement _lastJudgement = const SquatJudgement(isGoodForm: true);

  int get reps => _reps;
  SquatPhase get phase => _phase;
  SquatJudgement get lastJudgement => _lastJudgement;

  /// 매 프레임 호출 — 상태머신 업데이트
  void update(PoseResult result) {
    if (!result.isValid) return;

    // 좌우 무릎 각도 평균
    final kneeAngle = _average(result.leftKneeAngle, result.rightKneeAngle);
    if (kneeAngle == null) return;

    _lastJudgement = _judgeForm(result);

    switch (_phase) {
      case SquatPhase.standing:
        if (kneeAngle < _descendingEntry) {
          _phase = SquatPhase.descending;
        }

      case SquatPhase.descending:
        if (kneeAngle < _bottomThreshold) {
          _phase = SquatPhase.bottom;
        } else if (kneeAngle > _standingThreshold) {
          _phase = SquatPhase.standing; // 반동으로 취소
        }

      case SquatPhase.bottom:
        if (kneeAngle > _descendingEntry) {
          _phase = SquatPhase.ascending;
        }

      case SquatPhase.ascending:
        if (kneeAngle > _ascendingExit) {
          _phase = SquatPhase.standing;
          if (_lastJudgement.isGoodForm) {
            _reps++; // 정확한 자세일 때만 카운트
          }
        }
    }
  }

  SquatJudgement _judgeForm(PoseResult result) {
    final hipAngle = result.leftHipAngle;
    if (hipAngle != null && hipAngle < _maxHipLeanAngle) {
      return const SquatJudgement(
        isGoodForm: false,
        feedback: '상체를 너무 많이 숙이고 있어요',
      );
    }
    return const SquatJudgement(isGoodForm: true);
  }

  double? _average(double? a, double? b) {
    if (a != null && b != null) return (a + b) / 2;
    return a ?? b;
  }

  void reset() {
    _phase = SquatPhase.standing;
    _reps = 0;
  }
}