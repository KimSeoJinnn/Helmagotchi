import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// 💡 새로 추가된 화면 녹화 & 갤러리 저장 패키지들
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

// 💡 FFmpeg 패키지 추가 
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
 
// 💡 상단/하단 바를 숨기기 위해 꼭 필요해요!
import 'package:flutter/services.dart';

import '../main.dart'; 
import '../ai/pose_analyzer.dart';
import '../ai/rep_counter.dart';
import '../data/exp_service.dart';

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
  int prepTimeLeft = 5; 

  Pose? _currentPose;
  Size? _imageSize;

  Timer? _timeoutTimer;
  int _lastRepCount = 0;
  int _timeoutSecondsLeft = 5; 

  bool _isSquattingDown = false;

  // 🎥 화면 녹화 관련 변수 (새로운 방식!)
  bool _isRecording = false;
  bool _hasRecorded = false; 
  String? _videoPath; // 녹화된 파일의 진짜 경로 저장
  bool _isRecordingArmed = false; // 👈 💡 추가: 준비 시간에 눌러둔 '녹화 예약' 상태

  @override
  void initState() {
    super.initState();

    // 💡 [핵심] 화면에 들어오자마자 상단 배터리/시간, 하단 버튼을 싹 숨깁니다! (몰입 모드)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[1], 
        ResolutionPreset.medium, 
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888
      );
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() => _isCameraInitialized = true);

        _startPrepTimer();
        _startAIStream(); 
      });
    }
  }

  @override
  void dispose() {
    // 💡 [핵심] 운동 화면을 나갈 때는 시스템 바를 원래대로 복구해 줍니다!
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    _controller?.dispose();
    _poseDetector.close();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startAIStream() {
    if (_controller == null || _controller!.value.isStreamingImages) return;
    
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

        if (mounted) {
          setState(() {
            if (poses.isNotEmpty) {
              _currentPose = poses.first;
              _imageSize = imageSize;
              final poseResult = PoseAnalyzer.analyze(_currentPose!);

              if (!isPreparing && poseResult != null) {
                _repCounter.update(poseResult);

                double? kneeAngle = poseResult.leftKneeAngle ?? poseResult.rightKneeAngle;
                if (kneeAngle != null) {
                  if (kneeAngle < 110.0) _isSquattingDown = true; 
                  else if (kneeAngle > 150.0) _isSquattingDown = false; 
                }

                if (widget.isRecordMode && _repCounter.reps > _lastRepCount) {
                  _lastRepCount = _repCounter.reps;
                  _resetTimeoutTimer();
                }
              }
            } else {
              _isSquattingDown = false;
            }
          });
        }
      } catch (e) {
        print('AI 에러: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _resetTimeoutTimer() {
    if (!widget.isRecordMode) return;
    _timeoutTimer?.cancel();
    setState(() => _timeoutSecondsLeft = 5); 
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || isPreparing) { timer.cancel(); return; }
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

  void _startPrepTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (prepTimeLeft > 1) {
          prepTimeLeft--;
        } else {
          isPreparing = false;
          timer.cancel();
          if (widget.isRecordMode) _resetTimeoutTimer();
        }
      });
    });
  }

  void _showWorkoutCompleteDialog({bool isAutoEnd = false}) async {
    _timeoutTimer?.cancel();

    // 💡 화면 녹화 종료 (새로운 패키지 적용!)
    if (_isRecording) {
      try {
        String path = await FlutterScreenRecording.stopRecordScreen;
        if (path.isNotEmpty) {
          _videoPath = path; // 진짜 경로 저장!
        }
      } catch (e) {
        print("화면 녹화 자동 종료 에러: $e");
      }
      setState(() { _isRecording = false; });
    }

    // 0회 처리 로직 (기존과 동일)
    if (_repCounter.reps == 0) {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text('👀 앗!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            isAutoEnd ? '5초 동안 움직임이 없어 종료되었습니다.\n아직 1개도 하지 않았네요!' : '아직 스쿼트를 1개도 하지 않았습니다.\n이대로 운동을 종료할까요?', 
            style: const TextStyle(color: Colors.white70, fontSize: 16)
          ),
          actions: [
            if (!isAutoEnd) 
              TextButton(
                onPressed: () { 
                  Navigator.pop(dialogContext); 
                  if (widget.isRecordMode) _resetTimeoutTimer(); 
                }, 
                child: const Text('계속하기', style: TextStyle(color: Colors.grey, fontSize: 16))
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), 
              onPressed: () { 
                Navigator.pop(dialogContext); 
                if (mounted) Navigator.pop(context, {'reps': 0}); 
              }, 
              child: const Text('종료하기')
            ),
          ],
        ),
      );
      return;
    }

    int earnedExp = _repCounter.reps * ExpService.squatExp;
    bool isNewRecord = widget.isRecordMode && (_repCounter.reps > widget.currentBestRecord);
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Center(child: Text(isNewRecord ? '🏆 신기록 달성!' : '🎉 오운완!', style: TextStyle(color: isNewRecord ? Colors.amber : Colors.white, fontWeight: FontWeight.bold, fontSize: 24))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isNewRecord) const Text('축하합니다! 기존의 한계를 넘어섰습니다!', style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('🔥 이번 기록: ${_repCounter.reps}회', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text('경험치 획득: $earnedExp XP', style: const TextStyle(color: Colors.greenAccent, fontSize: 16), textAlign: TextAlign.center),
            
            // 🎬 갤러리 저장 버튼 영역
            if (_hasRecorded && _videoPath != null) ...[
              const Divider(color: Colors.white24, height: 30, thickness: 1),
              const Text('🎬 녹화된 영상을 어떻게 저장할까요?', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 15),
              
              // ⚡ 1. 타임랩스(4배속) 저장 버튼
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () async {
                  // 로딩 빙글빙글 띄우기
                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                  );

                  try {
                    Directory tempDir = await getTemporaryDirectory();
                    String outputPath = "${tempDir.path}/timelapse_${DateTime.now().millisecondsSinceEpoch}.mp4";

                    // 4배속 + 소리 제거 마법 주문
                    String command = "-y -i $_videoPath -filter:v \"setpts=0.25*PTS\" -c:v mpeg4 -an $outputPath";

                    await FFmpegKit.execute(command).then((session) async {
                      final returnCode = await session.getReturnCode();
                      
                      Navigator.pop(dialogContext); // 로딩 팝업 닫기

                      if (ReturnCode.isSuccess(returnCode)) {
                        bool hasAccess = await Gal.hasAccess();
                        if (!hasAccess) await Gal.requestAccess();
                        
                        await Gal.putVideo(outputPath); // 갤러리에 저장
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ 타임랩스 영상이 갤러리에 쏙 들어갔어요!')));
                          Navigator.pop(dialogContext); 
                          Navigator.pop(context, {'reps': _repCounter.reps}); 
                        }
                      } else {
                        print("FFmpeg 변환 실패");
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('영상 변환에 실패했습니다.')));
                      }
                    });
                  } catch (e) {
                    Navigator.pop(dialogContext);
                    print("타임랩스 에러: $e");
                  }
                },
                icon: const Icon(Icons.fast_forward),
                label: const Text('타임랩스(4배속)로 갤러리 저장', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 10),

              // 📸 2. 일반 속도 저장 버튼
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () async { 
                  try {
                    bool hasAccess = await Gal.hasAccess();
                    if (!hasAccess) await Gal.requestAccess();
                    
                    await Gal.putVideo(_videoPath!); 
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📸 갤러리에 일반 영상이 저장되었습니다!')));
                      Navigator.pop(dialogContext); 
                      Navigator.pop(context, {'reps': _repCounter.reps}); 
                    }
                  } catch (e) {
                    print("갤러리 저장 실패: $e");
                  }
                },
                icon: const Icon(Icons.save_alt),
                label: const Text('일반 속도로 갤러리 저장', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 5),

              // 🗑️ 3. 저장 안 함 버튼
              TextButton(
                onPressed: () { 
                  Navigator.pop(dialogContext); 
                  if (mounted) Navigator.pop(context, {'reps': _repCounter.reps}); 
                },
                child: const Text('영상 저장 안 함 (기록만 저장)', style: TextStyle(color: Colors.grey)),
              )
            ]
          ],
        ),
        actions: _hasRecorded && _videoPath != null ? [] : [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), 
              onPressed: () { 
                Navigator.pop(dialogContext); 
                if (mounted) Navigator.pop(context, {'reps': _repCounter.reps}); 
              }, 
              child: const Text('기록 저장하고 나가기', style: TextStyle(fontWeight: FontWeight.bold))
            ),
          )
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
                ? Positioned.fill(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1 / _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  )
                : const Center(child: Text("카메라 대기 중", style: TextStyle(color: Colors.white))),

            if (widget.isRecordMode && !isPreparing)
              Positioned(top: 30, left: 0, right: 0, child: Center(child: Text('🔥 남은 시간: $_timeoutSecondsLeft초', style: const TextStyle(fontSize: 30, color: Colors.redAccent, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)])))),

            Positioned(
              top: 80, left: 20, right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_repCounter.lastJudgement.isGoodForm ? '자세 완벽해요!' : _repCounter.lastJudgement.feedback ?? '자세 주의', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _repCounter.lastJudgement.isGoodForm ? Colors.greenAccent : Colors.redAccent, shadows: const [Shadow(color: Colors.black, blurRadius: 5)])),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: _showWorkoutCompleteDialog, child: const Text('운동 종료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                ],
              ),
            ),

            Positioned(bottom: 150, left: 0, right: 0, child: Center(child: Text('${_repCounter.reps} 회', style: const TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 5)])))),

            if (isPreparing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.isRecordMode ? '최고 기록 측정 준비!' : '여기에 서세요!', style: const TextStyle(fontSize: 30, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Text('$prepTimeLeft', style: const TextStyle(fontSize: 150, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),

            // 💡 4. 화면 녹화 버튼 (즉시 실행으로 롤백!)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    if (_isRecording) {
                      // ⏹️ 녹화 수동 정지
                      try {
                        String path = await FlutterScreenRecording.stopRecordScreen;
                        if (path.isNotEmpty) {
                          _videoPath = path;
                        }
                        setState(() { _isRecording = false; });
                      } catch (e) {
                        print("수동 화면 녹화 종료 에러: $e");
                      }
                    } else {
                      // ⏺️ 화면 녹화 즉시 시작! (준비 시간이든 운동 중이든 상관없이 누르면 바로 시작)
                      try {
                        bool started = await FlutterScreenRecording.startRecordScreen("helmagotchi_${DateTime.now().millisecondsSinceEpoch}");
                        if (started) {
                          setState(() { 
                            _isRecording = true; 
                            _hasRecorded = true; 
                          });
                        }
                      } catch (e) {
                        print("화면 녹화 시작 에러: $e");
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isRecording ? 80 : 70,
                    height: _isRecording ? 80 : 70,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent.withOpacity(0.8) : Colors.white54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    child: Center(
                      child: Container(
                        width: _isRecording ? 30 : 50,
                        height: _isRecording ? 30 : 50,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(_isRecording ? 8 : 25), 
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 20,
              bottom: 30,
              child: Container(
                padding: const EdgeInsets.all(12), 
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(20), 
                  border: Border.all(color: Colors.greenAccent, width: 3), 
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)], 
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Image.asset(
                    _isSquattingDown ? 'assets/images/pet_squat_down.png' : 'assets/images/pet_squat_up.png',  
                    key: ValueKey(_isSquattingDown),
                    width: 100, 
                    filterQuality: FilterQuality.none, 
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}