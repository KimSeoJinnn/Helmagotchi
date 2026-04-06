class UserModel {
  final String uid;
  int level;
  int currentExp;
  int totalSquatCount;
  List<String> unlockedTitles;

  UserModel({
    required this.uid,
    this.level = 1,
    this.currentExp = 0,
    this.totalSquatCount = 0,
    this.unlockedTitles = const [],
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'level': level,
    'currentExp': currentExp,
    'totalSquatCount': totalSquatCount,
    'unlockedTitles': unlockedTitles,
  };
}