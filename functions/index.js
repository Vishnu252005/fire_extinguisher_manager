/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// notifyExpiredExtinguishers using v2 API
exports.notifyExpiredExtinguishers = onSchedule(
  { schedule: "every 1 hours" },
  async (context) => {
    const now = admin.firestore.Timestamp.now();
    const fireRef = admin.firestore().collection("fire");
    const snapshot = await fireRef.where("expiry", "<=", now).get();

    if (snapshot.empty) {
      console.log("No expired extinguishers found.");
      return null;
    }

    const tokens = [];
    const expiredNames = [];

    for (const doc of snapshot.docs) {
      const data = doc.data();
      expiredNames.push(data.name || "Unnamed");
      // For demo, add your device's FCM token below:
      // tokens.push("YOUR_TEST_FCM_TOKEN");
    }

    // TODO: Replace with actual device tokens from your users
    tokens.push("YOUR_TEST_FCM_TOKEN");

    if (tokens.length > 0) {
      const message = {
        notification: {
          title: "Extinguisher Expired!",
          body: `Expired: ${expiredNames.join(", ")}`,
        },
        tokens: tokens,
      };
      await admin.messaging().sendMulticast(message);
      console.log("Notification sent to tokens:", tokens);
    }

    return null;
  }
);

// sendExpiryEmail using v2 API
exports.sendExpiryEmail = onSchedule(
  { schedule: "every 5 minutes" },
  async (context) => {
    const soon = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 5 * 60 * 1000),
    );
    const extinguishersRef = admin.firestore().collection("fire");
    const usersRef = admin.firestore().collection("users");

    // Find extinguishers that are expired or expiring in 5 minutes
    const snapshot = await extinguishersRef
      .where("expiry", "<=", soon)
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (!data.userId) continue;

      // Get user email
      const userSnap = await usersRef
        .where("userId", "==", data.userId)
        .limit(1)
        .get();
      if (userSnap.empty) continue;
      const user = userSnap.docs[0].data();

      // Compose email
      const mail = {
        to: [user.email],
        message: {
          subject: "Fire Extinguisher Expiry Alert",
          text:
            `Dear ${user.username || "User"},\n\nYour extinguisher "${
              data.name
            }" is expired or expiring soon (${data.expiry
              .toDate()
              .toLocaleString()}).\n\nPlease take action!`,
        },
      };

      // Write to the mail collection (triggers the extension)
      await admin.firestore().collection("mail").add(mail);
    }
    return null;
  }
);
