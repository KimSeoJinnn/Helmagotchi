// lib/data/workout_service.dart
import '../core/workout_data.dart';

class WorkoutService {
  // AI 브랜치에서 운동 감지 시 이 함수를 호출하도록 가이드합니다.
  void handleMovement(WorkoutEvent event) {
    print("${event.type} 운동이 감지되었습니다. ");
    
    // TODO: 이준식(BE1) 님의 경험치 계산 함수 호출 연동
    // TODO: 4주차에 구현할 LocalStorage 저장 로직 연동
  }
}