import 'package:cloud_firestore/cloud_firestore.dart';

/// 심리검사 결과 모델
class PsychologyTestResult {
  final String id;
  final String userId;
  final String? familyId; // 그룹과 공유 시 사용
  final String testType; // 'big5', 'mbti', 'attachment', 'love_language', 'stress', 'anxiety', 'depression'
  final List<int> answers; // 각 문항별 응답 (0-based index)
  final Map<String, dynamic> result; // 검사 유형별 결과 데이터
  final DateTime completedAt;
  final bool isShared; // 그룹 공유 여부

  PsychologyTestResult({
    required this.id,
    required this.userId,
    this.familyId,
    required this.testType,
    required this.answers,
    required this.result,
    required this.completedAt,
    this.isShared = false,
  });

  factory PsychologyTestResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PsychologyTestResult(
      id: doc.id,
      userId: data['userId'] ?? '',
      familyId: data['familyId'],
      testType: data['testType'] ?? '',
      answers: List<int>.from(data['answers'] ?? []),
      result: Map<String, dynamic>.from(data['result'] ?? {}),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isShared: data['isShared'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'familyId': familyId,
      'testType': testType,
      'answers': answers,
      'result': result,
      'completedAt': Timestamp.fromDate(completedAt),
      'isShared': isShared,
    };
  }

  PsychologyTestResult copyWith({
    String? id,
    String? userId,
    String? familyId,
    String? testType,
    List<int>? answers,
    Map<String, dynamic>? result,
    DateTime? completedAt,
    bool? isShared,
  }) {
    return PsychologyTestResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      testType: testType ?? this.testType,
      answers: answers ?? this.answers,
      result: result ?? this.result,
      completedAt: completedAt ?? this.completedAt,
      isShared: isShared ?? this.isShared,
    );
  }

  /// 검사 유형 한글명
  String get testTypeName => PsychologyTestType.getName(testType);

  /// 검사 유형 아이콘
  String get testTypeIcon => PsychologyTestType.getIcon(testType);
}

/// 심리검사 유형 상수
class PsychologyTestType {
  static const String big5 = 'big5';
  static const String mbti = 'mbti';
  static const String attachment = 'attachment';
  static const String loveLanguage = 'love_language';
  static const String stress = 'stress';
  static const String anxiety = 'anxiety';
  static const String depression = 'depression';

  static const Map<String, String> names = {
    big5: 'Big5 성격검사',
    mbti: 'MBTI 성격유형',
    attachment: '애착유형 검사',
    loveLanguage: '사랑의 언어',
    stress: '스트레스 지수',
    anxiety: '불안 선별검사',
    depression: '우울 선별검사',
  };

  static const Map<String, String> icons = {
    big5: '🎭',
    mbti: '🧩',
    attachment: '💕',
    loveLanguage: '💝',
    stress: '😰',
    anxiety: '😟',
    depression: '😔',
  };

  static String getName(String type) => names[type] ?? type;
  static String getIcon(String type) => icons[type] ?? '📝';

  static List<String> get allTypes => [
    big5, mbti, attachment, loveLanguage, stress, anxiety, depression
  ];
}
