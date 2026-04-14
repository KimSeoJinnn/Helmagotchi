import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'; 
import 'ai/pose_analyzer.dart'; 
import 'package:google_fonts/google_fonts.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.orange, // 메인 색상도 따뜻하게 변경
        // 🚀 [마법의 코드] 앱 전체 폰트를 '배달의민족 주아체' 느낌으로 한 방에 변경!
        textTheme: GoogleFonts.juaTextTheme(Theme.of(context).textTheme),
      ),
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
  int myBestSquats = 0; 
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
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

    if (result != null) {
      int completedReps = result['reps'] ?? 0;
      if (completedReps > 0) {
        int titlesCountBeforeWorkout = _titleService.getUnlockedTitles(myUser).length;

        setState(() {
          myTotalSquats += completedReps;
          myUser.totalSquatCount += completedReps; 
          
          // 👇 🚀 [수정] 측정 모드일 때만 최고 기록 업데이트를 수행합니다!
          if (isRecordMode && completedReps > myBestSquats) {
            myBestSquats = completedReps;
          }

          myUser = _expService.addExpByWorkout(myUser, WorkoutType.squat, completedReps);
          WorkoutService().handleMovement(WorkoutEvent(type: WorkoutType.squat, timestamp: DateTime.now()));
        });

        final titlesAfterWorkout = _titleService.getUnlockedTitles(myUser);
        if (titlesAfterWorkout.length > titlesCountBeforeWorkout) {
          Future.delayed(const Duration(milliseconds: 500), () => _showNewTitlePopup(titlesAfterWorkout.last));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int requiredExp = myUser.level * 100;
    double expRatio = myUser.currentExp / requiredExp;
    if (expRatio > 1.0) expRatio = 1.0;

    String displayTitle = _selectedTitle ?? _titleService.getLatestUnlockedTitle(myUser)?.name ?? "헬린이";

    return Scaffold(
      body: Container(
        // 🌈 3단계에서 적용했던 파스텔 배경!
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9C4), Color(0xFFFFCC80)], 
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🏷️ 1. 레벨 및 호칭 뱃지 (하얗고 둥글게!)
              GestureDetector(
                onTap: _showTitleListSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white, // 배경을 완전 흰색으로!
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))], // 은은한 그림자
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lv.${myUser.level} $displayTitle', style: const TextStyle(fontSize: 26, color: Colors.brown, fontWeight: FontWeight.bold)), // 글씨를 진한 갈색으로!
                      const SizedBox(width: 10),
                      const Icon(Icons.edit, color: Colors.orangeAccent, size: 22), 
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // 🔋 2. 경험치 바 (게이지가 뚜렷하게 보이게!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Container(
                  height: 28, // 두께를 살짝 키움
                  decoration: BoxDecoration(
                    color: Colors.white, // 빈 게이지바 배경을 흰색으로!
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500), curve: Curves.easeInOut,
                        width: (MediaQuery.of(context).size.width - 100) * expRatio,
                        decoration: BoxDecoration(
                          color: Colors.lightGreen, // 게이지 색상을 산뜻한 연두색으로!
                          borderRadius: BorderRadius.circular(15)
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 15),
                          child: Text(
                            '${myUser.currentExp} / $requiredExp XP', 
                            // 그림자 빼고 글씨를 진한 색으로!
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // 📊 3. 누적 & 최고 기록 텍스트 (색상 변경)
              Text('누적 스쿼트: $myTotalSquats회', style: const TextStyle(fontSize: 16, color: Colors.brown, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5), 
              Text('🏆 최고 기록: $myBestSquats회', style: const TextStyle(fontSize: 22, color: Colors.deepOrange, fontWeight: FontWeight.bold)), // 색상 강조!
              const SizedBox(height: 20),

              // 🐥 펫 이미지
              Builder(
                builder: (context) {
                  String petImagePath = 'assets/images/level_1.png'; 
                  if (myUser.level >= 3) petImagePath = 'assets/images/level_3.png'; 
                  else if (myUser.level >= 2) petImagePath = 'assets/images/level_2.png'; 

                  return AnimatedBuilder(
                    animation: _idleAnimation,
                    builder: (context, child) => Transform.translate(offset: Offset(0, _idleAnimation.value), child: child),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.75, height: MediaQuery.of(context).size.width * 0.75,
                      child: Image.asset(petImagePath, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              // 🍮 4. 일반 연습 버튼 (젤리 버튼 스타일)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.grey.shade400, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => _startWorkout(false), 
                  child: const Text('일반 연습하기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),

              // 🍮 5. 최고 기록 측정 버튼 (젤리 버튼 스타일)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.orange.shade800, offset: const Offset(0, 5))], // 진한 그림자
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => _startWorkout(true), 
                  child: const Text('🔥 최고 기록 측정하기', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ==========================================
// 📸 2. 카메라 운동 화면 (AI 로직 연동) + 오버레이
// ==========================================
class CameraWorkoutScreen extends StatefulWidget {
  final bool isRecordMode; 
  final int currentBestRecord; 

  const CameraWorkoutScreen({
    super.key, 
    required this.isRecordMode,
    required this.currentBestRecord, 
  }); 

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

  Pose? _currentPose;
  Size? _imageSize;

  late AnimationController _pipController;
  late Animation<double> _pipAnimation;

  bool _showSkeleton = true;

  Timer? _timeoutTimer;
  int _lastRepCount = 0;
  int _timeoutSecondsLeft = 3; 

  @override
  void initState() {
    super.initState();
    
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
                  _currentPose = pose; 
                  _imageSize = imageSize; 
                  
                  if (!isPreparing && poseResult != null) {
                    _repCounter.update(poseResult); 
                    
                    if (widget.isRecordMode && _repCounter.reps > _lastRepCount) {
                      _lastRepCount = _repCounter.reps;
                      _resetTimeoutTimer();
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
      });
    }
  }

  void _resetTimeoutTimer() {
    if (!widget.isRecordMode) return; 

    _timeoutTimer?.cancel(); 
    setState(() {
      _timeoutSecondsLeft = 3; 
    });
    
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || isPreparing) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeoutSecondsLeft > 1) {
          _timeoutSecondsLeft--; 
        } else {
          timer.cancel(); 
          _showWorkoutCompleteDialog(isAutoEnd: true); 
        }
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close(); 
    _pipController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startPrepTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (prepTimeLeft > 1) { 
          prepTimeLeft--; 
        } else { 
          isPreparing = false; 
          timer.cancel(); 
          
          if (widget.isRecordMode) {
            _resetTimeoutTimer(); 
          }
        }
      });
    });
  }

  void _showWorkoutCompleteDialog({bool isAutoEnd = false}) {
    _timeoutTimer?.cancel(); 

    if (_repCounter.reps == 0) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text('👀 앗!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            isAutoEnd ? '3초 동안 움직임이 없어 종료되었습니다.\n아직 1개도 하지 않았네요!' : '아직 스쿼트를 1개도 하지 않았습니다.\n이대로 운동을 종료할까요?', 
            style: const TextStyle(color: Colors.white70, fontSize: 16)
          ),
          actions: [
            if (!isAutoEnd) 
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.isRecordMode) _resetTimeoutTimer(); 
                }, 
                child: const Text('계속하기', style: TextStyle(color: Colors.grey, fontSize: 16))
              ),
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

    // 👇 🚀 [수정] "측정 모드"일 때만 신기록 달성 여부를 확인합니다!
    bool isNewRecord = widget.isRecordMode && (_repCounter.reps > widget.currentBestRecord);

    // 팝업 타이틀 결정 (측정 모드에서 신기록일 때만 금빛 타이틀)
    String dialogTitle = isNewRecord ? '🏆 신기록 달성!' : (isAutoEnd ? '⏱️ 한계 도달!' : '🎉 오운완!');
    Color titleColor = isNewRecord ? Colors.amber : Colors.white;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: Text(dialogTitle, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNewRecord)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('축하합니다! 기존의 한계를 넘어섰습니다!', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            
            if (isAutoEnd && !isNewRecord)
              const Text('3초 이상 움직임이 없어 측정 종료!', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            
            const SizedBox(height: 5),
            Text('🔥 이번 기록: ${_repCounter.reps}회', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('경험치 획득: $earnedExp XP', style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () { Navigator.pop(context); Navigator.pop(context, {'reps': _repCounter.reps}); },
            child: const Text('기록 저장하고 나가기'),
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
            // 📸 카메라 & 뼈대
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
                            if (_showSkeleton && _currentPose != null && _imageSize != null)
                              CustomPaint(
                                painter: PosePainter(_currentPose!, _imageSize!, _repCounter.lastJudgement.isGoodForm),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const Center(child: Text("카메라 대기 중", style: TextStyle(color: Colors.white))),

            // 시한폭탄 UI (측정 모드일 때만 표시)
            if (widget.isRecordMode && !isPreparing)
              Positioned(
                top: 30, left: 0, right: 0,
                child: Center(
                  child: Text(
                    '🔥 남은 시간: $_timeoutSecondsLeft초',
                    style: const TextStyle(
                      fontSize: 30, color: Colors.redAccent, fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                ),
              ),

            // 🥈 PT 쌤 (PIP)
            if (!isPreparing)
              Positioned(
                top: 130, right: 20,
                child: Container(
                  width: 80, height: 100,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.greenAccent, width: 2)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('PT 쌤', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      AnimatedBuilder(
                        animation: _pipAnimation,
                        builder: (context, child) => Transform.translate(offset: Offset(0, _pipAnimation.value), child: const Icon(Icons.accessibility_new, color: Colors.greenAccent, size: 40)),
                      ),
                    ],
                  ),
                ),
              ),

            // 🕶️ AR 뼈대 토글 버튼
            if (!isPreparing)
              Positioned(
                top: 290, right: 30,
                child: GestureDetector(
                  onTap: () => setState(() => _showSkeleton = !_showSkeleton),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _showSkeleton ? Colors.greenAccent : Colors.grey[800], shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                    ),
                    child: Icon(_showSkeleton ? Icons.visibility : Icons.visibility_off, color: _showSkeleton ? Colors.black : Colors.white54, size: 28),
                  ),
                ),
              ),

            // 🥉 준비 가이드 실루엣
            if (isPreparing)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.isRecordMode ? '최고 기록 측정 준비!' : '여기에 서세요!', style: const TextStyle(fontSize: 30, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    Icon(Icons.accessibility_new, size: 300, color: Colors.white.withOpacity(0.4)),
                  ],
                ),
              ),

            // 상단 종료 버튼 영역
            Positioned(
              top: 80, left: 20, right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _repCounter.lastJudgement.isGoodForm ? '자세 완벽해요!' : _repCounter.lastJudgement.feedback ?? '자세 주의',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _repCounter.lastJudgement.isGoodForm ? Colors.greenAccent : Colors.redAccent, shadows: const [Shadow(color: Colors.black, blurRadius: 5)]),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: _showWorkoutCompleteDialog,
                    child: const Text('운동 종료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),

            // 하단 횟수 표시
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
                child: Center(child: Text('$prepTimeLeft', style: const TextStyle(fontSize: 150, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🎨 AR 뼈대 클래스
// ==========================================
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final bool isGoodForm;

  PosePainter(this.pose, this.imageSize, this.isGoodForm);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 6.0..color = isGoodForm ? Colors.greenAccent : Colors.orangeAccent; 

    final double absoluteImageWidth = imageSize.width > imageSize.height ? imageSize.height : imageSize.width;
    final double absoluteImageHeight = imageSize.width > imageSize.height ? imageSize.width : imageSize.height;

    Offset translatePoint(double x, double y) {
      return Offset(size.width - (x * size.width / absoluteImageWidth), y * size.height / absoluteImageHeight);
    }

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = pose.landmarks[type1];
      final p2 = pose.landmarks[type2];
      if (p1 != null && p2 != null && p1.likelihood > 0.5 && p2.likelihood > 0.5) {
        canvas.drawLine(translatePoint(p1.x, p1.y), translatePoint(p2.x, p2.y), paint);
      }
    }

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
  bool shouldRepaint(covariant PosePainter oldDelegate) => true; 
}