import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const BATCH_LIMIT = 500;

/**
 * 서브컬렉션 삭제 헬퍼
 * Firestore는 부모 문서 삭제 시 서브컬렉션을 자동 삭제하지 않으므로 수동 처리 필요
 */
async function deleteSubcollection(
  docRef: admin.firestore.DocumentReference,
  subcollectionName: string
): Promise<number> {
  const subcollectionRef = docRef.collection(subcollectionName);
  const snapshot = await subcollectionRef.limit(BATCH_LIMIT).get();

  if (snapshot.empty) {
    return 0;
  }

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  // 재귀 호출 (BATCH_LIMIT 이상인 경우)
  if (snapshot.size >= BATCH_LIMIT) {
    const more = await deleteSubcollection(docRef, subcollectionName);
    return snapshot.size + more;
  }

  return snapshot.size;
}

/**
 * users/{userId}/albums/{albumId}/comments까지 포함하여 앨범 전체 삭제
 */
async function deleteAlbumsWithComments(
  userRef: admin.firestore.DocumentReference
): Promise<number> {
  let totalDeleted = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const albumsSnapshot = await userRef.collection("albums").limit(BATCH_LIMIT).get();
    if (albumsSnapshot.empty) {
      break;
    }

    const batch = admin.firestore().batch();
    for (const albumDoc of albumsSnapshot.docs) {
      const commentsDeleted = await deleteSubcollection(albumDoc.ref, "comments");
      totalDeleted += commentsDeleted;
      batch.delete(albumDoc.ref);
    }
    await batch.commit();

    totalDeleted += albumsSnapshot.size;
    if (albumsSnapshot.size < BATCH_LIMIT) {
      break;
    }
  }

  return totalDeleted;
}

/**
 * 쿼리 결과 문서 일괄 삭제 헬퍼
 */
async function deleteQueryResults(
  query: admin.firestore.Query
): Promise<number> {
  let totalDeleted = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await query.limit(BATCH_LIMIT).get();

    if (snapshot.empty) {
      break;
    }

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    totalDeleted += snapshot.size;

    if (snapshot.size < BATCH_LIMIT) {
      break;
    }
  }

  return totalDeleted;
}

/**
 * Storage 폴더 삭제 헬퍼
 */
async function deleteStorageFolder(prefix: string): Promise<number> {
  try {
    const bucket = admin.storage().bucket();
    const [files] = await bucket.getFiles({ prefix });

    if (files.length === 0) {
      return 0;
    }

    // 병렬 삭제 (최대 100개씩)
    const chunks = [];
    for (let i = 0; i < files.length; i += 100) {
      chunks.push(files.slice(i, i + 100));
    }

    for (const chunk of chunks) {
      await Promise.all(chunk.map((file) => file.delete().catch((err) => {
        console.log(`Failed to delete file: ${err}`);
      })));
    }

    console.log(`Deleted ${files.length} files from ${prefix}`);
    return files.length;
  } catch (error) {
    console.error(`Error deleting storage folder ${prefix}:`, error);
    return 0;
  }
}

/**
 * 계정 삭제 Cloud Function (Callable)
 * 사용자의 모든 데이터를 삭제합니다.
 *
 * 삭제 대상:
 * - Firestore:
 *   - users/{userId} (+ notificationHistory, todos, albums, business_reviews 하위 컬렉션)
 *   - memberships (userId == currentUser인 모든 문서)
 *   - ai_cache/{userId} (+ 하위 컬렉션)
 *   - analysis_jobs (userId == currentUser)
 * - Storage:
 *   - users/{userId}/*
 * - Auth:
 *   - Firebase Auth 사용자 삭제
 */
export const deleteUserAccount = functions
  .region("asia-northeast3")
  .runWith({
    timeoutSeconds: 540, // 9분 (최대 허용)
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    // 1. 인증 확인
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const userId = context.auth.uid;
    console.log(`[deleteUserAccount] Starting deletion for user: ${userId}`);

    const db = admin.firestore();
    const deletionStats = {
      firestore: {
        users: 0,
        memberships: 0,
        aiCache: 0,
        analysisJobs: 0,
        subcollections: 0,
      },
      storage: 0,
    };

    try {
      // 2. Firestore 삭제

      // 2.1 users/{userId} 서브컬렉션 삭제
      const userRef = db.collection("users").doc(userId);
      const albumsDeleted = await deleteAlbumsWithComments(userRef);
      deletionStats.firestore.subcollections += albumsDeleted;
      console.log(`[deleteUserAccount] Deleted ${albumsDeleted} docs from users/${userId}/albums(+comments)`);

      const subcollections = ["notificationHistory", "todos", "business_reviews"];

      for (const subcol of subcollections) {
        const deleted = await deleteSubcollection(userRef, subcol);
        deletionStats.firestore.subcollections += deleted;
        console.log(`[deleteUserAccount] Deleted ${deleted} docs from users/${userId}/${subcol}`);
      }

      // 2.2 users/{userId} 문서 삭제
      await userRef.delete();
      deletionStats.firestore.users = 1;
      console.log(`[deleteUserAccount] Deleted users/${userId}`);

      // 2.3 memberships 삭제 (userId 기준)
      const membershipsQuery = db.collection("memberships").where("userId", "==", userId);
      deletionStats.firestore.memberships = await deleteQueryResults(membershipsQuery);
      console.log(`[deleteUserAccount] Deleted ${deletionStats.firestore.memberships} memberships`);

      // 2.4 ai_cache/{userId} 삭제 (서브컬렉션 포함)
      const aiCacheRef = db.collection("ai_cache").doc(userId);
      const aiSubcollections = ["summaries", "insights"];
      for (const subcol of aiSubcollections) {
        const deleted = await deleteSubcollection(aiCacheRef, subcol);
        deletionStats.firestore.aiCache += deleted;
      }
      await aiCacheRef.delete().catch(() => undefined); // 문서가 없어도 OK
      console.log(`[deleteUserAccount] Deleted ai_cache/${userId}`);

      // 2.5 analysis_jobs 삭제 (userId 기준)
      const analysisJobsQuery = db.collection("analysis_jobs").where("userId", "==", userId);
      deletionStats.firestore.analysisJobs = await deleteQueryResults(analysisJobsQuery);
      console.log(`[deleteUserAccount] Deleted ${deletionStats.firestore.analysisJobs} analysis_jobs`);

      // 3. Storage 삭제
      deletionStats.storage = await deleteStorageFolder(`users/${userId}/`);

      // 4. Firebase Auth 사용자 삭제
      await admin.auth().deleteUser(userId);
      console.log(`[deleteUserAccount] Deleted Firebase Auth user: ${userId}`);

      console.log(`[deleteUserAccount] ✅ Deletion complete for user: ${userId}`, deletionStats);

      return {
        success: true,
        message: "계정이 성공적으로 삭제되었습니다.",
        stats: deletionStats,
      };
    } catch (error) {
      console.error(`[deleteUserAccount] ❌ Error deleting user ${userId}:`, error);
      throw new functions.https.HttpsError(
        "internal",
        "계정 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
      );
    }
  });
