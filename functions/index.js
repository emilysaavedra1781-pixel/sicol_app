const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.changePassword = onCall(async (request) => {

  console.log("FUNCION EJECUTADA");

  const uid = request.data.uid;
  const newPassword = request.data.newPassword;

  await admin.auth().updateUser(uid, {
    password: newPassword,
  });

  return {
    success: true,
  };
});