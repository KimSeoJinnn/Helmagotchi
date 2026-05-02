import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WorkoutCalendarScreen extends StatefulWidget {
  const WorkoutCalendarScreen({super.key});

  @override
  State<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends State<WorkoutCalendarScreen> {
  Map<String, dynamic> _dailyStats = {};
  int _overallTotal = 0;
  int _overallBest = 0;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now(); 

  // 💡 운동을 처음 시작한 날짜를 기억할 변수
  String? _firstDateKey;
  DateTime? _firstWorkoutDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 📂 전체 기록 & 날짜별 기록 싹 다 불러오기
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? statsJson = prefs.getString('daily_stats');
    
    setState(() {
      _overallTotal = prefs.getInt('total_squats') ?? 0;
      _overallBest = prefs.getInt('best_squats') ?? 0;
      
      if (statsJson != null) {
        _dailyStats = json.decode(statsJson);

        // 🔥 날짜들을 정렬해서 가장 처음 운동한 날짜 찾기
        if (_dailyStats.isNotEmpty) {
          List<String> keys = _dailyStats.keys.toList();
          keys.sort(); // 오름차순 정렬 (가장 옛날 날짜가 맨 앞으로)
          _firstDateKey = keys.first;
          
          List<String> parts = _firstDateKey!.split('-');
          _firstWorkoutDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      }
    });
  }

  // 🎨 출석 색상 결정 (처음 시작일, 완료, 휴식)
  Color _getDayColor(DateTime day) {
    String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    
    // 1. 처음 운동을 시작한 날! (우선순위 1등)
    if (dateKey == _firstDateKey) return Colors.blueAccent; 
    
    // 2. 아직 안 온 미래 날짜
    if (day.isAfter(DateTime.now())) return Colors.grey.shade200; 
    
    // 3. 운동한 날 vs 안 한 날
    int dailyReps = _dailyStats[dateKey]?['reps'] ?? 0;
    return dailyReps > 0 ? Colors.greenAccent : Colors.redAccent.withOpacity(0.2);
  }

  @override
  Widget build(BuildContext context) {
    String selectedDateKey = "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";
    int dailyReps = _dailyStats[selectedDateKey]?['reps'] ?? 0;
    int dailyMax = _dailyStats[selectedDateKey]?['max'] ?? 0;

    // 💡 누른 날짜가 첫 운동 시작일보다 '과거'인지 확인하는 로직
    DateTime selectedDateOnly = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    bool isBeforeStart = _firstWorkoutDate == null || selectedDateOnly.isBefore(_firstWorkoutDate!);

    // 과거라면 전체 기록을 0회로 덮어씌움!
    String displayTotal = isBeforeStart ? '0 회' : '$_overallTotal 회';
    String displayBest = isBeforeStart ? '0 회' : '$_overallBest 회';
    
    // 과거라면 색상도 차분한 검은색/회색 톤으로 변경
    Color totalCardColor = isBeforeStart ? Colors.grey.shade600 : Colors.blueAccent;
    Color bestCardColor = isBeforeStart ? Colors.grey.shade600 : Colors.amber.shade700;

    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text('운동 일지 및 통계', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        // 👇 해결 1: 달력이 길어져도 에러가 나지 않도록 스크롤 기능 추가!
        child: SingleChildScrollView( 
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              // 📅 캘린더 영역
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    // 1. 일반 날짜 빌더 (기존 유지)
                    defaultBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _getDayColor(day), borderRadius: BorderRadius.circular(10)), 
                        child: Text('${day.day}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      );
                    },
                    // 2. 선택된 날짜 빌더 (기존 유지)
                    selectedBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _getDayColor(day), 
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black87, width: 2) 
                        ),
                        child: Text('${day.day}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      );
                    },
                    // 🔥 3. [새로 추가] 오늘 날짜 빌더: 남색 원을 없애고 테두리로만 표시!
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _getDayColor(day), // 파랑/초록/빨강 로직 그대로 적용
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueAccent, width: 2.5), // 오늘임을 알 수 있게 파란 테두리!
                        ),
                        child: Text('${day.day}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                ),
              ),
              
              const SizedBox(height: 15),
              // 👇 설명 텍스트도 직관적으로 수정했습니다.
              const Text('💡파란색: 시작일 / 초록색: 운동 완료 / 붉은색: 휴식', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 📊 프리미엄 통계 대시보드 영역 (Expanded 제거하여 오버플로우 방지)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_selectedDay.month}월 ${_selectedDay.day}일 운동 리포트', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const Icon(Icons.analytics, color: Colors.deepPurpleAccent),
                      ],
                    ),
                    const Divider(height: 30, thickness: 1.5, color: Colors.black12),
                    
                    // 1. 역대 누적 스탯 (전체 - 과거를 누르면 0으로 표시)
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('💎 총 누적 수행량', 'Total Volume', displayTotal, totalCardColor)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildStatCard('👑 역대 최고 기록', 'Personal Best', displayBest, bestCardColor)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // 2. 선택한 날짜 스탯 (오늘)
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('🎯 일일 수행량', 'Daily Volume', '$dailyReps 회', dailyReps > 0 ? Colors.green : Colors.grey)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildStatCard('🔥 일일 최고 기록', 'Daily Max', '$dailyMax 회', dailyMax > 0 ? Colors.deepOrangeAccent : Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20), // 아래쪽 여백 추가
            ],
          ),
        ),
      ),
    );
  }

  // 💡 통계 카드 UI 헬퍼 함수
  Widget _buildStatCard(String title, String subtitle, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: accentColor)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)), // 글씨는 깔끔하게 검은색 유지!
        ],
      ),
    );
  }
}