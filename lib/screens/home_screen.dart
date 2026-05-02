import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; 
import 'dart:convert'; // 📅 캘린더 저장을 위한 json 변환기

// 리더님 프로젝트 경로에 맞게 설정된 import
import '../core/workout_data.dart';
import '../data/user_model.dart';
import '../data/exp_service.dart';
import '../data/workout_service.dart';
import '../data/title_service.dart';
import 'workout_screen.dart'; 
import 'calendar_screen.dart'; // 📅 캘린더 화면

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  UserModel myUser = UserModel(uid: 'helma_test_01', level: 1, currentExp: 0);

  final ExpService _expService = ExpService();
  final TitleService _titleService = TitleService();

  int myTotalSquats = 0;
  int myBestSquats = 0;
  String? _selectedTitle;

  int _selectedEffect = 0; 

  bool _isFrameOne = true; 
  Timer? _animationTimer;  

  bool _isBubbleVisible = false; 
  Timer? _bubbleTimer; 

  @override
  void initState() {
    super.initState();
    _loadSavedData(); 

    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _isFrameOne = !_isFrameOne; 
        });
      }
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myTotalSquats = prefs.getInt('total_squats') ?? 0;
      myBestSquats = prefs.getInt('best_squats') ?? 0;
      myUser.level = prefs.getInt('user_level') ?? 1;
      myUser.currentExp = prefs.getInt('user_exp') ?? 0;
      _selectedTitle = prefs.getString('user_title');
      _selectedEffect = prefs.getInt('user_title_effect') ?? 0; 
    });
  }

  Future<void> _saveCurrentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_squats', myTotalSquats);
      await prefs.setInt('best_squats', myBestSquats);
      await prefs.setInt('user_level', myUser.level); 
      await prefs.setInt('user_exp', myUser.currentExp); 
      await prefs.setInt('user_title_effect', _selectedEffect); 
      
      if (_selectedTitle != null) {
        await prefs.setString('user_title', _selectedTitle!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 저장 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // 📅 [핵심] 일일 통계 저장 (설계도 수정 완료!)
  Future<void> _saveDailyStats(int reps, bool isRecordMode) async {
    final prefs = await SharedPreferences.getInstance();
    final String dateKey = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    
    String? statsJson = prefs.getString('daily_stats');
    Map<String, dynamic> dailyStats = statsJson != null ? json.decode(statsJson) : {};

    Map<String, dynamic> todayData = dailyStats[dateKey] ?? {'reps': 0, 'max': 0};
    
    // 1. 일일 운동량은 모드 상관없이 누적
    todayData['reps'] = (todayData['reps'] as int) + reps;
    
    // 2. 최고 기록 측정 모드일 때만 일일 최고 기록을 갱신!
    if (isRecordMode && reps > (todayData['max'] as int)) {
      todayData['max'] = reps;
    }
    
    dailyStats[dateKey] = todayData;
    await prefs.setString('daily_stats', json.encode(dailyStats));
  }

  @override
  void dispose() {
    _animationTimer?.cancel(); 
    _bubbleTimer?.cancel(); 
    super.dispose();
  }

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

    setState(() {
      myTotalSquats += completedReps;
      
      // 👇 방금 만든 _saveDailyStats 호출! (에러 없어짐)
      _saveDailyStats(completedReps, isRecordMode); 

      if (isRecordMode && completedReps > myBestSquats) {
        myBestSquats = completedReps;
      }
      
      try {
        myUser.totalSquatCount += completedReps; 
        myUser = _expService.addExpByWorkout(myUser, WorkoutType.squat, completedReps);
      } catch (e) {
        print("경험치 계산 에러: $e");
      }
    });

    await _saveCurrentData();

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
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        const Text('✨ 칭호 이펙트 선택', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildEffectOption(0, '일반', Icons.lens_blur, Colors.grey, setSheetState),
                            _buildEffectOption(1, '불꽃', Icons.local_fire_department, Colors.orangeAccent, setSheetState),
                            _buildEffectOption(2, '얼음', Icons.ac_unit, Colors.cyanAccent, setSheetState),
                          ],
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildEffectOption(int effectValue, String label, IconData icon, Color color, StateSetter setSheetState) {
    bool isSelected = _selectedEffect == effectValue;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _selectedEffect = effectValue); 
        setState(() {}); 
        _saveCurrentData(); 
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey[700]!, width: 2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEquippedTitleBadge(String title) {
    if (_selectedEffect == 1) { 
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.8), blurRadius: 15, spreadRadius: 2)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
          ],
        ),
      );
    } else if (_selectedEffect == 2) { 
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyanAccent, width: 2),
          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.8), blurRadius: 15, spreadRadius: 2)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ac_unit, color: Colors.cyanAccent, size: 18),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            const Icon(Icons.ac_unit, color: Colors.cyanAccent, size: 18),
          ],
        ),
      );
    } else { 
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black87, width: 2), 
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int requiredExp = myUser.level * 100;
    double expRatio = myUser.currentExp / requiredExp;
    if (expRatio > 1.0) expRatio = 1.0;

    String displayTitle = _selectedTitle ?? _titleService.getLatestUnlockedTitle(myUser)?.name ?? "헬린이";

    return Scaffold(
      extendBody: true, // 🔥 [수정 1] 배경이 바닥까지 꽉 차도록 확장!
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9C4), Color(0xFFFFCC80)], 
          ),
        ),
        child: SafeArea(
          bottom: false, // 🔥 [수정 2] 아이폰 하단 홈 바 영역까지 그라데이션 덮기
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), 
              // ... (이하 기존의 경험치 바, 캐릭터, 칭호 등 UI 코드 동일하게 유지)
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(15), 
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500), 
                        curve: Curves.easeInOut, 
                        width: (MediaQuery.of(context).size.width - 100) * expRatio, 
                        decoration: BoxDecoration(color: Colors.lightGreen, borderRadius: BorderRadius.circular(15))
                      ),
                      Align(
                        alignment: Alignment.center, 
                        child: Text('XP ${myUser.currentExp} / $requiredExp', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),

              AnimatedOpacity(
                opacity: _isBubbleVisible ? 1.0 : 0.0, 
                duration: const Duration(milliseconds: 300), 
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Text('오늘 누적 스쿼트는 $myTotalSquats회 했어!!', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text('최고기록은 $myBestSquats회 했어!!', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      child: Transform.rotate(
                        angle: 0.785398, 
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(2, 2))],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              GestureDetector(
                onTap: () {
                  setState(() { _isBubbleVisible = true; });
                  _bubbleTimer?.cancel(); 
                  _bubbleTimer = Timer(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() { _isBubbleVisible = false; });
                    }
                  });
                },
                child: Builder(
                  builder: (context) {
                    String petImagePath = _isFrameOne 
                        ? 'assets/images/pet_idle_1.png'  
                        : 'assets/images/pet_idle_2.png'; 

                    return SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4, 
                      height: MediaQuery.of(context).size.width * 0.4, 
                      child: Image.asset(petImagePath, fit: BoxFit.contain, filterQuality: FilterQuality.none)
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 20), 
              
              GestureDetector(
                onTap: _showTitleListSheet,
                child: _buildEquippedTitleBadge(displayTitle),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
      
      // 🛠️ 배경이 채워진 예쁜 알약 네비게이션 바
      bottomNavigationBar: Padding(
        // SafeArea 대신 디바이스 하단 여백을 직접 계산해서 더 띄워줍니다.
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).padding.bottom + 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35), 
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15), 
                blurRadius: 20, 
                offset: const Offset(0, 5)
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(Icons.fitness_center, () => _startWorkout(false), Colors.blueAccent),
              _buildNavButton(Icons.calendar_month, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutCalendarScreen()));
              }, Colors.purpleAccent),
              _buildNavButton(Icons.emoji_events, () => _startWorkout(true), Colors.orangeAccent),
            ],
          ),
        ),
      ),
    );
  }
  // 💡 하단 네비게이션 버튼을 예쁘게 만들어주는 헬퍼 함수
  Widget _buildNavButton(IconData icon, VoidCallback onTap, Color iconColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, size: 35, color: iconColor), // 👈 여기서 전달받은 색상을 적용!
      ),
    );
  }
}