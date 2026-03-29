import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const HelmagotchiApp());
}

class HelmagotchiApp extends StatelessWidget {
  const HelmagotchiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '헬마고치',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MainHomeScreen(),
    );
  }
}

// ==========================================
// 🏠 1. 메인 홈 화면
// ==========================================
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int myLevel = 1;
  double myExp = 0.0; // 0.0 ~ 1.0
  int myTotalSquats = 0;
  
  List<bool> dailyWorkouts = [false, false, false];

  void _showWorkoutPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850], // 팝업 배경
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('오늘의 운동', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  bool isDone = dailyWorkouts[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // 🎨 가시성 대폭 수정!
                        // 배경(grey[850]) 위에서 확연히 구분되도록 완료된 버튼을 밝은 회색(grey[600])으로 변경
                        backgroundColor: isDone ? Colors.grey[600] : Colors.greenAccent,
                        // 글자/아이콘 색상도 어두운 배경에 맞게 조정
                        foregroundColor: isDone ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        minimumSize: const Size(double.infinity, 50),
                        elevation: isDone ? 0 : 2, // 완료된건 그림자 없앰
                      ),
                      onPressed: isDone ? null : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CameraWorkoutScreen(
                              startLevel: myLevel, 
                              startSquats: myTotalSquats,
                              workoutIndex: index, 
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            myTotalSquats = result['squats'];
                            if (result['isCompleted'] == true) {
                              dailyWorkouts[result['completedIndex']] = true;
                              myExp += 0.34; 
                              if (myExp >= 0.99) {
                                myLevel++;
                                myExp = 0.0;
                              }
                            }
                          });
                          setDialogState(() {}); 
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '스쿼트 ${index + 1}', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              decoration: isDone ? TextDecoration.lineThrough : null, 
                              // 완료된 글자는 약간 투명하게
                              color: isDone ? Colors.white.withOpacity(0.7) : Colors.black,
                            )
                          ),
                          Icon(
                            isDone ? Icons.check_circle : Icons.play_circle_fill, 
                            size: 28, 
                            // 체크 마크는 형광 초록색 고수 (잘 보임)
                            color: isDone ? Colors.greenAccent : Colors.black
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 경험치 퍼센트 계산 (텍스트용)
    int expPercentage = (myExp * 100).toInt();
    if(expPercentage > 100) expPercentage = 100;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Lv.$myLevel 헬린이', style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // 🌟 텍스트를 포함하는 커스텀 경험치 게이지 바!
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50), // 바 가로 길이 조정
              child: Container(
                height: 25, // 바 높이 약간 키움
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1), // 바 배경색
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack( // 겹치기 기술 사용!
                  children: [
                    // 1층: 차오르는 게이지 (애니메이션 효과)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500), // 게이지 찰 때 부드럽게
                      curve: Curves.easeInOut,
                      width: (MediaQuery.of(context).size.width - 100) * myExp, // 화면 너비 기반 계산
                      decoration: BoxDecoration(
                        color: Colors.greenAccent, // 차오르는 색상
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    // 2층: 우측 정렬 텍스트
                    Align(
                      alignment: Alignment.centerRight, // 우측 중앙 정렬
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12), // 우측 여백
                        child: Text(
                          '$expPercentage / 100 XP', // 👈 요청하신 텍스트 형식
                          style: const TextStyle(
                            color: Colors.white, // 배경색에 관계없이 잘 보이도록 흰색
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            // 글자가 게이지 색에 묻히지 않도록 그림자 살짝 추가
                            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Text('누적 스쿼트: $myTotalSquats회', style: const TextStyle(fontSize: 18, color: Colors.greenAccent)),
            const SizedBox(height: 40),
            
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 30, spreadRadius: 10)]),
              child: const Icon(Icons.pets, size: 100, color: Colors.green),
            ),
            const SizedBox(height: 80),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _showWorkoutPopup, 
              child: const Text('운동 시작하기', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 📸 2. 카메라 운동 화면 (변화 없음)
// ==========================================
class CameraWorkoutScreen extends StatefulWidget {
  final int startLevel;
  final int startSquats;
  final int workoutIndex; 

  const CameraWorkoutScreen({
    super.key, 
    required this.startLevel, 
    required this.startSquats,
    required this.workoutIndex,
  });

  @override
  State<CameraWorkoutScreen> createState() => _CameraWorkoutScreenState();
}

class _CameraWorkoutScreenState extends State<CameraWorkoutScreen> {
  late CameraController _controller;
  bool _isCameraInitialized = false;

  late int currentLevel;
  late int totalSquatCount; 
  
  int currentSet = 1;          
  int squatsInCurrentSet = 0;  
  
  bool isResting = false;      
  int restTimeLeft = 5;        
  Timer? _restTimer;           

  @override
  void initState() {
    super.initState();
    currentLevel = widget.startLevel;
    totalSquatCount = widget.startSquats;

    _controller = CameraController(cameras[0], ResolutionPreset.high);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    }).catchError((Object e) {
      print('카메라 오류: $e');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _restTimer?.cancel(); 
    super.dispose();
  }

  void _startRestTimer() {
    setState(() {
      isResting = true;
      restTimeLeft = 5; 
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (restTimeLeft > 0) {
          restTimeLeft--; 
        } else {
          isResting = false;
          currentSet++;
          squatsInCurrentSet = 0; 
          timer.cancel(); 
        }
      });
    });
  }

  void _onSquatDetected() {
    if (isResting) return; 

    setState(() {
      squatsInCurrentSet++;
      totalSquatCount++;

      if (squatsInCurrentSet == 10) {
        if (currentSet < 3) {
          _startRestTimer();
        } else {
          _showWorkoutCompleteDialog();
        }
      }
    });
  }

  void _showWorkoutCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('🎉 오운완!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('오늘의 3세트 목표를 모두 달성했습니다!\n다마고치가 경험치를 얻습니다.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context, {
                'squats': totalSquatCount,
                'completedIndex': widget.workoutIndex,
                'isCompleted': true 
              }); 
            },
            child: const Text('목록으로 돌아가기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _isCameraInitialized 
                ? SizedBox(width: double.infinity, height: double.infinity, child: CameraPreview(_controller))
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
            
            Positioned(
              top: 20, left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 40),
                onPressed: () {
                  Navigator.pop(context, {'squats': totalSquatCount});
                }
              ),
            ),

            Positioned(
              top: 80, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lv.$currentLevel 헬린이', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
                      Text('$currentSet / 3 세트', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: squatsInCurrentSet / 10.0, 
                      minHeight: 20,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 100, left: 0, right: 0,
              child: Center(
                child: Text(
                  '이번 세트: $squatsInCurrentSet / 10회', 
                  style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                ),
              ),
            ),

            if (isResting)
              Container(
                color: Colors.black.withOpacity(0.8), 
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('숨 고르기!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    const SizedBox(height: 20),
                    Text('$restTimeLeft초', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 20),
                    const Text('근육이 성장하고 있어요 💪', style: TextStyle(fontSize: 20, color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
      
      floatingActionButton: isResting ? null : FloatingActionButton(
        onPressed: _onSquatDetected,
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}