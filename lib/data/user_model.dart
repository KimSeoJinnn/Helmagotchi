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

  // [4주차: 데이터 영속성] 기기에 저장된 JSON을 다시 객체로 불러오는 생성자
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['u_id'], // [4주차: 최적화] 키 이름을 짧게 줄여 저장 용량 최적화
      level: json['lvl'],
      currentExp: json['exp'],
      totalSquatCount: json['sqt_cnt'] ?? 0,
      unlockedTitles: List<String>.from(json['titles'] ?? []),
    );
  }

  // [4주차: JSON 구조 정리] 로컬 저장용 데이터 변환
  Map<String, dynamic> toJson() => {
    'u_id': uid,
    'lvl': level,
    'exp': currentExp,
    'sqt_cnt': totalSquatCount,
    'titles': unlockedTitles,
  };
}

// [3주차: 칭호 데이터 정의 및 체크 함수]
// BE2 역할인 '게임 로직 파이프라인 연결'을 위해 필요합니다.
void checkAndGrantTitles(UserModel user) {
  // 3주차: 칭호 획득 조건 체크 로직
  if (user.totalSquatCount >= 100 &&
      !user.unlockedTitles.contains('squat_king')) {
    user.unlockedTitles.add('squat_king'); // '하체의 왕' 칭호 부여
  }
}
