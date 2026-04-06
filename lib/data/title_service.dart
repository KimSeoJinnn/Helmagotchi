import 'user_model.dart';
import 'title_model.dart';

class TitleService {
  final List<TitleModel> allTitles = const [
    TitleModel(name: "헬린이", description: "레벨 1 달성"),
    TitleModel(name: "초보 스쿼터", description: "누적 스쿼트 10회 달성"),
    TitleModel(name: "성장하는 헬린이", description: "레벨 3 달성"),
    TitleModel(name: "스쿼트 마스터", description: "누적 스쿼트 50회 달성"),
    TitleModel(name: "중급 헬창", description: "레벨 5 달성"),
    TitleModel(name: "전설의 하체왕", description: "누적 스쿼트 100회 달성"),
  ];

  List<TitleModel> getUnlockedTitles(UserModel user) {
    List<TitleModel> unlocked = [];

    if (user.level >= 1) {
      unlocked.add(allTitles[0]);
    }
    if (user.totalSquatCount >= 10) {
      unlocked.add(allTitles[1]);
    }
    if (user.level >= 3) {
      unlocked.add(allTitles[2]);
    }
    if (user.totalSquatCount >= 50) {
      unlocked.add(allTitles[3]);
    }
    if (user.level >= 5) {
      unlocked.add(allTitles[4]);
    }
    if (user.totalSquatCount >= 100) {
      unlocked.add(allTitles[5]);
    }

    return unlocked;
  }

  TitleModel? getLatestUnlockedTitle(UserModel user) {
    final unlocked = getUnlockedTitles(user);
    if (unlocked.isEmpty) return null;
    return unlocked.last;
  }
}