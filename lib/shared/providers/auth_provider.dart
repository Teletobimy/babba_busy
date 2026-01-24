import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_member.dart';
import '../models/family.dart';
import '../models/user.dart';
import '../models/membership.dart';
import '../../services/firebase/notification_service.dart';

/// Firebase Auth 인스턴스
final firebaseAuthProvider = Provider<firebase.FirebaseAuth?>((ref) {
  try {
    return firebase.FirebaseAuth.instance;
  } catch (e) {
    return null;
  }
});

/// 현재 인증 상태 스트림
final authStateProvider = StreamProvider<firebase.User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream.value(null);
  return auth.authStateChanges();
});

/// 현재 사용자 (Firebase User)
final currentUserProvider = Provider<firebase.User?>((ref) {
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

/// 현재 사용자 정보 (User 모델)
final currentUserDataProvider = StreamProvider<User?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value(null);

  return firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? User.fromFirestore(doc) : null);
});

/// 현재 사용자의 가족 멤버 정보 (DEPRECATED - 하위 호환성용)
/// 대신 group_provider.dart의 currentMembershipProvider 사용
@Deprecated('Use currentMembershipProvider from group_provider.dart instead')
final currentMemberProvider = StreamProvider<FamilyMember?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value(null);

  // 임시: 첫 번째 membership을 FamilyMember로 변환
  return firestore
      .collection('memberships')
      .where('userId', isEqualTo: user.uid)
      .limit(1)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    final membership = Membership.fromFirestore(snapshot.docs.first);
    return FamilyMember(
      id: user.uid,
      familyId: membership.groupId,
      name: membership.name,
      email: user.email ?? '',
      color: membership.color,
      avatarUrl: membership.avatarUrl ?? user.photoURL, // 프로필 사진
      role: membership.role,
      createdAt: membership.joinedAt,
    );
  });
});

/// 현재 사용자의 가족 정보 (DEPRECATED)
/// 대신 group_provider.dart의 currentGroupProvider 사용
@Deprecated('Use currentGroupProvider from group_provider.dart instead')
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

/// 가족 구성원 목록 (DEPRECATED)
/// 대신 group_provider.dart의 groupMembershipsProvider 사용
@Deprecated('Use groupMembershipsProvider from group_provider.dart instead')
final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final member = ref.watch(currentMemberProvider).value;
  final firestore = ref.watch(firestoreProvider);
  if (member == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('memberships')
      .where('groupId', isEqualTo: member.familyId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final membership = Membership.fromFirestore(doc);
            return FamilyMember(
              id: membership.userId,
              familyId: membership.groupId,
              name: membership.name,
              email: '', // membership에는 email 없음
              color: membership.color,
              avatarUrl: membership.avatarUrl, // 프로필 사진
              role: membership.role,
              createdAt: membership.joinedAt,
            );
          }).toList());
});

/// 인증 서비스 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

/// 인증 서비스
class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  firebase.FirebaseAuth? get _auth => _ref.read(firebaseAuthProvider);
  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  /// 이메일/비밀번호 로그인
  Future<firebase.UserCredential?> signInWithEmail(String email, String password) async {
    if (_auth == null) return null;
    return await _auth!.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 이메일/비밀번호 회원가입
  Future<firebase.UserCredential?> signUpWithEmail(String email, String password) async {
    if (_auth == null) return null;
    return await _auth!.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Google 로그인
  Future<firebase.UserCredential?> signInWithGoogle() async {
    if (_auth == null) return null;

    try {
      final firebase.GoogleAuthProvider googleProvider = firebase.GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      if (kIsWeb) {
        // 웹: 팝업으로 로그인
        return await _auth!.signInWithPopup(googleProvider);
      } else {
        // 모바일: 리다이렉트 방식 (또는 google_sign_in 패키지 사용)
        return await _auth!.signInWithProvider(googleProvider);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    final user = _auth?.currentUser;

    // 로그아웃 전 FCM 토큰 제거
    if (user != null) {
      try {
        final notificationService = _ref.read(notificationServiceProvider);
        await notificationService.removeTokenFromFirestore(user.uid);

        // 모든 그룹 토픽 구독 해제
        final memberships = await _firestore
            ?.collection('memberships')
            .where('userId', isEqualTo: user.uid)
            .get();

        if (memberships != null) {
          final familyIds = memberships.docs
              .map((doc) => doc.data()['groupId'] as String)
              .toList();

          // 병렬 처리: 독립적인 구독 해제 작업을 동시에 실행
          await Future.wait(
            familyIds.map((familyId) =>
              notificationService.unsubscribeFromFamily(familyId)
            ),
            eagerError: false, // 일부 실패해도 나머지 계속 진행
          );
        }
      } catch (e) {
        debugPrint('FCM 토큰 정리 실패: $e');
        // 에러가 있어도 로그아웃은 진행
      }
    }

    await _auth?.signOut();
  }

  /// 그룹 생성 및 참여 (다중 그룹 지원)
  Future<String?> createFamily(String familyName, String memberName, String color) async {
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) return null;

    // 초대 코드 생성
    final inviteCode = _generateInviteCode();

    // 1. 가족(그룹) 문서 생성
    final familyRef = await _firestore!.collection('families').add({
      'name': familyName,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. 사용자 문서 생성 (없는 경우)
    final userDoc = await _firestore!.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _firestore!.collection('users').doc(user.uid).set({
        'name': memberName,
        'email': user.email,
        'defaultGroupId': familyRef.id, // 첫 그룹을 기본값으로
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 기존 사용자인 경우 defaultGroupId만 업데이트
      await _firestore!.collection('users').doc(user.uid).update({
        'defaultGroupId': familyRef.id,
      });
    }

    // 3. 멤버십 문서 생성
    await _firestore!.collection('memberships').add({
      'userId': user.uid,
      'groupId': familyRef.id,
      'groupName': familyName,
      'name': memberName,
      'color': color,
      'role': 'admin',
      'avatarUrl': user.photoURL, // Google 프로필 사진
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return inviteCode;
  }

  /// 초대 코드로 그룹 참여 (다중 그룹 지원)
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
    final familyName = familyQuery.docs.first.data()['name'] as String;

    // 이미 참여했는지 확인
    final existingMembership = await _firestore!
        .collection('memberships')
        .where('userId', isEqualTo: user.uid)
        .where('groupId', isEqualTo: familyId)
        .get();

    if (existingMembership.docs.isNotEmpty) {
      throw Exception('이미 참여한 그룹입니다.');
    }

    // 사용자 문서 생성 (없는 경우)
    final userDoc = await _firestore!.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _firestore!.collection('users').doc(user.uid).set({
        'name': memberName,
        'email': user.email,
        'defaultGroupId': familyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 멤버십 문서 생성
    await _firestore!.collection('memberships').add({
      'userId': user.uid,
      'groupId': familyId,
      'groupName': familyName,
      'name': memberName,
      'color': color,
      'role': 'member',
      'avatarUrl': user.photoURL, // Google 프로필 사진
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 6자리 초대 코드 생성
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (index) => chars[(random + index * 17) % chars.length]).join();
  }

  /// 프로필 업데이트 (전역)
  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _firestore!.collection('users').doc(user.uid).update(updates);
    }
  }

  /// 그룹별 프로필 업데이트 (멤버십)
  Future<void> updateMembershipProfile(String membershipId, {String? name, String? color}) async {
    if (_firestore == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;

    if (updates.isNotEmpty) {
      await _firestore!.collection('memberships').doc(membershipId).update(updates);
    }
  }

  /// 가족 이름 업데이트
  Future<void> updateFamilyName(String familyId, String newName) async {
    if (_firestore == null) return;
    
    // 1. families 컬렉션 업데이트
    await _firestore!.collection('families').doc(familyId).update({'name': newName});
    
    // 2. 해당 그룹의 모든 memberships의 groupName도 업데이트 (캐시 동기화)
    final memberships = await _firestore!
        .collection('memberships')
        .where('groupId', isEqualTo: familyId)
        .get();
    
    for (final doc in memberships.docs) {
      await doc.reference.update({'groupName': newName});
    }
  }
}

