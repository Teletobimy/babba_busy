import 'package:cloud_firestore/cloud_firestore.dart';

/// 시장 조사 모델
class MarketResearch {
  final String? targetMarket;      // 목표 시장
  final String? marketSize;         // 시장 규모
  final List<String> competitors;   // 주요 경쟁사
  final List<String> trends;        // 시장 트렌드
  final String? customerSegment;    // 타겟 고객층
  final String? entryBarrier;       // 진입 장벽

  MarketResearch({
    this.targetMarket,
    this.marketSize,
    this.competitors = const [],
    this.trends = const [],
    this.customerSegment,
    this.entryBarrier,
  });

  factory MarketResearch.fromMap(Map<String, dynamic>? data) {
    if (data == null) return MarketResearch();
    return MarketResearch(
      targetMarket: data['targetMarket'],
      marketSize: data['marketSize'],
      competitors: List<String>.from(data['competitors'] ?? []),
      trends: List<String>.from(data['trends'] ?? []),
      customerSegment: data['customerSegment'],
      entryBarrier: data['entryBarrier'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetMarket': targetMarket,
      'marketSize': marketSize,
      'competitors': competitors,
      'trends': trends,
      'customerSegment': customerSegment,
      'entryBarrier': entryBarrier,
    };
  }

  bool get isEmpty =>
      targetMarket == null &&
      marketSize == null &&
      competitors.isEmpty &&
      trends.isEmpty &&
      customerSegment == null &&
      entryBarrier == null;
}

/// 사업 검토 결과 모델
class BusinessReview {
  final String id;
  final String userId;
  final String? groupId; // 그룹 공유 옵션
  final bool isShared;
  final String businessIdea;
  final String? industry;
  final String? budget;
  final int score; // 0-100
  final String summary;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> opportunities;
  final List<String> threats;
  final List<String> nextSteps;
  final MarketResearch? marketResearch; // 시장 조사
  final DateTime createdAt;

  BusinessReview({
    required this.id,
    required this.userId,
    this.groupId,
    this.isShared = false,
    required this.businessIdea,
    this.industry,
    this.budget,
    required this.score,
    required this.summary,
    required this.strengths,
    required this.weaknesses,
    required this.opportunities,
    required this.threats,
    required this.nextSteps,
    this.marketResearch,
    required this.createdAt,
  });

  factory BusinessReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessReview(
      id: doc.id,
      userId: data['userId'] ?? '',
      groupId: data['groupId'],
      isShared: data['isShared'] ?? false,
      businessIdea: data['businessIdea'] ?? '',
      industry: data['industry'],
      budget: data['budget'],
      score: data['score'] ?? 0,
      summary: data['summary'] ?? '',
      strengths: List<String>.from(data['strengths'] ?? []),
      weaknesses: List<String>.from(data['weaknesses'] ?? []),
      opportunities: List<String>.from(data['opportunities'] ?? []),
      threats: List<String>.from(data['threats'] ?? []),
      nextSteps: List<String>.from(data['nextSteps'] ?? []),
      marketResearch: data['marketResearch'] != null
          ? MarketResearch.fromMap(data['marketResearch'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'groupId': groupId,
      'isShared': isShared,
      'businessIdea': businessIdea,
      'industry': industry,
      'budget': budget,
      'score': score,
      'summary': summary,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'opportunities': opportunities,
      'threats': threats,
      'nextSteps': nextSteps,
      'marketResearch': marketResearch?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// BusinessAnalysisResult에서 변환
  factory BusinessReview.fromAnalysisResult({
    required String userId,
    required String businessIdea,
    String? industry,
    String? budget,
    required Map<String, dynamic> result,
  }) {
    return BusinessReview(
      id: '', // Firestore에서 자동 생성
      userId: userId,
      businessIdea: businessIdea,
      industry: industry,
      budget: budget,
      score: result['score'] ?? 0,
      summary: result['summary'] ?? '',
      strengths: List<String>.from(result['strengths'] ?? []),
      weaknesses: List<String>.from(result['weaknesses'] ?? []),
      opportunities: List<String>.from(result['opportunities'] ?? []),
      threats: List<String>.from(result['threats'] ?? []),
      nextSteps: List<String>.from(result['nextSteps'] ?? []),
      marketResearch: result['marketResearch'] != null
          ? MarketResearch.fromMap(result['marketResearch'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.now(),
    );
  }
}
