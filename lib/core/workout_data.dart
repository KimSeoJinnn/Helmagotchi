// lib/core/workout_data.dart
enum WorkoutType { squat, pushup, situp }

class WorkoutEvent {
  final WorkoutType type; // 운동 종류 (스쿼트, 팔굽 등)
  final DateTime timestamp; // 발생 시간

  WorkoutEvent({
    required this.type, 
    required this.timestamp
  });
}