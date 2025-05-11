/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

exports.notifyExpiredExtinguishers = functions.pubsub.schedule("every 1 hours").onRun(async (context) => {
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
});
