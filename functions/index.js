const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
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

// ────────────────────────────────────────────────────────────────────────────
// RF42 — Notificación push al conductor cuando el colectivo se llena
// ────────────────────────────────────────────────────────────────────────────
//
// Se dispara cada vez que se actualiza un documento en viajes/{viajeId}.
// Envía la notificación solo en el instante exacto en que asientosOcupados
// pasa de "no lleno" a "lleno" (evita notificar varias veces seguidas).

exports.notificarColectivoLleno = onDocumentUpdated(
  {
    document: "viajes/{viajeId}",
    region: "us-central1",
  },
  async (event) => {
    const antes = event.data.before.data();
    const ahora = event.data.after.data();

    if (!antes || !ahora) return;

    const capacidad = Number(ahora.capacidad || 0);
    const ocupadosAntes = Number(antes.asientosOcupados || 0);
    const ocupadosAhora = Number(ahora.asientosOcupados || 0);

    const estabaLleno = capacidad > 0 && ocupadosAntes >= capacidad;
    const estaLleno = capacidad > 0 && ocupadosAhora >= capacidad;

    // Solo notificar en la transición de "no lleno" → "lleno"
    if (estabaLleno || !estaLleno) return;

    // Si el viaje ya arrancó, no tiene sentido avisar "se llenó"
    if (ahora.estado === "en_camino" || ahora.estado === "finalizado") return;

    const conductorUid = ahora.conductorUid;
    if (!conductorUid) {
      console.log("notificarColectivoLleno: viaje sin conductorUid, se omite.");
      return;
    }

    try {
      const conductorDoc = await admin
        .firestore()
        .collection("usuarios")
        .doc(conductorUid)
        .get();

      if (!conductorDoc.exists) {
        console.log("notificarColectivoLleno: conductor no encontrado:", conductorUid);
        return;
      }

      const fcmToken = conductorDoc.data().fcmToken;
      if (!fcmToken) {
        console.log("notificarColectivoLleno: conductor sin fcmToken:", conductorUid);
        return;
      }

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "¡Colectivo lleno!",
          body: "Todos los asientos están ocupados. Valida los códigos antes de arrancar.",
        },
        data: {
          tipo: "colectivo_lleno",
          viajeId: event.params.viajeId,
        },
      });

      console.log("✅ Notificación 'colectivo lleno' enviada a:", conductorUid);
    } catch (error) {
      console.error("ERROR en notificarColectivoLleno:", error.message);
    }
  }
);