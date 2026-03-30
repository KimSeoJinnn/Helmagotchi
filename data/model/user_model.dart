// lib/data/models/user_model.dart
class UserModel {
  final String uid;
  int level;
  int currentExp;
  List<String> unlockedTitles;

  UserModel({
    required this.uid,
    this.level = 1,
    this.currentExp = 0,
    this.unlockedTitles = const [],
  });

  // 서버 및 로컬 저장소 연동을 위한 변환 로직
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'level': level,
    'currentExp': currentExp,
    'unlockedTitles': unlockedTitles,
  };
}