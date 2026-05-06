import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';

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

  Future<void> _takePicture() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        await Gal.putImageBytes(image, name: "helmagotchi_${DateTime.now().millisecondsSinceEpoch}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 찰칵! 갤러리에 사진이 저장되었습니다!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint("Screenshot error: $e");
    }
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
                      height: 100 / _cameraController!.value.aspectRatio,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
                
                // 💡 2. 손가락으로 드래그만 가능한 헬마고치! (확대/축소 제거)
                Positioned(
                  left: _petX,
                  top: _petY,
                  child: GestureDetector(
                    // 👆 오직 이동(드래그)만 담당합니다!
                    onPanUpdate: (details) {
                      setState(() {
                        _petX += details.delta.dx;
                        _petY += details.delta.dy;
                      });
                    },
                    child: SizedBox( // 👈 복잡했던 Transform.scale을 완전히 빼버렸습니다.
                      width: 140, 
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset('assets/images/photo.png', width: 100, filterQuality: FilterQuality.none),
                          
                          // 악세사리 (사진 화면 전용 핏 & 이미지 바꿔치기!)
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