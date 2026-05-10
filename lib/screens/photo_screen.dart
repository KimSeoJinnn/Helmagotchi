import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../data/local_storage.dart';

class ARPhotoScreen extends StatefulWidget {
  const ARPhotoScreen({super.key});

  @override
  State<ARPhotoScreen> createState() => _ARPhotoScreenState();
}

class _ARPhotoScreenState extends State<ARPhotoScreen> {
  CameraController? _cameraController;
  final ScreenshotController _screenshotController = ScreenshotController();

  // 💡 펫의 초기 위치 (화면 중간쯤으로 세팅)
  double _petX = 100; 
  double _petY = 200;
  
  String _equippedAccessory = 'none';
  bool _isFrontCamera = true;

  double _petScale = 1.0;  // 현재 펫의 크기 비율 (기본 1배)
  double _baseScale = 1.0; // 확대/축소할 때 기준이 되는 값

  // 👇 👇 새롭게 추가된 해시태그 변수들 👇 👇
  double _textX = 50;         // 텍스트 초기 가로 위치
  double _textY = 150;        // 텍스트 초기 세로 위치
  double _textScale = 1.0;     // 현재 텍스트 크기 비율
  double _baseTextScale = 1.0; // 확대/축소 기준값
  bool _showTextOverlay = true; // 텍스트 보이기/숨기기 상태 (기본값: 보임)

  @override
  void initState() {
    super.initState();
    _loadAccessory();
    _initCamera();
  }

  // 🔄 카메라 전후면 전환 함수 (에러 방지 완벽 처리!)
  Future<void> _toggleCamera() async {
    // 1. 기존 카메라 장치를 잠깐 다른 곳에 보관해 둡니다.
    final oldController = _cameraController;

    // 2. 화면이 '로딩 중'으로 바뀌도록 컨트롤러를 비우고 방향을 뒤집습니다.
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _cameraController = null; // 👈 이 순간 화면이 까맣게 변하면서 안전해집니다!
    });

    // 3. 보관해둔 기존 카메라를 완전히 꺼줍니다.
    if (oldController != null) {
      await oldController.dispose();
    }

    // 4. 새로운 방향의 카메라를 켭니다!
    await _initCamera();
  }

  Future<void> _loadAccessory() async {
    _equippedAccessory = await LocalStorage.loadEquippedAccessory();
    setState(() {});
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    
    // 💡 _isFrontCamera 값에 따라 전면/후면 방향을 결정합니다!
    final targetDirection = _isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;

    CameraDescription? selectedCamera;
    try {
      selectedCamera = cameras.firstWhere((camera) => camera.lensDirection == targetDirection);
    } catch (e) {
      selectedCamera = cameras.first; // 만약 해당 방향 카메라가 없으면 아무거나 켬
    }

    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  // 📸 촬영 & 자동 저장 기능
  Future<void> _takePicture() async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      
      if (imageBytes != null) {
        // 1. 찰칵! 하자마자 바로 갤러리에 자동 저장합니다.
        await Gal.putImageBytes(imageBytes, name: "helmagotchi_${DateTime.now().millisecondsSinceEpoch}");
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 갤러리에 사진이 저장되었습니다!'), backgroundColor: Colors.green),
          );
        }

        // 2. 저장 후 예쁜 공유용 미리보기 창을 띄웁니다.
        if (mounted) {
          _showPreviewDialog(imageBytes);
        }
      }
    } catch (e) {
      debugPrint("Capture error: $e");
    }
  }

  // 📱 미리보기 & 공유 전용 팝업 창 (오버플로우 해결 버전)
  void _showPreviewDialog(Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("📸 인생샷 완성!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            
            // 💡 Flexible을 사용하여 화면이 작아도 노란 바리케이드(오버플로우)가 뜨지 않고 알아서 줄어듭니다!
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(imageBytes, fit: BoxFit.contain), 
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 🚀 길쭉하고 누르기 편한 단일 공유 버튼!
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share, size: 20),
                label: const Text("인스타 스토리 / 공유하기", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () async {
                  final xFile = XFile.fromData(imageBytes, mimeType: 'image/png', name: 'workout.png');
                  await Share.shareXFiles([xFile], text: '#헬마고치 #오운완 득근득근! 💪');
                  if (mounted) Navigator.pop(context); // 공유 창 띄운 후 팝업 닫기
                },
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 닫기 버튼
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("닫기", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Screenshot(
            controller: _screenshotController,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. 카메라 화면 (비율 깨짐 방지 & 화면에 꽉 차게!)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover, // 👈 화면 비율에 맞춰서 남는 여백 없이 꽉 채워줍니다(Crop 효과)
                    child: SizedBox(
                      width: 100,
                      // 카메라 렌즈가 가진 고유의 원본 비율을 계산해서 그대로 적용합니다.
                      height: 100 * _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
                
                // 💡 2. 크기를 키워도 터치가 완벽하게 먹히는 헬마고치!
                Positioned(
                  left: _petX,
                  top: _petY,
                  // 🌟 핵심: Transform을 바깥으로 빼서 '터치 센서'도 같이 커지게 만듭니다!
                  child: Transform.scale(
                    scale: _petScale,
                    child: GestureDetector(
                      // 터치 시작 시 기준 크기 저장
                      onScaleStart: (details) {
                        _baseScale = _petScale;
                      },
                      // 이동 및 확대/축소
                      onScaleUpdate: (details) {
                        setState(() {
                          _petX += details.focalPointDelta.dx;
                          _petY += details.focalPointDelta.dy;
                          _petScale = (_baseScale * details.scale).clamp(0.5, 3.0);
                        });
                      },
                      child: SizedBox(
                        width: 140, 
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Image.asset('assets/images/photo.png', width: 100, filterQuality: FilterQuality.none),
                            
                            // 악세사리 유지
                            if (_equippedAccessory != 'none')
                              Builder(
                                builder: (context) {
                                  double tPos = 0; double rPos = 0; double w = 30;
                                  String imageFileName = _equippedAccessory;

                                  if (_equippedAccessory == 'crown') { tPos = 10; rPos = 50; w = 30; }
                                  else if (_equippedAccessory == 'wing') { tPos = 35; rPos = 85; w = 50; imageFileName = 'wing_color'; }
                                  else if (_equippedAccessory == 'ribbon') { tPos = 15; rPos = 50; w = 35; }
                                  else if (_equippedAccessory == 'sunglasses') { tPos = 25; rPos = 42; w = 50; }
                                  
                                  return Positioned(
                                    top: tPos, right: rPos, 
                                    child: Image.asset('assets/images/$imageFileName.png', width: w, filterQuality: FilterQuality.none)
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

          // 👇 해시태그 오버레이
          if (_showTextOverlay)
            Positioned(
              left: _textX,
              top: _textY,
              // 🌟 핵심: 텍스트 터치 센서도 글씨와 함께 커지도록 밖으로 뺐습니다!
              child: Transform.scale(
                scale: _textScale,
                child: GestureDetector(
                  onScaleStart: (details) {
                    _baseTextScale = _textScale;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _textX += details.focalPointDelta.dx;
                      _textY += details.focalPointDelta.dy;
                      _textScale = (_baseTextScale * details.scale).clamp(0.5, 4.0);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.transparent, // 투명한 배경을 깔아서 여유로운 터치 공간 확보
                    child: Stack( 
                      children: [
                        // 1. 흰색 테두리
                        Text(
                          '#오운완 #헬마고치',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4
                              ..color = Colors.white,
                          ),
                        ),
                        // 2. 실제 검은 글씨
                        const Text(
                          '#오운완 #헬마고치',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

          // ❌ 뒤로 가기 버튼
          Positioned(
            top: 50, left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 👇 👇 새롭게 추가된 해시태그 토글 버튼 👇 👇
          Positioned(
            top: 50, right: 20, // 우측 상단 배치
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showTextOverlay = !_showTextOverlay; // true <-> false 뒤집기
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4), // 반투명 배경으로 시인성 확보
                  shape: BoxShape.circle,
                ),
                // 현재 상태에 따라 아이콘을 바꿔서 친절하게 알려줍니다.
                child: Icon(
                  _showTextOverlay ? Icons.label : Icons.label_off_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),

           // 📸 안내 문구 추가!
          const Positioned(
            bottom: 140, left: 0, right: 0,
            child: Center(
              child: Text(
                '👆 헬마고치를 드래그해서 위치를 맞춰보세요!',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)]
                ),
              ),
            ),
          ),

          // 📸 하단 조작 버튼 영역 (사진 촬영 + 카메라 전환)
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. 가운데 사진 촬영 버튼
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white.withOpacity(0.5),
                    ),
                    child: const Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 40)),
                  ),
                ),
                
                // 2. 오른쪽 카메라 전환 버튼
                Positioned(
                  right: 40, // 👈 오른쪽 벽에서 40만큼 띄워서 배치
                  child: GestureDetector(
                    onTap: _toggleCamera,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4), // 살짝 반투명한 까만 배경으로 시인성 확보
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}