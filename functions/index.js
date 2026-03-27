const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

function shouldSuppressAlertPush(data) {
  const title = String(data.title || "").toLowerCase();
  const message = String(data.message || "").toLowerCase();
  const type = String(data.type || "").toLowerCase();
  const combined = `${title} ${message} ${type}`;

  return (
    combined.includes("medication") ||
    combined.includes("pill") ||
    combined.includes("overdue") ||
    combined.includes("missed dose")
  );
}

async function sendToUserToken(userId, payload) {
  if (!userId) return null;

  const userSnap = await admin.firestore().collection("users").doc(userId).get();
  if (!userSnap.exists) return null;

  const token = userSnap.data().fcmToken;
  if (!token) return null;

  return admin.messaging().send({
    token,
    notification: payload.notification,
    data: payload.data || {},
    android: {
      notification: {
        channelId: "general_channel",
      },
    },
  });
}

exports.sendAlertPush = functions.firestore
  .document("alerts/{alertId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const userId = data.userId;

    if (shouldSuppressAlertPush(data)) {
      functions.logger.info("Skipping medication-style alert push", {
        alertId: context.params.alertId,
        userId,
        type: data.type || null,
      });
      return null;
    }

    const notification = {
      title: data.title || "Medication Reminder",
      body: data.message || "Please check your medication schedule.",
    };

    const payload = {
      notification,
      data: {
        type: data.type || "alert",
        alertId: context.params.alertId,
        userId: userId || "",
        title: notification.title,
        message: notification.body,
      },
    };

    try {
      await sendToUserToken(userId, payload);
    } catch (e) {
      functions.logger.error("sendAlertPush failed", e);
    }
  });

exports.sendCaretakerNotificationPush = functions.firestore
  .document("users/{caretakerId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const caretakerId = context.params.caretakerId;

    const notification = {
      title: data.title || "Buddy Alert",
      body: data.message || "New alert from Buddy.",
    };

    const payload = {
      notification,
      data: {
        type: data.type || "buddy_alert",
        notificationId: context.params.notificationId,
        caretakerId,
        title: notification.title,
        message: notification.body,
      },
    };

    try {
      await sendToUserToken(caretakerId, payload);
    } catch (e) {
      functions.logger.error("sendCaretakerNotificationPush failed", e);
    }
  });
