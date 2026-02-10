import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

bool _sameStringSet(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  return a.toSet().containsAll(b) && b.toSet().containsAll(a);
}

/// 현재 사용자 정보 (User 모델)
final currentUserDataProvider = StreamProvider<User?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);
  if (user == null || firestore == null) return Stream.value(null);

  return firestore.collection('users').doc(user.uid).snapshots().asyncMap((
    doc,
  ) async {
    if (!doc.exists) return null;

    final data = doc.data();
    final currentGroupIds = data != null && data['groupIds'] is List
        ? List<String>.from(data['groupIds'])
        : <String>[];

    try {
      final memberships = await firestore
          .collection('memberships')
          .where('userId', isEqualTo: user.uid)
          .get();
      final groupIds = memberships.docs
          .map((m) => m.data()['groupId'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (!_sameStringSet(groupIds, currentGroupIds)) {
        await doc.reference.set({
          'groupIds': groupIds,
        }, SetOptions(merge: true));
      }

      // 레거시 데이터 정규화:
      // memberships 문서 ID를 {userId}_{groupId} 형태로 보강
      final batch = firestore.batch();
      var hasBatchWrites = false;
      for (final membershipDoc in memberships.docs) {
        final membership = Membership.fromFirestore(membershipDoc);
        final normalizedId = '${membership.userId}_${membership.groupId}';

        if (membershipDoc.id != normalizedId) {
          batch.set(
            firestore.collection('memberships').doc(normalizedId),
            membership.toFirestore(),
            SetOptions(merge: true),
          );
          hasBatchWrites = true;
        }
      }

      if (hasBatchWrites) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Failed to sync groupIds: $e');
    }

    return User.fromFirestore(doc);
  });
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
      .map(
        (snapshot) => snapshot.docs.map((doc) {
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
        }).toList(),
      );
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

  String _membershipDocId(String userId, String groupId) {
    return '${userId}_$groupId';
  }

  Future<void> _ensureDeterministicMembership(
    String userId,
    String groupId,
  ) async {
    if (_firestore == null) return;

    final normalizedRef = _firestore!
        .collection('memberships')
        .doc(_membershipDocId(userId, groupId));
    final normalizedDoc = await normalizedRef.get();
    if (normalizedDoc.exists) return;

    final legacyQuery = await _firestore!
        .collection('memberships')
        .where('userId', isEqualTo: userId)
        .where('groupId', isEqualTo: groupId)
        .limit(1)
        .get();

    if (legacyQuery.docs.isEmpty) return;

    await normalizedRef.set(
      legacyQuery.docs.first.data(),
      SetOptions(merge: true),
    );
  }

  /// 이메일/비밀번호 로그인
  Future<firebase.UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    if (_auth == null) return null;
    return await _auth!.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// 이메일/비밀번호 회원가입
  Future<firebase.UserCredential?> signUpWithEmail(
    String email,
    String password,
  ) async {
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
      final firebase.GoogleAuthProvider googleProvider =
          firebase.GoogleAuthProvider();
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
            familyIds.map(
              (familyId) => notificationService.unsubscribeFromFamily(familyId),
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
  /// 반환값: (groupId: 생성된 그룹 ID, inviteCode: 초대 코드) 또는 null
  Future<({String groupId, String inviteCode})?> createFamily(
    String familyName,
    String memberName,
    String color,
  ) async {
    debugPrint('[AuthService] 🏠 Creating family: $familyName');
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) {
      debugPrint('[AuthService] ❌ User or Firestore is null');
      return null;
    }

    // 초대 코드 생성
    final inviteCode = _generateInviteCode();
    debugPrint('[AuthService] 🎫 Generated invite code: $inviteCode');

    // 1. 가족(그룹) 문서 생성
    final familyRef = await _firestore!.collection('families').add({
      'name': familyName,
      'inviteCode': inviteCode,
      'memberIds': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[AuthService] ✅ Created family document: ${familyRef.id}');

    // 2. 사용자 문서 생성 (없는 경우)
    final userDoc = await _firestore!.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      debugPrint('[AuthService] 👤 Creating user document');
      await _firestore!.collection('users').doc(user.uid).set({
        'name': memberName,
        'email': user.email,
        'defaultGroupId': familyRef.id, // 첫 그룹을 기본값으로
        'groupIds': [familyRef.id],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      debugPrint('[AuthService] 👤 Updating existing user document');
      // 기존 사용자인 경우 defaultGroupId/groupIds 동기화
      await _firestore!.collection('users').doc(user.uid).update({
        'defaultGroupId': familyRef.id,
        'groupIds': FieldValue.arrayUnion([familyRef.id]),
      });
    }

    // 3. 멤버십 문서 생성
    final membershipId = _membershipDocId(user.uid, familyRef.id);
    await _firestore!.collection('memberships').doc(membershipId).set({
      'userId': user.uid,
      'groupId': familyRef.id,
      'groupName': familyName,
      'name': memberName,
      'color': color,
      'role': 'admin',
      'avatarUrl': user.photoURL, // Google 프로필 사진
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('[AuthService] ✅ Created membership document');

    debugPrint('[AuthService] ✅ Family creation complete: ${familyRef.id}');
    return (groupId: familyRef.id, inviteCode: inviteCode);
  }

  /// 초대 코드로 그룹 참여 (다중 그룹 지원)
  Future<void> joinFamily(
    String inviteCode,
    String memberName,
    String color,
  ) async {
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
        'groupIds': [familyId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore!.collection('users').doc(user.uid).update({
        'groupIds': FieldValue.arrayUnion([familyId]),
      });
    }

    // 그룹 멤버 목록 동기화
    await _firestore!.collection('families').doc(familyId).update({
      'memberIds': FieldValue.arrayUnion([user.uid]),
    });

    // 멤버십 문서 생성 (결정적 ID)
    final membershipId = _membershipDocId(user.uid, familyId);
    await _firestore!.collection('memberships').doc(membershipId).set({
      'userId': user.uid,
      'groupId': familyId,
      'groupName': familyName,
      'name': memberName,
      'color': color,
      'role': 'member',
      'avatarUrl': user.photoURL, // Google 프로필 사진
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 6자리 초대 코드 생성
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (index) => chars[(random + index * 17) % chars.length],
    ).join();
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
  Future<void> updateMembershipProfile(
    String membershipId, {
    String? name,
    String? color,
  }) async {
    if (_firestore == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;

    if (updates.isNotEmpty) {
      await _firestore!
          .collection('memberships')
          .doc(membershipId)
          .update(updates);
    }
  }

  /// 가족 이름 업데이트 (배치 최적화)
  Future<void> updateFamilyName(String familyId, String newName) async {
    if (_firestore == null) return;
    final user = _auth?.currentUser;

    if (user != null) {
      await _ensureDeterministicMembership(user.uid, familyId);
    }

    // 1. 해당 그룹의 모든 memberships 조회
    final memberships = await _firestore!
        .collection('memberships')
        .where('groupId', isEqualTo: familyId)
        .get();

    // 2. WriteBatch로 families + memberships 한번에 업데이트
    final batch = _firestore!.batch();

    // families 컬렉션 업데이트
    batch.update(_firestore!.collection('families').doc(familyId), {
      'name': newName,
    });

    // memberships의 groupName 업데이트 (최대 499개, families 1개 포함 총 500개)
    for (final doc in memberships.docs.take(499)) {
      batch.update(doc.reference, {'groupName': newName});
    }

    await batch.commit();
  }

  /// 그룹 나가기
  /// 반환값: {nextGroupId: 다음 그룹 ID 또는 null, wasGroupDeleted: 그룹 삭제 여부}
  Future<Map<String, dynamic>> leaveGroup(String groupId) async {
    final user = _auth?.currentUser;
    if (user == null || _firestore == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // 1. 현재 사용자의 해당 그룹 membership 찾기
    final myMembershipQuery = await _firestore!
        .collection('memberships')
        .where('userId', isEqualTo: user.uid)
        .where('groupId', isEqualTo: groupId)
        .get();

    if (myMembershipQuery.docs.isEmpty) {
      throw Exception('해당 그룹의 멤버가 아닙니다.');
    }

    final myMembership = myMembershipQuery.docs.first;
    final myRole = myMembership.data()['role'] as String?;

    // 관리자 권한 검증이 규칙에서 안정적으로 동작하도록 결정적 ID 보강
    await _ensureDeterministicMembership(user.uid, groupId);

    // 2. 그룹의 모든 멤버 조회
    final allMembersQuery = await _firestore!
        .collection('memberships')
        .where('groupId', isEqualTo: groupId)
        .get();

    final memberCount = allMembersQuery.docs.length;
    bool wasGroupDeleted = false;

    // 3. WriteBatch 준비
    final batch = _firestore!.batch();

    if (memberCount <= 1) {
      // 마지막 멤버인 경우: 그룹 삭제
      debugPrint(
        '[AuthService] 🗑️ Last member leaving, deleting group: $groupId',
      );

      // 그룹 문서 삭제
      batch.delete(_firestore!.collection('families').doc(groupId));

      // 본인 멤버십 삭제 (중복 문서 모두 정리)
      for (final doc in myMembershipQuery.docs) {
        batch.delete(doc.reference);
      }

      wasGroupDeleted = true;
    } else {
      // 여러 멤버가 있는 경우

      // 4. 관리자인 경우 권한 이전
      if (myRole == 'admin') {
        // 가장 오래된 다른 멤버에게 admin 권한 이전
        final otherMembers = allMembersQuery.docs
            .where((doc) => doc.data()['userId'] != user.uid)
            .toList();

        // joinedAt 기준 정렬 (가장 오래된 멤버 선택)
        otherMembers.sort((a, b) {
          final aJoined =
              (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bJoined =
              (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return aJoined.compareTo(bJoined);
        });

        if (otherMembers.isNotEmpty) {
          final newAdmin = otherMembers.first;
          debugPrint(
            '[AuthService] 👑 Transferring admin to: ${newAdmin.data()['name']}',
          );
          batch.update(newAdmin.reference, {'role': 'admin'});
        }
      }

      // 5. families.memberIds에서 본인 제거
      batch.update(_firestore!.collection('families').doc(groupId), {
        'memberIds': FieldValue.arrayRemove([user.uid]),
      });

      // 6. 본인 멤버십 삭제 (중복 문서 모두 정리)
      for (final doc in myMembershipQuery.docs) {
        batch.delete(doc.reference);
      }
    }

    // 7. 배치 커밋
    await batch.commit();

    // 8. 남은 그룹 중 다음 그룹 ID 찾기
    final remainingMemberships = await _firestore!
        .collection('memberships')
        .where('userId', isEqualTo: user.uid)
        .get();

    String? nextGroupId;
    if (remainingMemberships.docs.isNotEmpty) {
      nextGroupId = remainingMemberships.docs.first.data()['groupId'] as String;
    }

    // 9. 사용자 groupIds/defaultGroupId 동기화
    final userRef = _firestore!.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final currentDefaultGroupId = userDoc.data()?['defaultGroupId'] as String?;

    final userUpdates = <String, dynamic>{
      'groupIds': FieldValue.arrayRemove([groupId]),
    };
    if (nextGroupId == null) {
      userUpdates['defaultGroupId'] = FieldValue.delete();
    } else if (currentDefaultGroupId == null ||
        currentDefaultGroupId == groupId) {
      userUpdates['defaultGroupId'] = nextGroupId;
    }
    await userRef.set(userUpdates, SetOptions(merge: true));

    // 10. FCM 토픽 구독 해제
    try {
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.unsubscribeFromFamily(groupId);
    } catch (e) {
      debugPrint('[AuthService] ⚠️ FCM unsubscribe failed: $e');
    }

    debugPrint(
      '[AuthService] ✅ Left group: $groupId, next group: $nextGroupId',
    );

    return {'nextGroupId': nextGroupId, 'wasGroupDeleted': wasGroupDeleted};
  }

  /// 비밀번호 재설정 이메일 발송
  Future<void> sendPasswordResetEmail(String email) async {
    if (_auth == null) throw Exception('인증 서비스를 사용할 수 없습니다.');
    await _auth!.sendPasswordResetEmail(email: email);
  }

  /// Google 재인증 (민감한 작업 전 필요)
  Future<bool> reauthenticateWithGoogle() async {
    final user = _auth?.currentUser;
    if (user == null) return false;

    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = firebase.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('[AuthService] ✅ Google reauthentication successful');
      return true;
    } catch (e) {
      debugPrint('[AuthService] ❌ Google reauthentication failed: $e');
      return false;
    }
  }

  /// 이메일/비밀번호 재인증
  Future<bool> reauthenticateWithPassword(String password) async {
    final user = _auth?.currentUser;
    if (user == null || user.email == null) return false;

    try {
      final credential = firebase.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('[AuthService] ✅ Password reauthentication successful');
      return true;
    } catch (e) {
      debugPrint('[AuthService] ❌ Password reauthentication failed: $e');
      return false;
    }
  }

  /// 계정 삭제 (GDPR 준수)
  /// Cloud Function을 호출하여 모든 사용자 데이터를 삭제합니다.
  Future<void> deleteAccount() async {
    final user = _auth?.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');

    debugPrint('[AuthService] 🗑️ Starting account deletion for: ${user.uid}');

    try {
      // Cloud Function 호출 (asia-northeast3 리전)
      final functions = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      );
      final callable = functions.httpsCallable('deleteUserAccount');

      final result = await callable.call<Map<String, dynamic>>();
      debugPrint('[AuthService] ✅ Account deletion result: ${result.data}');

      // 로컬 로그아웃 (Auth 삭제는 Cloud Function에서 처리)
      await _auth?.signOut();
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[AuthService] ❌ Cloud Function error: ${e.code} - ${e.message}',
      );
      throw Exception(e.message ?? '계정 삭제 중 오류가 발생했습니다.');
    } catch (e) {
      debugPrint('[AuthService] ❌ Account deletion failed: $e');
      throw Exception('계정 삭제 중 오류가 발생했습니다.');
    }
  }
}
