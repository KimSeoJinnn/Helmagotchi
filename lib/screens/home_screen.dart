import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/workout_data.dart';
import '../data/user_model.dart';
import '../data/exp_service.dart';
import '../data/workout_service.dart';
import '../data/title_service.dart';
import 'workout_screen.dart'; 

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> with SingleTickerProviderStateMixin {
  UserModel myUser = UserModel(uid: 'helma_test_01', level: 1, currentExp: 0);

  final ExpService _expService = ExpService();
  final TitleService _titleService = TitleService();

  int myTotalSquats = 0;
  int myBestSquats = 0;
  String? _selectedTitle;

  late AnimationController _idleController;
  late Animation<double> _idleAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedData(); 

    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _idleAnimation = Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(parent: _idleController, curve: Curves.easeInOut));
  }

  // 🚀 1. 스마트폰 메모장에서 내 기록 꺼내오기
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myTotalSquats = prefs.getInt('total_squats') ?? 0;
      myBestSquats = prefs.getInt('best_squats') ?? 0;
      myUser.level = prefs.getInt('user_level') ?? 1;
      myUser.currentExp = prefs.getInt('user_exp') ?? 0;
      _selectedTitle = prefs.getString('user_title');
    });
  }

  // 🚀 2. 0개, null 값 에러 방지 + 알림 없이 조용히 영구 저장하는 함수!
  Future<void> _saveCurrentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_squats', myTotalSquats);
      await prefs.setInt('best_squats', myBestSquats);
      await prefs.setInt('user_level', myUser.level); 
      await prefs.setInt('user_exp', myUser.currentExp); 
      
      if (_selectedTitle != null) {
        await prefs.setString('user_title', _selectedTitle!);
      }
      
      // 🤫 성공 알림(SnackBar)은 요청하신 대로 깔끔하게 지웠습니다!
      
    } catch (e) {
      // 혹시라도 기기 용량 부족 등으로 에러가 나면 빨간색으로 원인만 알려줍니다.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 저장 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  // 🚀 3. 순서를 완벽하게 맞춘 운동 완료 로직
  void _startWorkout(bool isRecordMode) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraWorkoutScreen(
          isRecordMode: isRecordMode,
          currentBestRecord: myBestSquats,
        ),
      )
    );

    if (result == null) return;
    int completedReps = result['reps'] ?? 0;
    if (completedReps == 0) return;

    int titlesCountBeforeWorkout = _titleService.getUnlockedTitles(myUser).length;

    // 🥇 1. [수정됨] 내 기록, 경험치를 모두 한 번에 UI에 업데이트!
    setState(() {
      myTotalSquats += completedReps;
      if (isRecordMode && completedReps > myBestSquats) {
        myBestSquats = completedReps;
      }
      
      // 경험치와 유저의 누적 횟수도 여기서 같이 올려줍니다!
      try {
        myUser.totalSquatCount += completedReps; 
        myUser = _expService.addExpByWorkout(myUser, WorkoutType.squat, completedReps);
      } catch (e) {
        print("경험치 계산 에러: $e");
      }
    });

    // 🥇 2. 모든 숫자가 올바르게 세팅된 후에 메모장에 영구 저장 쾅!
    await _saveCurrentData();

    // 🥇 3. 칭호 획득 알림은 맨 마지막에!
    try {
      final titlesAfterWorkout = _titleService.getUnlockedTitles(myUser);
      if (titlesAfterWorkout.length > titlesCountBeforeWorkout) {
        Future.delayed(const Duration(milliseconds: 500), () => _showNewTitlePopup(titlesAfterWorkout.last));
      }
    } catch (e) {
      print("칭호 확인 에러: $e");
    }
  }

  void _showNewTitlePopup(dynamic newTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text('🎉 새로운 칭호 획득!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber, size: 80),
            const SizedBox(height: 15),
            Text(
              newTitle.name,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            Text(
              newTitle.description,
              style: const TextStyle(color: Colors.white70, fontSize: 16)
            ),
          ]
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () {
              setState(() { _selectedTitle = newTitle.name; });
              _saveCurrentData(); 
              Navigator.pop(context);
            },
            child: const Text('지금 장착하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      )
    );
  }

  void _showTitleListSheet() {
    final unlockedTitles = _titleService.getUnlockedTitles(myUser);
    String currentDisplayTitle = _selectedTitle ?? _titleService.getLatestUnlockedTitle(myUser)?.name ?? "헬린이";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, top: 30, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆 내 칭호 도감', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _titleService.allTitles.length,
                    itemBuilder: (context, index) {
                      final title = _titleService.allTitles[index];
                      final isUnlocked = unlockedTitles.any((t) => t.name == title.name);
                      final isSelected = currentDisplayTitle == title.name;

                      return Card(
                        color: isUnlocked ? Colors.greenAccent.withOpacity(0.1) : Colors.grey[850],
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isSelected ? Colors.greenAccent : (isUnlocked ? Colors.greenAccent.withOpacity(0.3) : Colors.transparent),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          onTap: isUnlocked ? () {
                            setState(() { _selectedTitle = title.name; });
                            _saveCurrentData();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('칭호가 [${title.name}](으)로 변경되었습니다!'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
                            );
                          } : null,
                          leading: Icon(
                            isUnlocked ? Icons.workspace_premium : Icons.lock,
                            color: isSelected ? Colors.greenAccent : (isUnlocked ? Colors.greenAccent.withOpacity(0.5) : Colors.grey[600]),
                            size: 30,
                          ),
                          title: Text(title.name, style: TextStyle(color: isUnlocked ? Colors.white : Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(title.description, style: TextStyle(color: isUnlocked ? Colors.greenAccent.withOpacity(0.8) : Colors.grey[600])),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.greenAccent) : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int requiredExp = myUser.level * 100;
    double expRatio = myUser.currentExp / requiredExp;
    if (expRatio > 1.0) expRatio = 1.0;

    String displayTitle = _selectedTitle ?? _titleService.getLatestUnlockedTitle(myUser)?.name ?? "헬린이";

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9C4), Color(0xFFFFCC80)],
          ),
        ),
        child: SafeArea(
          // 👇 스크롤 삭제됨! 완전히 원래대로 돌아왔습니다.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _showTitleListSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lv.${myUser.level} $displayTitle', style: const TextStyle(fontSize: 26, color: Colors.brown, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      const Icon(Icons.edit, color: Colors.orangeAccent, size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                  child: Stack(
                    children: [
                      AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, width: (MediaQuery.of(context).size.width - 100) * expRatio, decoration: BoxDecoration(color: Colors.lightGreen, borderRadius: BorderRadius.circular(15))),
                      Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(right: 15), child: Text('${myUser.currentExp} / $requiredExp XP', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              Text('누적 스쿼트: $myTotalSquats회', style: const TextStyle(fontSize: 16, color: Colors.brown, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('🏆 최고 기록: $myBestSquats회', style: const TextStyle(fontSize: 22, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Builder(
                builder: (context) {
                  String petImagePath = 'assets/images/level_1.png';
                  if (myUser.level >= 3) petImagePath = 'assets/images/level_3.png';
                  else if (myUser.level >= 2) petImagePath = 'assets/images/level_2.png';

                  return AnimatedBuilder(
                    animation: _idleAnimation,
                    builder: (context, child) => Transform.translate(offset: Offset(0, _idleAnimation.value), child: child),
                    child: SizedBox(width: MediaQuery.of(context).size.width * 0.75, height: MediaQuery.of(context).size.width * 0.75, child: Image.asset(petImagePath, fit: BoxFit.contain)),
                  );
                },
              ),
              const SizedBox(height: 30),

              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.shade400, offset: const Offset(0, 5))]),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: () => _startWorkout(false),
                  child: const Text('일반 연습하기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.orange.shade800, offset: const Offset(0, 5))]),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: () => _startWorkout(true),
                  child: const Text('🔥 최고 기록 측정하기', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
              
              // 👇 테스트용 강제 저장 버튼 2개도 완벽하게 철거했습니다! 
            ],
          ),
        ),
      ),
    );
  }
}