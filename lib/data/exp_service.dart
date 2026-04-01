import 'models/user_model.dart';
import '../core/workout_data.dart';

class ExpService {
  static const int squatExp = 2;
  static const int pushupExp = 3;
  static const int situpExp = 2;

  UserModel addExpByWorkout(UserModel user, WorkoutType type, int count) {
    int gainedExp = _calculateExp(type, count);
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

  int _calculateExp(WorkoutType type, int count) {
    switch (type) {
      case WorkoutType.squat:
        return squatExp * count;
      case WorkoutType.pushup:
        return pushupExp * count;
      case WorkoutType.situp:
        return situpExp * count;
    }
  }

  int _requiredExpForNextLevel(int level) {
    return level * 100;
  }
}