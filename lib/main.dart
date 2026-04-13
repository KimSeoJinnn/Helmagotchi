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
import 'data/title_service.dart'; 

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("카메라를 찾을 수 없습니다.");
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
// 🏠 1. 메인 홈 화면
// ==========================================
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
  String? _selectedTitle;

  late AnimationController _idleController;
  late Animation<double> _idleAnimation;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _idleAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              setState(() { _selectedTitle = newTitle.name; });
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
                top: 30, left: 20, right: 20,
              ),
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
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                    Text('Lv.${myUser.level} $displayTitle', style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    const Icon(Icons.edit, color: Colors.greenAccent, size: 20), 
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Container(
                height: 25,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500), curve: Curves.easeInOut,
                      width: (MediaQuery.of(context).size.width - 100) * expRatio,
                      decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(15)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text('${myUser.currentExp} / $requiredExp XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('누적 스쿼트: $myTotalSquats회', style: const TextStyle(fontSize: 18, color: Colors.greenAccent)),
            const SizedBox(height: 20),

            Builder(
              builder: (context) {
                String petImagePath = 'assets/images/level_1.png'; 
                if (myUser.level >= 3) petImagePath = 'assets/images/level_3.png'; 
                else if (myUser.level >= 2) petImagePath = 'assets/images/level_2.png'; 

                return AnimatedBuilder(
                  animation: _idleAnimation,
                  builder: (context, child) => Transform.translate(offset: Offset(0, _idleAnimation.value), child: child),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8, height: MediaQuery.of(context).size.width * 0.8,
                    child: Image.asset(petImagePath, fit: BoxFit.contain),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraWorkoutScreen()));

                if (result != null) {
                  int completedReps = result['reps'] ?? 0;
                  if (completedReps > 0) {
                    int titlesCountBeforeWorkout = _titleService.getUnlockedTitles(myUser).length;

                    setState(() {
                      myTotalSquats += completedReps;
                      myUser.totalSquatCount += completedReps; 
                      myUser = _expService.addExpByWorkout(myUser, WorkoutType.squat, completedReps);
                      WorkoutService().handleMovement(WorkoutEvent(type: WorkoutType.squat, timestamp: DateTime.now()));
                    });

                    final titlesAfterWorkout = _titleService.getUnlockedTitles(myUser);
                    if (titlesAfterWorkout.length > titlesCountBeforeWorkout) {
                      Future.delayed(const Duration(milliseconds: 500), () => _showNewTitlePopup(titlesAfterWorkout.last));
                    }
                  }
                }
              },
              child: const Text('운동 시작하기', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 📸 2. 카메라 운동 화면 (AI 로직 연동) + 오버레이
// ==========================================
class CameraWorkoutScreen extends StatefulWidget {
  const CameraWorkoutScreen({super.key}); 
  @override
  State<CameraWorkoutScreen> createState() => _CameraWorkoutScreenState();
}

class _CameraWorkoutScreenState extends State<CameraWorkoutScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  final SquatRepCounter _repCounter = SquatRepCounter();
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isProcessing = false;

  bool isPreparing = true; 
  int prepTimeLeft = 3;

  // 🚀 [추가] AI가 인식한 실시간 뼈대 데이터 보관용
  Pose? _currentPose;
  Size? _imageSize;

  // 🚀 [추가] 레벨 2 (PIP 미니 쌤) 애니메이션용
  late AnimationController _pipController;
  late Animation<double> _pipAnimation;

  @override
  void initState() {
    super.initState();
    
    // 미니 쌤이 스쿼트 하듯 위아래로 움직이는 애니메이션
    _pipController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pipAnimation = Tween<double>(begin: -5, end: 15).animate(CurvedAnimation(parent: _pipController, curve: Curves.easeInOut));

    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[1], ResolutionPreset.medium, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() => _isCameraInitialized = true);
        
        _startPrepTimer();

        _controller!.startImageStream((CameraImage image) async {
          if (_isProcessing) return; 
          _isProcessing = true;

          try {
            final WriteBuffer allBytes = WriteBuffer();
            for (final Plane plane in image.planes) { allBytes.putUint8List(plane.bytes); }
            final bytes = allBytes.done().buffer.asUint8List();

            final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
            final imageRotation = InputImageRotationValue.fromRawValue(_controller!.description.sensorOrientation) ?? InputImageRotation.rotation0deg;
            final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

            final inputImageData = InputImageMetadata(size: imageSize, rotation: imageRotation, format: inputImageFormat, bytesPerRow: image.planes[0].bytesPerRow);
            final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);

            final List<Pose> poses = await _poseDetector.processImage(inputImage);

            if (poses.isNotEmpty) {
              final pose = poses.first;
              final poseResult = PoseAnalyzer.analyze(pose);

              if (mounted) {
                setState(() {
                  _currentPose = pose; // 뼈대 데이터 저장!
                  _imageSize = imageSize; // 이미지 크기 저장!
                  
                  if (!isPreparing && poseResult != null) {
                    _repCounter.update(poseResult); 
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
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close(); 
    _pipController.dispose();
    super.dispose();
  }

  void _startPrepTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (prepTimeLeft > 1) { prepTimeLeft--; } 
        else { isPreparing = false; timer.cancel(); }
      });
    });
  }

  void _showWorkoutCompleteDialog() {
    if (_repCounter.reps == 0) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text('👀 앗!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('아직 스쿼트를 1개도 하지 않았습니다.\n이대로 운동을 종료할까요?', style: TextStyle(color: Colors.white70, fontSize: 16)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('계속하기', style: TextStyle(color: Colors.grey, fontSize: 16))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () { Navigator.pop(context); Navigator.pop(context, {'reps': 0}); },
              child: const Text('종료하기'),
            ),
          ],
        ),
      );
      return; 
    }

    int earnedExp = _repCounter.reps * ExpService.squatExp;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('🎉 오운완!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('스쿼트 ${_repCounter.reps}회 완료!\n$earnedExp 경험치 획득!', style: const TextStyle(color: Colors.white70, fontSize: 18)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () { Navigator.pop(context); Navigator.pop(context, {'reps': _repCounter.reps}); },
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
            // 📸 0층: 카메라 화면 (비율 완벽 수정됨)
            _isCameraInitialized && _controller != null
                ? Container(
                    width: double.infinity, height: double.infinity, color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1 / _controller!.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),
                            
                            // 🥇 [레벨 3] 실시간 AR 뼈대 오버레이 (카메라 크기에 맞춰서 그려짐)
                            if (_currentPose != null && _imageSize != null)
                              CustomPaint(
                                painter: PosePainter(
                                  _currentPose!, 
                                  _imageSize!, 
                                  _repCounter.lastJudgement.isGoodForm // 자세가 좋으면 초록색으로 변함!
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const Center(child: Text("카메라 대기 중", style: TextStyle(color: Colors.white))),

            // 🥈 [레벨 2] 우측 상단 미니 PT 쌤 (PIP)
            if (!isPreparing)
              Positioned(
                top: 130, right: 20,
                child: Container(
                  width: 80, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('PT 쌤', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      AnimatedBuilder(
                        animation: _pipAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _pipAnimation.value),
                          child: const Icon(Icons.accessibility_new, color: Colors.greenAccent, size: 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 🥉 [레벨 1] 준비 중일 때 가운데 뜨는 반투명 가이드 실루엣
            if (isPreparing)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('여기에 서세요!', style: TextStyle(fontSize: 30, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    Icon(Icons.accessibility_new, size: 300, color: Colors.white.withOpacity(0.4)),
                  ],
                ),
              ),

            // 상단 UI (운동 종료 버튼)
            Positioned(
              top: 80, left: 20, right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _repCounter.lastJudgement.isGoodForm ? '자세 완벽해요!' : _repCounter.lastJudgement.feedback ?? '자세 주의',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: _repCounter.lastJudgement.isGoodForm ? Colors.greenAccent : Colors.redAccent,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: _showWorkoutCompleteDialog,
                    child: const Text('운동 종료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),

            // 하단 UI (스쿼트 횟수)
            Positioned(
              bottom: 100, left: 0, right: 0,
              child: Center(
                child: Text('${_repCounter.reps} 회', style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
              ),
            ),

            // 카운트다운 숫자
            if (isPreparing)
              Container(
                color: Colors.black.withOpacity(0.5), width: double.infinity, height: double.infinity,
                child: Center(
                  child: Text('$prepTimeLeft', style: const TextStyle(fontSize: 150, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🎨 [레벨 3] AR 뼈대 그리는 붓잡이 클래스! (비율 완벽 수정됨)
// ==========================================
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isGoodForm;

  PosePainter(this.pose, this.imageSize, this.isGoodForm);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 
      ..color = isGoodForm ? Colors.greenAccent : Colors.orangeAccent; 

    // 🚀 [핵심 해결책] 안드로이드 센서의 가로/세로 뒤집힘 문제 강제 보정!
    // 무조건 세로가 더 긴 '스마트폰 화면 비율'로 맞춰줍니다.
    final double absoluteImageWidth = imageSize.width > imageSize.height ? imageSize.height : imageSize.width;
    final double absoluteImageHeight = imageSize.width > imageSize.height ? imageSize.width : imageSize.height;

    // 🚀 완벽한 좌표 변환 함수
    Offset translatePoint(double x, double y) {
      return Offset(
        // 전면 카메라 거울 모드 (좌우 반전) + 완벽한 가로 비율 보정
        size.width - (x * size.width / absoluteImageWidth),
        // 완벽한 세로 비율 보정
        y * size.height / absoluteImageHeight,
      );
    }

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = pose.landmarks[type1];
      final p2 = pose.landmarks[type2];
      if (p1 != null && p2 != null && p1.likelihood > 0.5 && p2.likelihood > 0.5) {
        // 기존 translateX 대신 새로 만든 translatePoint 함수를 사용합니다.
        canvas.drawLine(translatePoint(p1.x, p1.y), translatePoint(p2.x, p2.y), paint);
      }
    }

    // 어깨, 골반, 무릎, 발목 선 긋기
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true; 
  }
}