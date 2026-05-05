import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // ==========================================
  // 🎒 악세사리 해금 & 장착 저장 기능 (Stack 겹치기용)
  // ==========================================
  
  // 1) 현재 장착 중인 악세사리 1개 저장 & 불러오기
  static Future<void> saveEquippedAccessory(String accessoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('equipped_accessory', accessoryId);
  }

  static Future<String> loadEquippedAccessory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('equipped_accessory') ?? 'none'; // 아무것도 안 꼈으면 'none'
  }

  // 2) 경험치로 해금한 악세사리 목록 전체 저장 & 불러오기
  static Future<void> saveUnlockedAccessories(List<String> accessories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_accessories', accessories);
  }

  static Future<List<String>> loadUnlockedAccessories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('unlocked_accessories') ?? ['none']; // 기본은 'none'만 보유
  }
}