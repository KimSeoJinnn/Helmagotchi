import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // 추가: WriteBuffer 사용
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'; // 추가: 구글 ML Kit
import 'ai/pose_analyzer.dart'; // 추가: 자세 분석기

// 🤝 팀원들이 만든 파일들 불러오기
import 'core/workout_data.dart';
import 'data/user_model.dart';
import 'data/exp_service.dart';
import 'data/workout_service.dart';
import 'ai/rep_counter.dart';
import 'core/models/pose_result.dart';

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
  // 💾 BE2 팀원의 UserModel 적용!
  UserModel myUser = UserModel(uid: 'helma_test_01', level: 1, currentExp: 0);

  // 💾 BE1 팀원의 ExpService 적용!
  final ExpService _expService = ExpService();

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
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '오늘의 운동',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        backgroundColor: isDone
                            ? Colors.grey[600]
                            : Colors.greenAccent,
                        foregroundColor: isDone ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                        elevation: isDone ? 0 : 2,
                      ),
                      onPressed: isDone
                          ? null
                          : () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CameraWorkoutScreen(workoutIndex: index),
                                ),
                              );

                              if (result != null) {
                                setState(() {
                                  // 운동 완료 후 결과 처리
                                  if (result['isCompleted'] == true) {
                                    dailyWorkouts[result['completedIndex']] =
                                        true;

                                    int completedReps = result['reps'] ?? 0;
                                    myTotalSquats += completedReps;

                                    // 🎁 BE1 팀원의 로직 호출! (수행한 스쿼트 개수만큼 한 번에 경험치 획득)
                                    myUser = _expService.addExpByWorkout(
                                      myUser,
                                      WorkoutType.squat,
                                      completedReps, // 에러 해결된 3번째 매개변수
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
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black,
                            ),
                          ),
                          Icon(
                            isDone
                                ? Icons.check_circle
                                : Icons.play_circle_fill,
                            size: 28,
                            color: isDone ? Colors.greenAccent : Colors.black,
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
    // BE1 로직에 따른 다음 레벨업 필요 경험치 계산 (레벨 * 100)
    int requiredExp = myUser.level * 100;
    double expRatio = myUser.currentExp / requiredExp;
    if (expRatio > 1.0) expRatio = 1.0;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Lv.${myUser.level} 헬린이',
              style: const TextStyle(
                fontSize: 30,
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
                      width:
                          (MediaQuery.of(context).size.width - 100) * expRatio,
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
                // 🧠 진화 단계 계산 로직
                String petImagePath = 'assets/images/level_1.png'; // 기본 1단계 이미지

                if (myUser.level >= 6) {
                  petImagePath =
                      'assets/images/level_3.png'; // 레벨 6 이상: 3단계 최종 진화!
                } else if (myUser.level >= 3) {
                  petImagePath =
                      'assets/images/level_2.png'; // 레벨 3 이상: 2단계 진화!
                }

                // 🚀 [반응형 크기 적용!]
                return SizedBox(
                  // 현재 폰 가로 길이의 80% 크기로 자동 맞춤!
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _showWorkoutPopup,
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
  final int workoutIndex;

  const CameraWorkoutScreen({super.key, required this.workoutIndex});

  @override
  State<CameraWorkoutScreen> createState() => _CameraWorkoutScreenState();
}

class _CameraWorkoutScreenState extends State<CameraWorkoutScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  // 🤖 AI 팀원의 상태 머신 로직 적용!
  final SquatRepCounter _repCounter = SquatRepCounter();

  // 👉 실제 자세 분석을 위한 객체 및 상태 변수 (추가됨)
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _isProcessing = false;

  int currentSet = 1;
  bool isResting = false;
  int restTimeLeft = 5;
  Timer? _restTimer;

// 🚀 [추가] 3초 준비 시간용 변수
  bool isPreparing = true; 
  int prepTimeLeft = 3;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      // 👉 cameras[1]을 사용하여 전면 카메라 적용
      _controller = CameraController(cameras[1], ResolutionPreset.medium, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,);
     _controller!
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _isCameraInitialized = true);
            
            // 🚀 [추가] 카메라가 켜지면 3초 카운트다운 시작!
            _startPrepTimer();

            _controller!.startImageStream((CameraImage image) async {
              // 🚀 [수정] 준비 중(isPreparing)일 때도 AI 분석을 멈춥니다!
              if (isPreparing || _isProcessing || isResting) return; 
              
              _isProcessing = true;

              try {
                // 1. 카메라 프레임(이미지)을 ML Kit가 읽을 수 있게 포맷 변환
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

                // 2. 구글 ML Kit로 뼈대(관절) 추출
                final List<Pose> poses = await _poseDetector.processImage(
                  inputImage,
                );

                // 3. 추출된 뼈대를 분석해서 스쿼트 상태 업데이트!
                if (poses.isNotEmpty) {
                  final poseResult = PoseAnalyzer.analyze(poses.first);

                  if (poseResult != null) {
                    setState(() {
                      _repCounter.update(poseResult); // 진짜 카운트가 여기서 올라감

                      // 10개를 채웠다면 다음 세트로 넘어가거나 완료 처리
                      if (_repCounter.reps >= 10) {
                        if (currentSet < 3) {
                          _startRestTimer();
                        } else {
                          if (!isResting) {
                            _showWorkoutCompleteDialog();
                            isResting = true;
                          }
                        }
                      }
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
    _restTimer?.cancel();
    _poseDetector.close(); // 👉 AI 리소스 해제 코드 추가
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
          _repCounter.reset(); // 다음 세트를 위해 AI 카운터 초기화!
          timer.cancel();
        }
      });
    });
  }

  // 🚀 [추가] 3초 준비 타이머 함수
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
          isPreparing = false; // 3초가 지나면 준비 끝! AI 분석 시작!
          timer.cancel();
        }
      });
    });
  }

  // 🧪 윈도우 환경 테스트용 가짜 AI 업데이트 함수 (비상시를 위해 일단 유지)
  void _triggerMockAIUpdate() {
    if (isResting) return;
    setState(() {
      _repCounter.update(
        const PoseResult(
          leftKneeAngle: 120,
          rightKneeAngle: 120,
          leftHipAngle: 100,
          landmarks: {},
          confidence: 0.99,
        ),
      );
      _repCounter.update(
        const PoseResult(
          leftKneeAngle: 90,
          rightKneeAngle: 90,
          leftHipAngle: 100,
          landmarks: {},
          confidence: 0.99,
        ),
      );
      _repCounter.update(
        const PoseResult(
          leftKneeAngle: 140,
          rightKneeAngle: 140,
          leftHipAngle: 100,
          landmarks: {},
          confidence: 0.99,
        ),
      );
      _repCounter.update(
        const PoseResult(
          leftKneeAngle: 170,
          rightKneeAngle: 170,
          leftHipAngle: 100,
          landmarks: {},
          confidence: 0.99,
        ),
      );

      if (_repCounter.reps >= 10) {
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
        title: const Text(
          '🎉 오운완!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '오늘의 3세트 목표를 모두 달성했습니다!\n경험치가 팍팍 오릅니다!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {
                'reps': currentSet * 10, // 총 30개 수행 완료
                'completedIndex': widget.workoutIndex,
                'isCompleted': true,
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
                      // 🤖 AI 팀원의 자세 피드백을 실시간으로 화면에 띄워줍니다!
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
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 5),
                          ],
                        ),
                      ),
                      Text(
                        '$currentSet / 3 세트',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _repCounter.reps / 10.0,
                      minHeight: 20,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '이번 세트: ${_repCounter.reps} / 10회',
                  style: const TextStyle(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                  ),
                ),
              ),
            ),

            // 🚀 [추가] 화면 한가운데에 3, 2, 1 카운트다운 보여주기
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

            if (isResting)
              Container(
                color: Colors.black.withOpacity(0.8),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '숨 고르기!',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$restTimeLeft초',
                      style: const TextStyle(
                        fontSize: 80,
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

      // 🧪 윈도우 테스트용 가짜 스쿼트 발생 버튼 (화면 우측 하단에 남겨둠)
      // floatingActionButton: isResting
      //     ? null
      //     : FloatingActionButton(
      //         onPressed: _triggerMockAIUpdate,
      //         backgroundColor: Colors.greenAccent,
      //         child: const Icon(Icons.add, color: Colors.black),
      //       ),
    );
  }
}
