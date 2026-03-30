import 'models/user_model.dart';
import '../core/workout_data.dart';

class ExpService {
  static const int squatExp = 10;
  static const int pushupExp = 12;
  static const int situpExp = 8;

  void addExpByWorkout(UserModel user, WorkoutType type) {
    int gainedExp = _calculateExp(type);
    user.currentExp += gainedExp;

    while (user.currentExp >= _requiredExpForNextLevel(user.level)) {
      user.currentExp -= _requiredExpForNextLevel(user.level);
      user.level++;
    }
  }

  int _calculateExp(WorkoutType type) {
    switch (type) {
      case WorkoutType.squat:
        return squatExp;
      case WorkoutType.pushup:
        return pushupExp;
      case WorkoutType.situp:
        return situpExp;
    }
  }

  int _requiredExpForNextLevel(int level) {
    return level * 100;
  }
}