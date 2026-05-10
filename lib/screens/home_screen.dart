import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; 
import 'dart:convert';

import '../core/workout_data.dart';
import '../data/user_model.dart';
import '../data/exp_service.dart';
import '../data/workout_service.dart';
import '../data/title_service.dart';
import '../data/local_storage.dart'; // 💡 로컬 스토리지 import!
import 'workout_screen.dart'; 
import 'calendar_screen.dart'; 
import 'photo_screen.dart';

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
  int myDailyGoal = 50;
  String? _selectedTitle;
  int _selectedEffect = 0; 

  // 🎒 악세사리 옷장용 변수
  String _equippedAccessory = 'none'; 
  List<String> _unlockedAccessories = ['none'];

  bool _isFrameOne = true; 
  Timer? _animationTimer;  

  bool _isBubbleVisible = false; 
  Timer? _bubbleTimer; 

  int todaySquats = 0;

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

  // 👇 기존 _loadSavedData 함수를 지우고 이걸로 덮어써주세요!
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayKey = DateTime.now().toString().split(' ')[0]; // "2024-05-10" 형태

    // 💡 악세사리 데이터 불러오기
    String loadedAcc = await LocalStorage.loadEquippedAccessory();
    List<String> unlockedAcc = await LocalStorage.loadUnlockedAccessories();

    String? statsJson = prefs.getString('daily_stats');
  if (statsJson != null) {
    Map<String, dynamic> statsMap = jsonDecode(statsJson);
    if (statsMap.containsKey(todayKey)) {
      todaySquats = statsMap[todayKey]['reps'] ?? 0;
    } else {
      todaySquats = 0;
    }
  }

    setState(() {
      myTotalSquats = prefs.getInt('total_squats') ?? 0;
      myBestSquats = prefs.getInt('best_squats') ?? 0;
      myDailyGoal = prefs.getInt('daily_goal') ?? 50;

      // 💡 [핵심 수정] myUser 내부의 스탯도 똑같이 복구해야 칭호 해금 상태가 유지됩니다!
      myUser.level = prefs.getInt('user_level') ?? 1;
      myUser.currentExp = prefs.getInt('user_exp') ?? 0;
      myUser.totalSquatCount = myTotalSquats; // 👈 칭호를 기억하게 만드는 마법의 한 줄!
      
      _selectedTitle = prefs.getString('user_title');
      _selectedEffect = prefs.getInt('user_title_effect') ?? 0; 
      
      _equippedAccessory = loadedAcc;
      _unlockedAccessories = unlockedAcc;
    });
  }

  Future<void> _saveCurrentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_squats', myTotalSquats);
      await prefs.setInt('best_squats', myBestSquats);
      await prefs.setInt('daily_goal', myDailyGoal);
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

  Future<void> _saveDailyStats(int reps, bool isRecordMode) async {
    final prefs = await SharedPreferences.getInstance();
    final String dateKey = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    
    String? statsJson = prefs.getString('daily_stats');
    Map<String, dynamic> dailyStats = statsJson != null ? json.decode(statsJson) : {};

    Map<String, dynamic> todayData = dailyStats[dateKey] ?? {'reps': 0, 'max': 0};
    
    todayData['reps'] = (todayData['reps'] as int) + reps;
    
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
            Text(newTitle.name, style: const TextStyle(color: Colors.greenAccent, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(newTitle.description, style: const TextStyle(color: Colors.white70, fontSize: 16)),
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

  // 🎯 일일 목표 설정 팝업창
  void _showGoalSettingDialog() {
    TextEditingController goalController = TextEditingController(text: myDailyGoal.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎯 일일 퀘스트 목표 설정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: goalController,
          keyboardType: TextInputType.number, // 숫자 키보드만 나오게!
          decoration: InputDecoration(
            labelText: '스쿼트 목표 횟수',
            suffixText: '회',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              setState(() {
                // 입력한 숫자를 가져오되, 이상한 문자면 기본값 50으로 설정
                myDailyGoal = int.tryParse(goalController.text) ?? 50; 
              });
              _saveCurrentData(); // 💡 바뀐 목표치 로컬에 저장!
              Navigator.pop(context);
            },
            child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🎒 칭호 아래에 추가할 옷장 바텀시트!
  void _showClosetSheet() {
    final Map<String, String> allItems = {
      'none': '기본 (장착 해제)',
      'crown': '황금 왕관',
      'wing': '천사 날개',         // ✨ 추가!
      'ribbon': '귀여운 리본',        // ✨ 추가!
      'sunglasses': '멋쟁이 선글라스', // ✨ 추가!
    };

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
                  const Text('🎒 내 옷장', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allItems.keys.length,
                    itemBuilder: (context, index) {
                      String itemKey = allItems.keys.elementAt(index);
                      String itemName = allItems[itemKey]!;
                      bool isUnlocked = _unlockedAccessories.contains(itemKey);
                      bool isSelected = _equippedAccessory == itemKey;

                      // 테스트를 위해 모두 해금 상태로 열어둡니다!
                      isUnlocked = true; 

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
                          onTap: isUnlocked ? () async {
                            setState(() { _equippedAccessory = itemKey; });
                            await LocalStorage.saveEquippedAccessory(itemKey);
                            Navigator.pop(context);
                          } : null,
                          leading: Icon(
                            isUnlocked ? Icons.checkroom : Icons.lock,
                            color: isSelected ? Colors.greenAccent : (isUnlocked ? Colors.greenAccent.withOpacity(0.5) : Colors.grey[600]),
                            size: 30,
                          ),
                          title: Text(itemName, style: TextStyle(color: isUnlocked ? Colors.white : Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 18)),
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
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9C4), Color(0xFFFFCC80)], 
          ),
        ),
        child: SafeArea(
          bottom: false, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), 
              
              // 🌟 1. 레벨 & 경험치 바 영역
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    // 👑 현재 레벨 표시 (왼쪽)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Text(
                        'Lv.${myUser.level}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 🔋 경험치 바 & 우측 텍스트
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: LinearProgressIndicator(
                              // 👇 핵심 수정: maxExp 대신 (현재 레벨 * 100)을 목표치로 계산합니다!
                              value: (myUser.currentExp / (myUser.level * 100)).clamp(0.0, 1.0),
                              minHeight: 26,
                              backgroundColor: Colors.grey[200],
                              color: Colors.amber,
                            ),
                          ),
                          // 바 내부 우측 XP 텍스트
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              // 👇 여기도 마찬가지로 (현재 레벨 * 100)으로 표시합니다!
                              '${myUser.currentExp} / ${myUser.level * 100} XP',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 👇 기존 const Spacer(), 자리에 이 코드를 쏙 넣어주세요!
              const SizedBox(height: 30), // 위쪽 여백

              // 🎯 일일 퀘스트 카드
              GestureDetector(
                onTap: _showGoalSettingDialog, // 👈 누르면 팝업창 뜸!
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber, width: 2), // 예쁜 노란색 테두리
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('일일 목표', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                          const SizedBox(width: 8),
                          Icon(Icons.edit, size: 16, color: Colors.grey[500]), // 수정 가능함을 알리는 연필 아이콘
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 🟢 프로그레스 바 (진행도)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: myDailyGoal > 0 ? (todaySquats / myDailyGoal).clamp(0.0, 1.0) : 0, // 에러 방지 계산식
                          minHeight: 12,
                          backgroundColor: Colors.grey[200],
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 🔢 숫자 텍스트
                      Text(
                        '$todaySquats / $myDailyGoal 회', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 50),
              
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
                          Text('총 누적 스쿼트 횟수는 $myTotalSquats회야!!', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text('역대 최고 기록은 $myBestSquats회야!!', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
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

              // 💡 펫 & 악세사리 Stack 영역 (Builder 걷어내고 교체 완료!)
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
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4, 
                  height: MediaQuery.of(context).size.width * 0.4, 
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Stack(
                      key: ValueKey('$_equippedAccessory$_isFrameOne'),
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 🧸 1층 (Layer 1): 헬마고치 몸통
                        Image.asset(
                          _isFrameOne ? 'assets/images/basic_idle1.png' : 'assets/images/basic_idle2.png',
                          width: MediaQuery.of(context).size.width * 0.4,
                          filterQuality: FilterQuality.none, 
                        ),
                        
                        // 👑 2층 (Layer 2): 악세사리 (홈 화면 전용 위치 자동 조절!)
                        if (_equippedAccessory != 'none')
                          Builder(
                            builder: (context) {
                              // 📍 홈 화면에서의 기본 위치와 크기를 세팅합니다.
                              double topPos = 0;
                              double rightPos = 0; 
                              double itemWidth = 40; // 홈 화면은 펫이 더 크니까 기본 크기도 약간 더 큼!

                              if (_equippedAccessory == 'crown') {
                                // 👑 왕관일 때의 위치 (오른쪽 위 대각선 핏!)
                                topPos = -14;  // 숫자가 작아질수록 더 높이 올라감
                                rightPos = 50; // 숫자가 작아질수록 더 오른쪽으로 감
                                itemWidth = 40; 
                              } else if (_equippedAccessory == 'wing') {
                                // 🪽 날개: 몸통 뒤쪽에 넓게 퍼지도록 크게 설정
                                topPos = 30;
                                rightPos = 100; 
                                itemWidth = 80; 
                              } else if (_equippedAccessory == 'ribbon') {
                                // 🎀 리본: 머리 한쪽이나 목에 오도록 설정
                                topPos = -14;
                                rightPos = 40; 
                                itemWidth = 60;
                              } else if (_equippedAccessory == 'sunglasses') {
                                // 🕶️ 선글라스: 눈 위치에 딱 맞게!
                                topPos = 0;
                                rightPos = 20; 
                                itemWidth = 100;
                              }

                              return Positioned(
                                top: topPos,
                                right: rightPos, // 👈 여기가 핵심! 오른쪽 기준으로 띄웁니다.
                                child: Image.asset(
                                  'assets/images/$_equippedAccessory.png', 
                                  width: itemWidth, 
                                  filterQuality: FilterQuality.none, 
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 50), 
              
              // 💡 기존 칭호 뱃지 유지!
              GestureDetector(
                onTap: _showTitleListSheet,
                child: _buildEquippedTitleBadge(displayTitle),
              ),

              const SizedBox(height: 15),

              const Spacer(),
            ],
          ),
        ),
      ),
      
      // 💡 홈 화면 맨 아래 bottomNavigationBar
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).padding.bottom + 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35), 
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 5))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(Icons.fitness_center, () => _startWorkout(false), Colors.blueAccent), // 스쿼트
              
              _buildNavButton(Icons.checkroom, _showClosetSheet, Colors.green), // 옷장
              _buildNavButton(Icons.calendar_month, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkoutCalendarScreen()));
              }, Colors.purpleAccent), // 캘린더
              
              // 📸 새롭게 추가된 AR 카메라 버튼!
              _buildNavButton(Icons.camera_alt, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ARPhotoScreen()));
              }, Colors.pinkAccent),

              _buildNavButton(Icons.emoji_events, () => _startWorkout(true), Colors.orangeAccent), // 최고 기록
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, Color iconColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, size: 35, color: iconColor), 
      ),
    );
  }
}