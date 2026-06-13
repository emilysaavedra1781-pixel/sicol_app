const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.changePassword = onCall(
  {
    region: "us-central1",
    invoker: "public", // ← permite llamadas sin autenticación
  },
  async (request) => {
    console.log("=== changePassword EJECUTADA ===");
    console.log("Data recibida:", JSON.stringify(request.data));

    const uid = request.data.uid;
    const newPassword = request.data.newPassword;

    // ── Validaciones ────────────────────────────────────────────────────────

    if (!uid || typeof uid !== "string" || uid.trim() === "") {
      console.error("ERROR: uid faltante o inválido →", uid);
      throw new HttpsError("invalid-argument", "El UID del usuario es requerido.");
    }

    if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
      console.error("ERROR: newPassword inválido");
      throw new HttpsError("invalid-argument", "La contraseña debe tener al menos 6 caracteres.");
    }

    // ── Actualizar contraseña en Firebase Auth ───────────────────────────────

    try {
      await admin.auth().updateUser(uid.trim(), {
        password: newPassword,
      });

      console.log("✅ Contraseña actualizada para UID:", uid);
      return { success: true };

    } catch (error) {
      console.error("ERROR al actualizar contraseña:", error.code, error.message);

      if (error.code === "auth/user-not-found") {
        throw new HttpsError("not-found", "Usuario no encontrado en Firebase Auth.");
      }

      throw new HttpsError("internal", "Error al actualizar la contraseña: " + error.message);
    }
  }
);
