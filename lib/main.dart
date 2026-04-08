import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'; 
import 'ai/pose_analyzer.dart'; 

// 🤝 팀원들이 만든 파일들 불러오기
import 'core/workout_data.dart';
import 'data/user_model.dart';
import 'data/exp_service.dart';
import 'data/workout_service.dart';
import 'ai/rep_counter.dart';
import 'core/models/pose_result.dart';
// 🚀 [추가] 칭호 서비스 임포트
import 'data/title_service.dart'; 

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("카메라를 찾을 수 없습니다. (에뮬레이터/윈도우 환경 체크)");
  }
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
// 🏠 1. 메인 홈 화면 (BE 로직 연동)
// ==========================================
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

  // 🚀 멋진 칭호 도감 바텀 시트 UI
  void _showTitleListSheet() {
    final unlockedTitles = _titleService.getUnlockedTitles(myUser);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 30,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🏆 내 칭호 도감',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _titleService.allTitles.length,
                itemBuilder: (context, index) {
                  final title = _titleService.allTitles[index];
                  final isUnlocked = unlockedTitles.any((t) => t.name == title.name);

                  return Card(
                    color: isUnlocked ? Colors.greenAccent.withOpacity(0.1) : Colors.grey[850],
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isUnlocked ? Colors.greenAccent : Colors.transparent,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Icon(
                        isUnlocked ? Icons.workspace_premium : Icons.lock,
                        color: isUnlocked ? Colors.greenAccent : Colors.grey[600],
                        size: 30,
                      ),
                      title: Text(
                        title.name,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.grey[500],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Text(
                        title.description,
                        style: TextStyle(
                          color: isUnlocked ? Colors.greenAccent.withOpacity(0.8) : Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int requiredExp = myUser.level * 100;
    double expRatio = myUser.currentExp / requiredExp;
    if (expRatio > 1.0) expRatio = 1.0;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🚀 터치하면 도감이 열리고, 최신 칭호가 뜨도록 변경!
            GestureDetector(
              onTap: _showTitleListSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lv.${myUser.level} ${_titleService.getLatestUnlockedTitle(myUser)?.name ?? "헬린이"}',
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.info_outline, color: Colors.greenAccent, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Container(
                height: 25,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: (MediaQuery.of(context).size.width - 100) * expRatio,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${myUser.currentExp} / $requiredExp XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '누적 스쿼트: $myTotalSquats회',
              style: const TextStyle(fontSize: 18, color: Colors.greenAccent),
            ),
            const SizedBox(height: 20),

            Builder(
              builder: (context) {
                String petImagePath = 'assets/images/level_1.png'; 

                if (myUser.level >= 3) {
                  petImagePath = 'assets/images/level_3.png'; 
                } else if (myUser.level >= 2) {
                  petImagePath = 'assets/images/level_2.png'; 
                }

                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  child: Image.asset(petImagePath, fit: BoxFit.contain),
                );
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              // 🚀 팝업창 없이 바로 카메라 화면으로 이동!
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraWorkoutScreen(),
                  ),
                );

                // 카메라 화면에서 전달받은 결과 처리
                if (result != null) {
                  setState(() {
                    int completedReps = result['reps'] ?? 0;
                    if (completedReps > 0) {
                      myTotalSquats += completedReps;
                      myUser.totalSquatCount += completedReps; // 칭호 해금을 위해 누적 스쿼트 추가!

                      // BE1 팀원의 로직 호출 (경험치 획득)
                      myUser = _expService.addExpByWorkout(
                        myUser,
                        WorkoutType.squat,
                        completedReps,
                      );

                      // BE2 팀원의 WorkoutService 연동 (기록 저장용)
                      WorkoutService().handleMovement(
                        WorkoutEvent(
                          type: WorkoutType.squat,
                          timestamp: DateTime.now(),
                        ),
                      );
                    }
                  });
                }
              },
              child: const Text(
                '운동 시작하기',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 📸 2. 카메라 운동 화면 (AI 로직 연동)
// ==========================================
class CameraWorkoutScreen extends StatefulWidget {
  const CameraWorkoutScreen({super.key}); // 🚀 index 매개변수 제거

  @override
  State<CameraWorkoutScreen> createState() => _CameraWorkoutScreenState();
}

class _CameraWorkoutScreenState extends State<CameraWorkoutScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  final SquatRepCounter _repCounter = SquatRepCounter();
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isProcessing = false;

  // 🚀 세트 관련 변수 삭제 완료
  bool isPreparing = true; 
  int prepTimeLeft = 3;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[1], 
        ResolutionPreset.medium, 
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      _controller!
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _isCameraInitialized = true);
            
            _startPrepTimer();

            _controller!.startImageStream((CameraImage image) async {
              if (isPreparing || _isProcessing) return; // 🚀 휴식(isResting) 조건 제거
              
              _isProcessing = true;

              try {
                final WriteBuffer allBytes = WriteBuffer();
                for (final Plane plane in image.planes) {
                  allBytes.putUint8List(plane.bytes);
                }
                final bytes = allBytes.done().buffer.asUint8List();

                final Size imageSize = Size(
                  image.width.toDouble(),
                  image.height.toDouble(),
                );
                final imageRotation =
                    InputImageRotationValue.fromRawValue(
                      _controller!.description.sensorOrientation,
                    ) ??
                    InputImageRotation.rotation0deg;
                final inputImageFormat =
                    InputImageFormatValue.fromRawValue(image.format.raw) ??
                    InputImageFormat.nv21;

                final inputImageData = InputImageMetadata(
                  size: imageSize,
                  rotation: imageRotation,
                  format: inputImageFormat,
                  bytesPerRow: image.planes[0].bytesPerRow,
                );

                final inputImage = InputImage.fromBytes(
                  bytes: bytes,
                  metadata: inputImageData,
                );

                final List<Pose> poses = await _poseDetector.processImage(inputImage);

                if (poses.isNotEmpty) {
                  final poseResult = PoseAnalyzer.analyze(poses.first);

                  if (poseResult != null) {
                    setState(() {
                      _repCounter.update(poseResult); 
                      // 🚀 10개 달성 시 자동 종료되는 로직(세트 휴식) 삭제! 
                      // 무한으로 개수가 올라갑니다.
                    });
                  }
                }
              } catch (e) {
                print('에러: $e');
              } finally {
                _isProcessing = false;
              }
            });
          })
          .catchError((Object e) {
            print('카메라 오류: $e');
          });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close(); 
    super.dispose();
  }

  void _startPrepTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (prepTimeLeft > 1) {
          prepTimeLeft--;
        } else {
          isPreparing = false; 
          timer.cancel();
        }
      });
    });
  }

  // 🚀 운동 종료 및 경험치 확인 팝업
  void _showWorkoutCompleteDialog() {
    // 획득할 경험치 미리 계산 (스쿼트 개수 * 스쿼트 경험치율(2))
    int earnedExp = _repCounter.reps * ExpService.squatExp;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          '🎉 오운완!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '스쿼트 ${_repCounter.reps}회 완료!\n$earnedExp 경험치 획득!', // 🚀 변경된 텍스트
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context); // 팝업 닫기
              Navigator.pop(context, { // 홈 화면으로 횟수와 함께 돌아가기
                'reps': _repCounter.reps, 
              });
            },
            child: const Text('확인'),
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
            _isCameraInitialized && _controller != null
                ? SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CameraPreview(_controller!),
                  )
                : const Center(
                    child: Text(
                      "카메라 대기 중 (모바일에서 확인)",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

            Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 40),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _repCounter.lastJudgement.isGoodForm
                            ? '자세 완벽해요!'
                            : _repCounter.lastJudgement.feedback ?? '자세 주의',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _repCounter.lastJudgement.isGoodForm
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                      // 🚀 세트 텍스트 자리에 '운동 종료' 버튼 배치!
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _showWorkoutCompleteDialog,
                        child: const Text('운동 종료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  // 🚀 프로그레스 바(게이지 바) 삭제 완료!
                ],
              ),
            ),

            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                // 🚀 진행 중인 스쿼트 횟수만 깔끔하게 표시
                child: Text(
                  '${_repCounter.reps} 회',
                  style: const TextStyle(
                    fontSize: 80,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                  ),
                ),
              ),
            ),

            if (isPreparing)
              Container(
                color: Colors.black.withOpacity(0.7),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '준비하세요!',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$prepTimeLeft',
                      style: const TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}