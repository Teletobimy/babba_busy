import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendNotification } from "../services/notificationService";
import { MessageTemplates } from "../utils/messageTemplates";

/**
 * 그룹 멤버 ID 목록 조회
 * Note: families 컬렉션에는 memberIds 필드가 없으므로 memberships 쿼리 사용
 */
async function getGroupMemberIds(groupId: string): Promise<string[]> {
  const db = admin.firestore();
  const membershipsSnapshot = await db
    .collection("memberships")
    .where("groupId", "==", groupId)
    .get();

  return membershipsSnapshot.docs.map((doc) => doc.data().userId as string);
}

/**
 * 여러 그룹의 멤버 ID 수집 (중복 제거)
 */
async function getMembersFromGroups(
  groupIds: string[],
  excludeUserId: string
): Promise<string[]> {
  const allMemberIds = new Set<string>();

  for (const groupId of groupIds) {
    const memberIds = await getGroupMemberIds(groupId);
    memberIds.forEach((id) => allMemberIds.add(id));
  }

  allMemberIds.delete(excludeUserId);
  return Array.from(allMemberIds);
}

/**
 * 앨범 생성 시 알림
 */
export const onAlbumCreated = functions.firestore
  .document("users/{userId}/albums/{albumId}")
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const albumData = snapshot.data();

    try {
      // 공유된 앨범인지 확인
      const sharedGroups: string[] = albumData.sharedGroups || [];
      if (albumData.visibility !== "shared" || sharedGroups.length === 0) {
        console.log(`Album ${snapshot.id} is not shared, skipping notification`);
        return;
      }

      // 생성자 정보 조회
      const userDoc = await admin.firestore()
        .collection("users").doc(userId).get();
      const userName = userDoc.data()?.name || "사용자";

      // 공유된 그룹 멤버 수집
      const targetUserIds = await getMembersFromGroups(sharedGroups, userId);
      if (targetUserIds.length === 0) {
        console.log(`No users to notify for album ${snapshot.id}`);
        return;
      }

      // 알림 전송
      const { title, body } = MessageTemplates.albumShared(
        albumData.title || "앨범",
        userName
      );

      await sendNotification(targetUserIds, {
        title,
        body,
        data: {
          type: "album",
          albumId: snapshot.id,
          ownerId: userId,
          route: "/home",
        },
        tag: `album_${snapshot.id}`,
      });

      console.log(`Album notification sent to ${targetUserIds.length} users`);
    } catch (error) {
      console.error("Error in onAlbumCreated:", error);
    }
  });

/**
 * 앨범에 사진 추가 시 알림
 */
export const onAlbumPhotosAdded = functions.firestore
  .document("users/{userId}/albums/{albumId}")
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const before = change.before.data();
    const after = change.after.data();

    try {
      // 공유된 앨범인지 확인
      const sharedGroups: string[] = after.sharedGroups || [];
      if (after.visibility !== "shared" || sharedGroups.length === 0) {
        return;
      }

      // 사진 추가 여부 확인
      const beforePhotos: string[] = before.photoUrls || [];
      const afterPhotos: string[] = after.photoUrls || [];
      const newPhotosCount = afterPhotos.length - beforePhotos.length;

      if (newPhotosCount <= 0) {
        return;
      }

      // 추가한 사용자 정보 조회
      const userDoc = await admin.firestore()
        .collection("users").doc(userId).get();
      const userName = userDoc.data()?.name || "사용자";

      // 공유된 그룹 멤버 수집
      const targetUserIds = await getMembersFromGroups(sharedGroups, userId);
      if (targetUserIds.length === 0) {
        console.log(`No users to notify for album ${change.after.id}`);
        return;
      }

      // 알림 전송
      const { title, body } = MessageTemplates.albumPhotosAdded(
        after.title || "앨범",
        userName,
        newPhotosCount
      );

      await sendNotification(targetUserIds, {
        title,
        body,
        data: {
          type: "album",
          albumId: change.after.id,
          ownerId: userId,
          route: "/home",
        },
        tag: `album_${change.after.id}`, // 같은 앨범 알림 덮어쓰기
      });

      console.log(`Album photos notification sent to ${targetUserIds.length} users`);
    } catch (error) {
      console.error("Error in onAlbumPhotosAdded:", error);
    }
  });
