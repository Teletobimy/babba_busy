import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memo.dart';
import '../models/memo_category.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 현재 그룹의 메모 목록 (실시간)
final memosProvider = StreamProvider<List<Memo>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('memos')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Memo.fromFirestore(doc)).toList());
});

/// 현재 그룹의 메모 카테고리 목록
final memoCategoriesProvider = StreamProvider<List<MemoCategory>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('memo_categories')
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => MemoCategory.fromFirestore(doc)).toList());
});

/// 선택된 카테고리 ID
final selectedMemoCategoryIdProvider = StateProvider<String?>((ref) => null);

/// 카테고리별 메모 필터링
final filteredMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(memosProvider).value ?? [];
  final categoryId = ref.watch(selectedMemoCategoryIdProvider);

  if (categoryId == null) return memos;
  return memos.where((m) => m.categoryId == categoryId).toList();
});

/// 고정된 메모 목록
final pinnedMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(filteredMemosProvider);
  return memos.where((m) => m.isPinned).toList();
});

/// 고정되지 않은 메모 목록
final unpinnedMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(filteredMemosProvider);
  return memos.where((m) => !m.isPinned).toList();
});

/// 검색 쿼리
final memoSearchQueryProvider = StateProvider<String>((ref) => '');

/// 검색된 메모 목록
final searchedMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(filteredMemosProvider);
  final query = ref.watch(memoSearchQueryProvider).toLowerCase();

  if (query.isEmpty) return memos;

  return memos.where((m) {
    return m.title.toLowerCase().contains(query) ||
           m.content.toLowerCase().contains(query) ||
           m.tags.any((t) => t.toLowerCase().contains(query));
  }).toList();
});

/// 메모 서비스 Provider
final memoServiceProvider = Provider<MemoService>((ref) {
  return MemoService(ref);
});

/// 메모 서비스
class MemoService {
  final Ref _ref;

  MemoService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _groupId => _ref.read(currentMembershipProvider)?.groupId;
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _memosCollection {
    if (_groupId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_groupId).collection('memos');
  }

  CollectionReference? get _categoriesCollection {
    if (_groupId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_groupId).collection('memo_categories');
  }

  /// 메모 추가
  Future<String?> addMemo({
    required String title,
    String content = '',
    String? categoryId,
    String? categoryName,
    List<String> tags = const [],
    bool isPinned = false,
  }) async {
    final memosRef = _memosCollection;
    if (memosRef == null || _userId == null) return null;

    final doc = await memosRef.add({
      'familyId': _groupId,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'tags': tags,
      'isPinned': isPinned,
      'aiAnalysis': null,
      'analyzedAt': null,
      'createdBy': _userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// 메모 수정
  Future<void> updateMemo(String memoId, {
    String? title,
    String? content,
    String? categoryId,
    String? categoryName,
    List<String>? tags,
    bool? isPinned,
    String? aiAnalysis,
    DateTime? analyzedAt,
  }) async {
    final memosRef = _memosCollection;
    if (memosRef == null) return;

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (categoryId != null) updates['categoryId'] = categoryId;
    if (categoryName != null) updates['categoryName'] = categoryName;
    if (tags != null) updates['tags'] = tags;
    if (isPinned != null) updates['isPinned'] = isPinned;
    if (aiAnalysis != null) updates['aiAnalysis'] = aiAnalysis;
    if (analyzedAt != null) updates['analyzedAt'] = Timestamp.fromDate(analyzedAt);

    await memosRef.doc(memoId).update(updates);
  }

  /// 메모 고정 토글
  Future<void> togglePin(String memoId, bool isPinned) async {
    await updateMemo(memoId, isPinned: isPinned);
  }

  /// 메모 삭제
  Future<void> deleteMemo(String memoId) async {
    final memosRef = _memosCollection;
    if (memosRef == null) return;
    await memosRef.doc(memoId).delete();
  }

  /// AI 분석 결과 저장
  Future<void> saveAiAnalysis(String memoId, String analysis) async {
    await updateMemo(
      memoId,
      aiAnalysis: analysis,
      analyzedAt: DateTime.now(),
    );
  }

  // ========== 카테고리 관리 ==========

  /// 카테고리 추가
  Future<String?> addCategory({
    required String name,
    String? icon,
    required String color,
    int? sortOrder,
  }) async {
    final categoriesRef = _categoriesCollection;
    if (categoriesRef == null) return null;

    // sortOrder가 지정되지 않으면 마지막 순서로
    final finalOrder = sortOrder ?? await _getNextCategorySortOrder();

    final doc = await categoriesRef.add({
      'familyId': _groupId,
      'name': name,
      'icon': icon,
      'color': color,
      'sortOrder': finalOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// 카테고리 수정
  Future<void> updateCategory(String categoryId, {
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
  }) async {
    final categoriesRef = _categoriesCollection;
    if (categoriesRef == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (icon != null) updates['icon'] = icon;
    if (color != null) updates['color'] = color;
    if (sortOrder != null) updates['sortOrder'] = sortOrder;

    if (updates.isNotEmpty) {
      await categoriesRef.doc(categoryId).update(updates);
    }
  }

  /// 카테고리 삭제
  Future<void> deleteCategory(String categoryId) async {
    final categoriesRef = _categoriesCollection;
    if (categoriesRef == null) return;

    // 해당 카테고리를 사용하는 메모들의 categoryId를 null로 업데이트
    final memosRef = _memosCollection;
    if (memosRef != null) {
      final memos = await memosRef.where('categoryId', isEqualTo: categoryId).get();
      for (final doc in memos.docs) {
        await doc.reference.update({
          'categoryId': null,
          'categoryName': null,
        });
      }
    }

    await categoriesRef.doc(categoryId).delete();
  }

  /// 기본 카테고리 생성 (그룹 생성 시 호출)
  Future<void> createDefaultCategories() async {
    final categoriesRef = _categoriesCollection;
    if (categoriesRef == null || _groupId == null) return;

    final defaults = DefaultMemoCategories.createDefaults(_groupId!);

    for (final category in defaults) {
      await categoriesRef.doc(category.id).set(category.toFirestore());
    }
  }

  /// 다음 카테고리 정렬 순서 가져오기
  Future<int> _getNextCategorySortOrder() async {
    final categoriesRef = _categoriesCollection;
    if (categoriesRef == null) return 0;

    final snapshot = await categoriesRef.orderBy('sortOrder', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return 0;

    final lastOrder = snapshot.docs.first.data() as Map<String, dynamic>;
    return (lastOrder['sortOrder'] as int? ?? 0) + 1;
  }
}
