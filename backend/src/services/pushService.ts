import admin from "firebase-admin";

/**
 * Send a "catch up ping" push notification to a user.
 *
 * This is the notification a user sees when someone in their queue goes live
 * and the rotation engine picks them. The notification carries data the client
 * needs to join the call immediately.
 *
 * @param fcmToken - The recipient's FCM device token.
 * @param fromUserName - Display name of the user who went live.
 * @param fromUserId - UID of the user who went live.
 * @param catchupId - The catch-up relationship ID.
 * @param callId - The pre-created call document ID.
 */
export async function sendCatchUpPing(
  fcmToken: string,
  fromUserName: string,
  fromUserId: string,
  catchupId: string,
  callId: string,
): Promise<void> {
  const message: admin.messaging.Message = {
    token: fcmToken,
    notification: {
      title: "We Should Catch Up",
      body: `${fromUserName} is free to catch up \u{1F44B}`,
    },
    data: {
      type: "catch_up_ping",
      fromUserId,
      fromUserName,
      catchupId,
      callId,
    },
    // High priority to wake the device and show immediately.
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
  } catch (err: any) {
    // If the token is invalid/expired, log it so we can clean up.
    if (
      err?.code === "messaging/invalid-registration-token" ||
      err?.code === "messaging/registration-token-not-registered"
    ) {
      console.warn(
        `Stale FCM token detected for catchup=${catchupId}. Token should be removed.`,
      );
      // In a production system you'd mark this token as stale in Firestore
      // so the client refreshes it on next launch.
    }
    throw err;
  }
}

/**
 * Send a "call ready" push to User A when User B accepts the ping.
 *
 * This tells User A that someone accepted their catch-up request and
 * they should call /join-call to get Agora credentials and enter the call.
 */
export async function sendCallReady(
  fcmToken: string,
  fromUserName: string,
  fromUserId: string,
  catchupId: string,
  callId: string,
): Promise<void> {
  const message: admin.messaging.Message = {
    token: fcmToken,
    notification: {
      title: "We Should Catch Up",
      body: `${fromUserName} is joining your call!`,
    },
    data: {
      type: "call_ready",
      fromUserId,
      fromUserName,
      catchupId,
      callId,
    },
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          contentAvailable: true,
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
  } catch (err: any) {
    if (
      err?.code === "messaging/invalid-registration-token" ||
      err?.code === "messaging/registration-token-not-registered"
    ) {
      console.warn(
        `Stale FCM token detected for callReady callId=${callId}. Token should be removed.`,
      );
    }
    throw err;
  }
}

/**
 * Send a notification when someone accepts a catch-up invite.
 *
 * @param fcmToken - The recipient's (invite creator's) FCM device token.
 * @param userName - Display name of the user who accepted.
 * @param catchupId - The catch-up relationship ID.
 */
export async function sendInviteAccepted(
  fcmToken: string,
  userName: string,
  catchupId: string,
): Promise<void> {
  const message: admin.messaging.Message = {
    token: fcmToken,
    notification: {
      title: "Invite Accepted!",
      body: `${userName} accepted your catch-up invite.`,
    },
    data: {
      type: "invite_accepted",
      userName,
      catchupId,
    },
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
  } catch (err: any) {
    if (
      err?.code === "messaging/invalid-registration-token" ||
      err?.code === "messaging/registration-token-not-registered"
    ) {
      console.warn(
        `Stale FCM token detected for catchup=${catchupId}. Token should be removed.`,
      );
    }
    throw err;
  }
}
