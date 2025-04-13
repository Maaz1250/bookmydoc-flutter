const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const twilio = require("twilio");

// Twilio credentials (Get from Twilio Dashboard)
const accountSid = "ACf3f40f3cc8574097a430f60e084d56cf";
const authToken = "ccb4aaeb26b54522263ed5b44e8edbdf";
const twilioNumber = "+1 814 498 4239";

admin.initializeApp();
const client = twilio(accountSid, authToken);

exports.sendSMS = onDocumentCreated("sms_requests/{smsId}", async (event) => {
  const snap = event.data;
  if (!snap) {
    console.error("No data found in event.");
    return;
  }
  const data = snap.data();
  const phone = data.phone;
  const message = data.message;
  try {
    await client.messages.create({
      body: message,
      from: twilioNumber,
      to: phone,
    });
    await snap.ref.update({status: "sent"});
    console.log("SMS sent successfully!");
  } catch (error) {
    console.error("Error sending SMS:", error);
    await snap.ref.update({status: "failed"});
  }
});

