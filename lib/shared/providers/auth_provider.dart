import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_member.dart';
import '../models/family.dart';

/// Firebase Auth 인스턴스
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  try {
    return FirebaseAuth.instance;
  } catch (e) {
    return null;
  }
});

/// 현재 인증 상태 스트림
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream.value(null);
  return auth.authStateChanges();
});

/// 현재 사용자
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Firestore 인스턴스
final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  try {
    return FirebaseFirestore.instance;
  } catch (e) {
    return null;
  }
});

/// 현재 사용자의 가족 멤버 정보
final currentMemberProvider = StreamProvider<FamilyMember?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value(null);

  return firestore
      .collection('members')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? FamilyMember.fromFirestore(doc) : null);
});

/// 현재 사용자의 가족 정보
final currentFamilyProvider = StreamProvider<FamilyGroup?>((ref) {
  final member = ref.watch(currentMemberProvider).value;
  final firestore = ref.watch(firestoreProvider);
  if (member == null || firestore == null) return Stream.value(null);

  return firestore
      .collection('families')
      .doc(member.familyId)
      .snapshots()
      .map((doc) => doc.exists ? FamilyGroup.fromFirestore(doc) : null);
});

/// 가족 구성원 목록
final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final member = ref.watch(currentMemberProvider).value;
  final firestore = ref.watch(firestoreProvider);
  if (member == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('members')
      .where('familyId', isEqualTo: member.familyId)
      .snapshots()
      .map((snapshot) => 
          snapshot.docs.map((doc) => FamilyMember.fromFirestore(doc)).toList());
});

/// 인증 서비스 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

/// 인증 서비스
class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  FirebaseAuth? get _auth => _ref.read(firebaseAuthProvider);
  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  /// 이메일/비밀번호 로그인
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (_auth == null) return null;
    return await _auth!.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 이메일/비밀번호 회원가입
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    if (_auth == null) return null;
    return await _auth!.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _auth?.signOut();
  }

  /// 가족 생성
  Future<String?> createFamily(String familyName, String memberName, String color) async {
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) return null;

    // 초대 코드 생성
    final inviteCode = _generateInviteCode();

    // 가족 문서 생성
    final familyRef = await _firestore!.collection('families').add({
      'name': familyName,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 멤버 문서 생성
    await _firestore!.collection('members').doc(user.uid).set({
      'familyId': familyRef.id,
      'name': memberName,
      'email': user.email,
      'color': color,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return inviteCode;
  }

  /// 초대 코드로 가족 참여
  Future<void> joinFamily(String inviteCode, String memberName, String color) async {
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) throw Exception('로그인이 필요합니다.');

    // 초대 코드로 가족 찾기
    final familyQuery = await _firestore!
        .collection('families')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (familyQuery.docs.isEmpty) {
      throw Exception('유효하지 않은 초대 코드입니다.');
    }

    final familyId = familyQuery.docs.first.id;

    // 멤버 문서 생성
    await _firestore!.collection('members').doc(user.uid).set({
      'familyId': familyId,
      'name': memberName,
      'email': user.email,
      'color': color,
      'role': 'member',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 6자리 초대 코드 생성
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (index) => chars[(random + index * 17) % chars.length]).join();
  }

  /// 프로필 업데이트
  Future<void> updateProfile({String? name, String? color}) async {
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;

    if (updates.isNotEmpty) {
      await _firestore!.collection('members').doc(user.uid).update(updates);
    }
  }
}
