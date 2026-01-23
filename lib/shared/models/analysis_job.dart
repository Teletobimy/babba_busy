import 'package:cloud_firestore/cloud_firestore.dart';

/// 분석 작업 상태
enum AnalysisJobStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled;

  String get displayName {
    switch (this) {
      case pending:
        return '대기 중';
      case processing:
        return '분석 중';
      case completed:
        return '완료';
      case failed:
        return '실패';
      case cancelled:
        return '취소됨';
    }
  }

  static AnalysisJobStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return AnalysisJobStatus.pending;
      case 'processing':
        return AnalysisJobStatus.processing;
      case 'completed':
        return AnalysisJobStatus.completed;
      case 'failed':
        return AnalysisJobStatus.failed;
      case 'cancelled':
        return AnalysisJobStatus.cancelled;
      default:
        return AnalysisJobStatus.pending;
    }
  }
}

/// 분석 작업 유형
enum AnalysisJobType {
  businessReview,
  psychologyTest;

  String get value {
    switch (this) {
      case businessReview:
        return 'business_review';
      case psychologyTest:
        return 'psychology_test';
    }
  }

  String get displayName {
    switch (this) {
      case businessReview:
        return '사업 검토';
      case psychologyTest:
        return '심리 검사';
    }
  }

  static AnalysisJobType fromString(String value) {
    switch (value) {
      case 'business_review':
        return AnalysisJobType.businessReview;
      case 'psychology_test':
        return AnalysisJobType.psychologyTest;
      default:
        return AnalysisJobType.businessReview;
    }
  }
}

/// 분석 작업 진행 상황
class AnalysisJobProgress {
  final int currentStep;
  final int totalSteps;
  final double percentage;
  final String? currentStepName;

  AnalysisJobProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.percentage,
    this.currentStepName,
  });

  factory AnalysisJobProgress.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return AnalysisJobProgress(
        currentStep: 0,
        totalSteps: 5,
        percentage: 0.0,
      );
    }
    return AnalysisJobProgress(
      currentStep: map['currentStep'] ?? 0,
      totalSteps: map['totalSteps'] ?? 5,
      percentage: (map['percentage'] ?? 0.0).toDouble(),
      currentStepName: map['currentStepName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStep': currentStep,
      'totalSteps': totalSteps,
      'percentage': percentage,
      if (currentStepName != null) 'currentStepName': currentStepName,
    };
  }
}

/// 분석 작업 에러 정보
class AnalysisJobError {
  final String code;
  final String message;
  final bool retryable;

  AnalysisJobError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory AnalysisJobError.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return AnalysisJobError(
        code: 'unknown',
        message: '알 수 없는 오류',
        retryable: true,
      );
    }
    return AnalysisJobError(
      code: map['code'] ?? 'unknown',
      message: map['message'] ?? '오류가 발생했습니다',
      retryable: map['retryable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'message': message,
      'retryable': retryable,
    };
  }
}

/// 사업 검토 입력 데이터
class BusinessAnalysisInput {
  final String businessIdea;
  final String? industry;
  final String? targetMarket;
  final String? budget;

  BusinessAnalysisInput({
    required this.businessIdea,
    this.industry,
    this.targetMarket,
    this.budget,
  });

  factory BusinessAnalysisInput.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return BusinessAnalysisInput(businessIdea: '');
    }
    return BusinessAnalysisInput(
      businessIdea: map['businessIdea'] ?? map['idea'] ?? '',
      industry: map['industry'],
      targetMarket: map['targetMarket'] ?? map['target_market'],
      budget: map['budget'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessIdea': businessIdea,
      if (industry != null) 'industry': industry,
      if (targetMarket != null) 'targetMarket': targetMarket,
      if (budget != null) 'budget': budget,
    };
  }
}

/// 분석 작업 모델
class AnalysisJob {
  final String id;
  final String userId;
  final AnalysisJobType jobType;
  final AnalysisJobStatus status;
  final int priority;
  final Map<String, dynamic> input;
  final AnalysisJobProgress progress;
  final String? resultId;
  final AnalysisJobError? error;
  final int retryCount;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final bool notificationSent;

  AnalysisJob({
    required this.id,
    required this.userId,
    required this.jobType,
    required this.status,
    this.priority = 5,
    required this.input,
    required this.progress,
    this.resultId,
    this.error,
    this.retryCount = 0,
    this.maxRetries = 3,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
    this.notificationSent = false,
  });

  factory AnalysisJob.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnalysisJob(
      id: doc.id,
      userId: data['userId'] ?? '',
      jobType: AnalysisJobType.fromString(data['jobType'] ?? 'business_review'),
      status: AnalysisJobStatus.fromString(data['status'] ?? 'pending'),
      priority: data['priority'] ?? 5,
      input: data['input'] ?? {},
      progress: AnalysisJobProgress.fromMap(data['progress']),
      resultId: data['resultId'],
      error: data['error'] != null
          ? AnalysisJobError.fromMap(data['error'])
          : null,
      retryCount: data['retryCount'] ?? 0,
      maxRetries: data['maxRetries'] ?? 3,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationSent: data['notificationSent'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'jobType': jobType.value,
      'status': status.name,
      'priority': priority,
      'input': input,
      'progress': progress.toMap(),
      if (resultId != null) 'resultId': resultId,
      if (error != null) 'error': error!.toMap(),
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'createdAt': Timestamp.fromDate(createdAt),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'notificationSent': notificationSent,
    };
  }

  AnalysisJob copyWith({
    String? id,
    String? userId,
    AnalysisJobType? jobType,
    AnalysisJobStatus? status,
    int? priority,
    Map<String, dynamic>? input,
    AnalysisJobProgress? progress,
    String? resultId,
    AnalysisJobError? error,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    bool? notificationSent,
  }) {
    return AnalysisJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      jobType: jobType ?? this.jobType,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      input: input ?? this.input,
      progress: progress ?? this.progress,
      resultId: resultId ?? this.resultId,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationSent: notificationSent ?? this.notificationSent,
    );
  }

  /// 사업 검토 입력 데이터 추출
  BusinessAnalysisInput get businessInput => BusinessAnalysisInput.fromMap(input);

  /// 진행률 퍼센트
  double get progressPercent => progress.percentage;

  /// 대기/처리 중 여부
  bool get isInProgress =>
      status == AnalysisJobStatus.pending ||
      status == AnalysisJobStatus.processing;

  /// 완료 여부
  bool get isCompleted => status == AnalysisJobStatus.completed;

  /// 실패 여부
  bool get isFailed => status == AnalysisJobStatus.failed;

  /// 재시도 가능 여부
  bool get canRetry =>
      isFailed && (error?.retryable ?? true) && retryCount < maxRetries;

  /// 예상 대기 시간 (초)
  int get estimatedTimeSeconds {
    switch (jobType) {
      case AnalysisJobType.businessReview:
        return 120; // 약 2분
      case AnalysisJobType.psychologyTest:
        return 180; // 약 3분
    }
  }
}
