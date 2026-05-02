import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // 👈 이거 꼭 추가해주세요!

// 🚀 이 한 줄이 핵심! 방금 완벽하게 고친 home_screen.dart를 불러옵니다!
import 'screens/home_screen.dart';

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
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.juaTextTheme(Theme.of(context).textTheme),
      ),
      home: const MainHomeScreen(), // 🚀 이제 드디어 새 파일을 가리킵니다!
    );
  }
}