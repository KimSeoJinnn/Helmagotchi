import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// 다른 폴더의 파일들 불러오기
import '../main.dart'; // 전역 변수 cameras를 가져오기 위해
import '../ai/pose_analyzer.dart';
import '../ai/rep_counter.dart';
import '../data/exp_service.dart';
import '../widgets/pose_painter.dart'; // 방금 만든 뼈대 그리기 파일

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
    bool isNewRecord = widget.isRecordMode && (_repCounter.reps > widget.currentBestRecord);
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

            Positioned(
              bottom: 100, left: 0, right: 0,
              child: Center(
                child: Text('${_repCounter.reps} 회', style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
              ),
            ),

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