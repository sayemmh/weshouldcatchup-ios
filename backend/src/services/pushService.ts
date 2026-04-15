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
    android: {
      priority: "high",
      collapseKey: `ping-${fromUserId}`,
    },
    apns: {
      headers: {
        "apns-collapse-id": `ping-${fromUserId}`,
        "apns-expiration": `${Math.floor(Date.now() / 1000) + 20}`,
      },
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
        `Stale FCM token detected for catchup=${catchupId}. Token should be removed.`,
      );
    }
    throw err;
  }
}

/**
 * Send a silent "rotation_update" push to the live user (User A) so their
 * client can show who is currently being pinged.  This is a data-only message
 * — no notification banner.
 */
export async function sendRotationUpdate(
  fcmToken: string,
  pingingUserName: string,
  pingingUserId: string,
): Promise<void> {
  const message: admin.messaging.Message = {
    token: fcmToken,
    data: {
      type: "rotation_update",
      pingingUserName,
      pingingUserId,
    },
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
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
      console.warn(`Stale FCM token for rotation_update. Token should be removed.`);
    }
    throw err;
  }
}

/**
 * Replace a stale ping notification with a "missed" message.
 * Uses the same collapse-id so it overwrites the original "is free" notification
 * rather than stacking a new one. This is more reliable than silent pushes
 * which iOS throttles.
 */
export async function sendPingExpired(
  fcmToken: string,
  fromUserId: string,
  fromUserName: string,
): Promise<void> {
  const message: admin.messaging.Message = {
    token: fcmToken,
    notification: {
      title: "We Should Catch Up",
      body: `You missed ${fromUserName} — they moved on. Next time!`,
    },
    data: {
      type: "ping_expired",
      fromUserId,
    },
    android: {
      priority: "high",
      collapseKey: `ping-${fromUserId}`,
    },
    apns: {
      headers: {
        "apns-collapse-id": `ping-${fromUserId}`,
      },
      payload: {
        aps: {
          sound: "",
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
      console.warn(`Stale FCM token for ping_expired.`);
    }
  }
}

/**
 * Send a silent push to trigger the recipient's app to refresh their queue.
 * Used when someone removes a catchup so the other person's queue updates.
 */
export async function sendQueueUpdated(
  fcmToken: string,
): Promise<void> {
  const message: admin.messaging.Message = {
    token: fcmToken,
    data: {
      type: "queue_updated",
    },
    android: { priority: "high" },
    apns: {
      payload: {
        aps: { contentAvailable: true },
      },
    },
  };

  try {
    await admin.messaging().send(message);
  } catch {
    // Best effort.
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
