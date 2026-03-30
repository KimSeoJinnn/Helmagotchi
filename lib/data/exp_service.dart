import 'models/user_model.dart';
import '../core/workout_data.dart';

class ExpService {
  static const int squatExp = 10;
  static const int pushupExp = 12;
  static const int situpExp = 8;

  UserModel addExpByWorkout(UserModel user, WorkoutType type) {
    int gainedExp = _calculateExp(type);
    user.currentExp += gainedExp;

    int requiredExp = _requiredExpForNextLevel(user.level);

    while (user.currentExp >= requiredExp) {
      user.currentExp -= requiredExp;
      user.level++;
      print("레벨업! 현재 레벨: ${user.level}");
      requiredExp = _requiredExpForNextLevel(user.level);
    }

    return user;
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