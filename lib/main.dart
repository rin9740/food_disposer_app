import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart'; // FlutterFire가 자동 생성

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase 초기화 성공!');
  } catch (e) {
    print('❌ Firebase 초기화 실패: $e');
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '음식물 처리기',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Firebase Database
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('devices/device_001');
  
  // 상태 관리
  String currentStatus = 'idle';
  String lastUpdateTime = '-';
  bool notificationEnabled = true;
  bool isFirebaseConnected = false;
  
  // 타이머 관련
  Timer? _timer;
  int _elapsedSeconds = 0;
  
  // 애니메이션
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    
    _listenToFirebase();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  // Firebase 실시간 감시
  void _listenToFirebase() {
    _dbRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        setState(() {
          currentStatus = data['status'] ?? 'idle';
          lastUpdateTime = data['lastUpdate'] ?? '-';
          isFirebaseConnected = true;
          
          // 상태에 따라 애니메이션/타이머 제어
          if (currentStatus == 'running') {
            if (!_animationController.isAnimating) {
              _animationController.repeat();
            }
            if (_timer == null || !_timer!.isActive) {
              _startTimer();
            }
          } else {
            _animationController.stop();
            _animationController.reset();
            if (currentStatus != 'running') {
              _stopTimer();
            }
          }
        });
      }
    }, onError: (error) {
      print('Firebase 오류: $error');
      setState(() {
        isFirebaseConnected = false;
      });
    });
  }
  
  // Firebase에 상태 업데이트
  Future<void> _updateFirebaseStatus(String status) async {
    try {
      await _dbRef.update({
        'status': status,
        'lastUpdate': DateTime.now().toString().substring(0, 19),
        'notificationSent': false,
      });
      print('✅ Firebase 업데이트 성공: $status');
    } catch (e) {
      print('❌ Firebase 업데이트 실패: $e');
    }
  }
  
  // 타이머 시작
  void _startTimer() {
    _elapsedSeconds = 0;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }
  
  // 타이머 정지
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
  
  // 경과 시간 포맷팅
  String _formatElapsedTime() {
    int minutes = _elapsedSeconds ~/ 60;
    int seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon() {
    switch (currentStatus) {
      case 'idle': return Icons.power_settings_new;
      case 'running': return Icons.autorenew;
      case 'completed': return Icons.check_circle;
      default: return Icons.help_outline;
    }
  }

  String _getStatusText() {
    switch (currentStatus) {
      case 'idle': return '대기 중';
      case 'running': return '작동 중';
      case 'completed': return '완료';
      default: return '연결 중...';
    }
  }

  Color _getStatusColor() {
    switch (currentStatus) {
      case 'idle': return Colors.grey;
      case 'running': return Colors.blue;
      case 'completed': return Colors.green;
      default: return Colors.orange;
    }
  }

  // 테스트용: 상태 변경
  void _simulateStatusChange() {
    String newStatus = 'idle';
    
    if (currentStatus == 'idle') {
      newStatus = 'running';
    } else if (currentStatus == 'running') {
      newStatus = 'completed';
    } else {
      newStatus = 'idle';
      _elapsedSeconds = 0;
    }
    
    _updateFirebaseStatus(newStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('음식물 처리기'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // 상태 카드
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      RotationTransition(
                        turns: _animationController,
                        child: Icon(
                          _getStatusIcon(),
                          size: 100,
                          color: _getStatusColor(),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      if (currentStatus == 'running') ...[
                        SizedBox(height: 15),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer, color: Colors.blue[700], size: 20),
                              SizedBox(width: 8),
                              Text(
                                _formatElapsedTime(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (currentStatus == 'completed' && _elapsedSeconds > 0) ...[
                        SizedBox(height: 15),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                              SizedBox(width: 8),
                              Text(
                                '소요 시간: ${_formatElapsedTime()}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      SizedBox(height: 15),
                      Text(
                        '마지막 업데이트',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      Text(
                        lastUpdateTime,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),

              // 알림 설정
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text('푸시 알림'),
                  subtitle: Text('분쇄 완료 시 알림을 받습니다'),
                  value: notificationEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      notificationEnabled = value;
                    });
                  },
                  secondary: Icon(Icons.notifications_active),
                ),
              ),

              SizedBox(height: 20),

              // 테스트 버튼
              ElevatedButton.icon(
                onPressed: _simulateStatusChange,
                icon: Icon(
                  currentStatus == 'idle' 
                    ? Icons.play_arrow 
                    : currentStatus == 'running'
                      ? Icons.stop
                      : Icons.refresh,
                ),
                label: Text(
                  currentStatus == 'idle'
                    ? '작동 시작'
                    : currentStatus == 'running'
                      ? '작동 완료'
                      : '초기화',
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _getStatusColor(),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              Spacer(),

              // Firebase 연결 상태
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isFirebaseConnected ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFirebaseConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: isFirebaseConnected ? Colors.green[700] : Colors.red[700],
                    ),
                    SizedBox(width: 10),
                    Text(
                      isFirebaseConnected ? 'Firebase 연결됨' : 'Firebase 연결 안 됨',
                      style: TextStyle(
                        color: isFirebaseConnected ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}