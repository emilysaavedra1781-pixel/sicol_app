const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { MercadoPagoConfig, Preference, Payment } = require('mercadopago');
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configuración de Email (Recomendado: SendGrid o Gmail con App Password)
// Debes configurar estas variables en Firebase con:
// firebase functions:secrets:set SMTP_USER
// firebase functions:secrets:set SMTP_PASS
const mailTransport = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

// URLs de retorno (páginas puente en Firebase Hosting que redirigen al deep link sicolapp://)
const BACK_URLS = {
  success: "https://jupiter-da0d7.web.app/payment-success.html",
  failure: "https://jupiter-da0d7.web.app/payment-error.html",
  pending: "https://jupiter-da0d7.web.app/payment-pending.html"
};

// ── Recuperación de Contraseña con OTP Real (Email) ───────────────────────────

exports.solicitarOtpRecuperacion = onCall(
  {
    region: "us-central1",
    secrets: ["SMTP_USER", "SMTP_PASS"],
  },
  async (request) => {
    const { email } = request.data;
    if (!email) throw new HttpsError("invalid-argument", "El email es requerido.");

    try {
      const db = admin.firestore();

      // 1. Buscar el celular asociado al email en Firestore
      const userQuery = await db.collection("usuarios")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (userQuery.empty) {
        throw new HttpsError("not-found", "No existe una cuenta con este correo.");
      }

      const userData = userQuery.docs[0].data();
      const celular = userData.celular;
      if (!celular) throw new HttpsError("internal", "Error de consistencia: usuario sin celular.");

      const emailAuth = `${celular}@sicol.pe`;
      const user = await admin.auth().getUserByEmail(emailAuth);
      const uid = user.uid;

      // Rate limit: 1 solicitud cada 60 segundos
      const otpRef = db.collection("otp_recuperacion").doc(uid);
      const doc = await otpRef.get();

      if (doc.exists) {
        const lastSent = doc.data().creadoEn.toDate();
        const diff = (new Date() - lastSent) / 1000;
        if (diff < 60) {
          throw new HttpsError("resource-exhausted", `Espera ${Math.ceil(60 - diff)}s para reenviar.`);
        }
      }

      // Generar código de 6 dígitos
      const otp = Math.floor(100000 + Math.random() * 900000).toString();

      await otpRef.set({
        otp,
        intentos: 0,
        creadoEn: admin.firestore.FieldValue.serverTimestamp(),
        email: email
      });

      // Enviar Email
      const mailOptions = {
        from: '"SICOL Soporte" <no-reply@sicol.pe>',
        to: email,
        subject: `${otp} es tu código de recuperación de SICOL`,
        text: `Tu código de verificación es: ${otp}. Válido por 60 segundos.`,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              .container { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 16px; overflow: hidden; }
              .header { background-color: #6B21F5; padding: 32px; text-align: center; }
              .content { padding: 40px; background-color: #ffffff; text-align: center; }
              .otp-box { background-color: #f3f4f6; padding: 24px; font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #6B21F5; border-radius: 12px; margin: 24px 0; border: 2px dashed #6B21F5; }
              .footer { padding: 24px; background-color: #f9fafb; color: #6b7280; font-size: 12px; text-align: center; }
              .logo-text { color: #ffffff; font-size: 28px; font-weight: bold; letter-spacing: 2px; margin: 0; }
              .h1 { color: #111827; font-size: 20px; font-weight: 700; margin-bottom: 16px; }
              .p { color: #4b5563; font-size: 15px; line-height: 1.6; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <p class="logo-text">SICOL</p>
              </div>
              <div class="content">
                <h1 class="h1">Restablecer contraseña</h1>
                <p class="p">Hola,</p>
                <p class="p">Has solicitado un código para cambiar tu contraseña en la aplicación SICOL. Utiliza el siguiente código de verificación:</p>
                <div class="otp-box">${otp}</div>
                <p class="p">Este código es válido por solo <b>60 segundos</b> por razones de seguridad.</p>
                <p class="p" style="margin-top: 32px; font-size: 13px;">Si no solicitaste este cambio, puedes ignorar este correo de forma segura.</p>
              </div>
              <div class="footer">
                &copy; 2026 SICOL - Sistema de Colectivos. Todos los derechos reservados.<br>
                Este es un mensaje automático, por favor no respondas a este correo.
              </div>
            </div>
          </body>
          </html>
        `
      };

      await mailTransport.sendMail(mailOptions);
      return { success: true };

    } catch (error) {
      console.error("Error en solicitarOtpRecuperacion:", error);
      if (error.code === "auth/user-not-found") {
        throw new HttpsError("not-found", "No existe una cuenta con este correo.");
      }
      throw new HttpsError("internal", error.message);
    }
  }
);

exports.verificarOtpRecuperacion = onCall(
  { region: "us-central1" },
  async (request) => {
    const { email, otp } = request.data;
    if (!email || !otp) throw new HttpsError("invalid-argument", "Datos incompletos.");

    try {
      const db = admin.firestore();

      // 1. Buscar el celular asociado al email en Firestore
      const userQuery = await db.collection("usuarios")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (userQuery.empty) {
        throw new HttpsError("not-found", "No existe una cuenta con este correo.");
      }

      const userData = userQuery.docs[0].data();
      const emailAuth = `${userData.celular}@sicol.pe`;

      const user = await admin.auth().getUserByEmail(emailAuth);
      const uid = user.uid;
      const otpRef = db.collection("otp_recuperacion").doc(uid);
      const doc = await otpRef.get();

      if (!doc.exists) throw new HttpsError("not-found", "Código no solicitado o ya usado.");

      const data = doc.data();

      // Seguridad: Límite de 3 intentos
      if (data.intentos >= 3) {
        await otpRef.delete();
        throw new HttpsError("permission-denied", "Demasiados intentos fallidos. Solicita un nuevo código.");
      }

      // Validación de tiempo: 60 segundos
      const diff = (new Date() - data.creadoEn.toDate()) / 1000;
      if (diff > 60) {
        await otpRef.delete();
        throw new HttpsError("deadline-exceeded", "El código ha expirado.");
      }

      if (data.otp !== otp) {
        await otpRef.update({ intentos: admin.firestore.FieldValue.increment(1) });
        throw new HttpsError("invalid-argument", "Código incorrecto.");
      }

      // Éxito: Marcar como verificado (guardamos un flag temporal o simplemente retornamos success)
      // Para mayor seguridad, podríamos generar un "token de reset" corto.
      await otpRef.update({ verificado: true });
      return { success: true, uid: uid };

    } catch (error) {
      console.error("Error en verificarOtpRecuperacion:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error.message);
    }
  }
);

exports.changePasswordSecure = onCall(
  { region: "us-central1" },
  async (request) => {
    const { uid, newPassword } = request.data;
    if (!uid || !newPassword || newPassword.length < 6) {
      throw new HttpsError("invalid-argument", "Datos inválidos.");
    }

    try {
      const db = admin.firestore();
      const otpRef = db.collection("otp_recuperacion").doc(uid);
      const doc = await otpRef.get();

      if (!doc.exists || !doc.data().verificado) {
        throw new HttpsError("permission-denied", "Debes verificar el OTP primero.");
      }

      // Cambio real de contraseña
      await admin.auth().updateUser(uid, { password: newPassword });

      // Desbloqueo de cuenta en Firestore (si aplica)
      const userRef = db.collection("usuarios").doc(uid);
      await userRef.update({
        estado: "activo",
        bloqueado: false,
        intentosFallidos: 0
      }).catch(() => {}); // Ignorar si el doc no existe o no tiene esos campos (ej. admin)

      // Limpiar rastro
      await otpRef.delete();

      return { success: true };
    } catch (error) {
      throw new HttpsError("internal", error.message);
    }
  }
);

// ── Mercado Pago ─────────────────────────────────────────────────────────────

exports.bloquearYCrearPreferencia = onCall(
  {
    region: "us-central1",
    secrets: ["MP_ACCESS_TOKEN"],
  },
  async (request) => {
    const { viajeId, pasajeroId, asientos, viajeros, monto, email, paradero } = request.data;

    if (!viajeId || !pasajeroId || !asientos || !viajeros || !monto || !paradero) {
      throw new HttpsError("invalid-argument", "Faltan parámetros obligatorios.");
    }

    try {
      const db = admin.firestore();

      // 1. Bloquear múltiples asientos mediante transacción (CP03)
      const bloqueadoExitoso = await db.runTransaction(async (tx) => {
        const vRef = db.collection("viajes").doc(viajeId);
        const vSnap = await tx.get(vRef);
        if (!vSnap.exists) throw new Error("Viaje no encontrado");

        const vData = vSnap.data();
        const asientosMapa = vData.asientos || {};

        for (const numAsiento of asientos) {
          const key = `asiento_${numAsiento}`;
          if (asientosMapa[key] && asientosMapa[key].estado !== 'libre') {
            return false; // Uno de los asientos ya no está libre
          }
        }

        // Marcar todos como bloqueados
        const now = admin.firestore.FieldValue.serverTimestamp();
        for (const numAsiento of asientos) {
          const key = `asiento_${numAsiento}`;
          asientosMapa[key] = {
            numero: numAsiento,
            estado: 'bloqueado',
            bloqueado_por: pasajeroId,
            bloqueado_at: now
          };
        }

        tx.update(vRef, { asientos: asientosMapa });
        return true;
      });

      if (!bloqueadoExitoso) {
        throw new HttpsError("already-exists", "Uno de los asientos elegidos acaba de ser ocupado. Por favor elige otros.");
      }

      const expiraEn = new Date();
      expiraEn.setMinutes(expiraEn.getMinutes() + 10);

      // 2. Crear registros de reserva temporal (CP01, CP02)
      const reservaGroupId = db.collection("reservas").doc().id;

      const promesas = viajeros.map((v, index) => {
        return db.collection("reservas").add({
          viajeId,
          pasajeroUid: pasajeroId,
          nombreViajero: v.nombre,
          dniViajero: v.dni,
          numeroAsiento: v.asiento,
          paradero,
          estado: 'bloqueada',
          monto: 15,
          reservaGroupId,
          esTitular: index === 0, // El primero del array es el titular
          creadoEn: admin.firestore.FieldValue.serverTimestamp(),
          expira_en: admin.firestore.Timestamp.fromDate(expiraEn),
          notificado_8min: false
        });
      });

      await Promise.all(promesas);

      // 3. Configurar Mercado Pago — DIAGNÓSTICO TEMPORAL con fetch directo
      const bodyMp = {
        items: [
          {
            id: `reserva_${reservaGroupId}`,
            title: `Reserva Colectivo - ${asientos.length} Asientos`,
            quantity: 1,
            unit_price: Number(monto),
            currency_id: 'PEN'
          }
        ],
        payer: { email: email || "pasajero_sicol@test.com" },
        notification_url: "https://us-central1-jupiter-da0d7.cloudfunctions.net/webhookMercadoPago",
        external_reference: JSON.stringify({
          reservaGroupId,
          viajeId,
          pasajeroId,
          paradero
        }),
        back_urls: BACK_URLS,
        auto_return: "approved"
      };

      const mpRawResponse = await fetch("https://api.mercadopago.com/checkout/preferences", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${process.env.MP_ACCESS_TOKEN}`
        },
        body: JSON.stringify(bodyMp)
      });

      const rawText = await mpRawResponse.text();
      console.error("MP STATUS:", mpRawResponse.status);
      console.error("MP RAW BODY:", rawText);
      console.error("MP TOKEN PREFIX:", (process.env.MP_ACCESS_TOKEN || "").substring(0, 8));

      let response;
      try {
        response = JSON.parse(rawText);
      } catch (e) {
        throw new HttpsError("internal", `MP devolvió una respuesta no-JSON. Status: ${mpRawResponse.status}. Body: ${rawText.substring(0, 200)}`);
      }

      if (!mpRawResponse.ok) {
        throw new HttpsError("internal", `Error de Mercado Pago (${mpRawResponse.status}): ${response.message || JSON.stringify(response)}`);
      }

      return {
        init_point: response.init_point,
        preference_id: response.id,
        reservaGroupId: reservaGroupId // Añadido para RF08
      };

    } catch (error) {
      console.error("ERROR bloquearYCrearPreferencia:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error.message);
    }
  }
);

exports.crearPreferenciaPago = onCall(
  {
    region: "us-central1",
    secrets: ["MP_ACCESS_TOKEN"],
  },
  async (request) => {
    const { viajeId, pasajeroId, asientoNumero, monto, email, paradero, nombrePasajero } = request.data;

    if (!viajeId || !pasajeroId || !asientoNumero || !monto || !paradero) {
      throw new HttpsError("invalid-argument", "Faltan parámetros obligatorios.");
    }

    try {
      const db = admin.firestore();

      const bloqueadoExitoso = await db.runTransaction(async (tx) => {
        const vRef = db.collection("viajes").doc(viajeId);
        const vSnap = await tx.get(vRef);
        if (!vSnap.exists) throw new Error("Viaje no encontrado");

        const vData = vSnap.data();
        const asientos = vData.asientos || {};
        const key = `asiento_${asientoNumero}`;

        if (asientos[key] && asientos[key].estado !== 'libre') {
          return false;
        }

        asientos[key] = {
          ...asientos[key],
          numero: asientoNumero,
          estado: 'bloqueado',
          bloqueado_por: pasajeroId,
          bloqueado_at: admin.firestore.FieldValue.serverTimestamp()
        };

        tx.update(vRef, { asientos });
        return true;
      });

      if (!bloqueadoExitoso) {
        throw new HttpsError("already-exists", "Este asiento acaba de ser ocupado. Por favor elige otro.");
      }

      const resRef = db.collection("reservas").doc();
      const expiraEn = new Date();
      expiraEn.setMinutes(expiraEn.getMinutes() + 10);

      await resRef.set({
        viajeId,
        pasajeroUid: pasajeroId,
        nombreViajero: nombrePasajero || "Pasajero",
        numeroAsiento: asientoNumero,
        paradero,
        estado: 'bloqueada',
        monto: 15,
        creadoEn: admin.firestore.FieldValue.serverTimestamp(),
        expira_en: admin.firestore.Timestamp.fromDate(expiraEn),
        notificado_8min: false
      });

      const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN });
      const preference = new Preference(client);

      const body = {
        items: [
          {
            id: `asiento_${asientoNumero}`,
            title: `Reserva Colectivo - Asiento ${asientoNumero}`,
            quantity: 1,
            unit_price: Number(monto),
            currency_id: 'PEN'
          }
        ],
        payer: {
          email: email || "pasajero_sicol@test.com"
        },
        notification_url: "https://us-central1-jupiter-da0d7.cloudfunctions.net/webhookMercadoPago",
        external_reference: JSON.stringify({
          viajeId,
          pasajeroId,
          asientoNumero,
          paradero,
          nombrePasajero: nombrePasajero || "Pasajero"
        }),
        back_urls: BACK_URLS,
        auto_return: "approved"
      };

      let response;
      try {
        response = await preference.create({ body });
      } catch (mpError) {
        console.error("ERROR Mercado Pago (crearPreferenciaPago):", JSON.stringify(mpError, null, 2));
        throw new HttpsError("internal", "No se pudo crear la preferencia de pago. Intenta nuevamente.");
      }

      return {
        init_point: response.init_point,
        preference_id: response.id
      };

    } catch (error) {
      console.error("ERROR crearPreferenciaPago:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error.message);
    }
  }
);

exports.webhookMercadoPago = onRequest({ secrets: ["MP_ACCESS_TOKEN"] }, async (req, res) => {
  const { action, type, data } = req.body;

  if (type === "payment" && (action === "payment.created" || action === "payment.updated")) {
    const paymentId = data.id;

    try {
      const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN });
      const payment = new Payment(client);

      const pData = await payment.get({ id: paymentId });

      if (pData.status === "approved") {
        const ref = JSON.parse(pData.external_reference);

        if (ref.reservaGroupId) {
          await registrarMultiReservaExitosa(ref, paymentId);
        } else {
          const { viajeId, pasajeroId, asientoNumero, paradero, nombrePasajero } = ref;
          const existingRes = await admin.firestore().collection("reservas")
            .where("paymentId", "==", paymentId.toString())
            .limit(1)
            .get();

          if (existingRes.empty) {
            await registrarReservaExitosa(viajeId, pasajeroId, asientoNumero, paradero, nombrePasajero, paymentId);
          }
        }
      }
    } catch (e) {
      console.error("Webhook Error:", e);
    }
  }

  res.sendStatus(200);
});

async function registrarMultiReservaExitosa(ref, paymentId) {
  const db = admin.firestore();
  const { reservaGroupId, viajeId, pasajeroId, paradero } = ref;

  try {
    const resSnap = await db.collection("reservas")
      .where("reservaGroupId", "==", reservaGroupId)
      .get();

    if (resSnap.empty) return;

    await db.runTransaction(async (tx) => {
      const viajeRef = db.collection('viajes').doc(viajeId);
      const vSnap = await tx.get(viajeRef);
      if (!vSnap.exists) return;

      const vData = vSnap.data();
      const asientosMapa = { ...(vData.asientos || {}) };
      const ocupadosLista = [...(vData.asientosListaOcupados || [])];

      for (const resDoc of resSnap.docs) {
        const rData = resDoc.data();
        const num = rData.numeroAsiento;
        const key = `asiento_${num}`;

        // CP04: Verificar si el asiento sigue bloqueado para nosotros
        if (!asientosMapa[key] || (asientosMapa[key].estado !== 'bloqueado' && asientosMapa[key].bloqueado_por !== pasajeroId)) {
          // Si el asiento ya no es nuestro (expiró y alguien más lo tomó), marcamos la reserva como fallida por concurrencia
          tx.update(resDoc.ref, { estado: 'error_concurrencia', paymentId: paymentId.toString() });
          continue;
        }

        if (!ocupadosLista.includes(num)) {
          ocupadosLista.push(num);
        }

        asientosMapa[key] = {
          numero: num,
          estado: 'ocupado',
          pasajero: {
            uid: pasajeroId,
            nombre: rData.nombreViajero,
            asiento: num,
            paradero: paradero,
          }
        };

        const codigo = Math.random().toString(36).substring(2, 7).toUpperCase();
        tx.update(resDoc.ref, {
          estado: 'confirmada',
          paymentId: paymentId.toString(),
          codigoVerificacion: codigo,
          confirmadoEn: admin.firestore.FieldValue.serverTimestamp()
        });

        // CP02: Notificar al pasajero
        await enviarPushUsuario(pasajeroId, {
          notification: {
            title: "Tu pago fue confirmado",
            body: `Asiento ${num} reservado con éxito.`
          }
        });

        // RF09 CP01: Generar Comprobante
        await generarComprobanteConReintento(resDoc, vData, paymentId);
      }

      tx.update(viajeRef, {
        asientosListaOcupados: ocupadosLista,
        asientos: asientosMapa,
        asientosOcupados: ocupadosLista.length,
        ingresoTotal: (vData.ingresoTotal || 0) + (15 * resSnap.size)
      });
    });

    const viajeDoc = await db.collection('viajes').doc(viajeId).get();
    const vData = viajeDoc.data();

    // CP02: Notificar al conductor por cada pasajero nuevo
    for (const resDoc of resSnap.docs) {
      const rData = resDoc.data();
      await enviarPushUsuario(vData.conductorUid, {
        notification: {
          title: "Nueva reserva confirmada",
          body: `${rData.nombreViajero} - Asiento ${rData.numeroAsiento} - Paradero ${paradero}.`
        }
      });
    }

    // CP02: Notificar al admin (RF48)
    const totalPagado = 15 * resSnap.size;
    await notificarAdminPagoExitoso(totalPagado, resSnap.docs[0].ref);

    if (vData.asientosOcupados >= vData.capacidad && vData.estado === 'activo') {
      await enviarNotificacionLlenado(viajeId, vData.conductorUid);
    }

  } catch (e) {
    console.error("Error en registrarMultiReservaExitosa:", e);
  }
}

async function enviarPushUsuario(uid, payload) {
  try {
    const userDoc = await admin.firestore().collection("usuarios").doc(uid).get();
    const token = userDoc.data()?.fcmToken;
    if (token) {
      await admin.messaging().send({ token, ...payload });
    }
  } catch (e) {
    console.error("Error enviando push a", uid, e);
  }
}

async function registrarReservaExitosa(viajeId, pasajeroId, asientoNumero, paradero, nombrePasajero, paymentId) {
  const db = admin.firestore();

  try {
    const resSnap = await db.collection("reservas")
      .where("viajeId", "==", viajeId)
      .where("pasajeroUid", "==", pasajeroId)
      .where("numeroAsiento", "==", asientoNumero)
      .where("estado", "==", "bloqueada")
      .limit(1)
      .get();

    await db.runTransaction(async (tx) => {
      const viajeRef = db.collection('viajes').doc(viajeId);
      const vSnap = await tx.get(viajeRef);
      if (!vSnap.exists) return;

      const vData = vSnap.data();
      const asientosMapa = { ...(vData.asientos || {}) };
      const key = `asiento_${asientoNumero}`;

      // CP04: Verificar concurrencia
      if (!asientosMapa[key] || (asientosMapa[key].estado !== 'bloqueado' && asientosMapa[key].bloqueado_por !== pasajeroId)) {
        if (!resSnap.empty) tx.update(resSnap.docs[0].ref, { estado: 'error_concurrencia' });
        return;
      }

      const ocupados = Array.from(vData.asientosListaOcupados || []);
      if (!ocupados.includes(asientoNumero)) {
        ocupados.push(asientoNumero);
      }

      asientosMapa[key] = {
        numero: asientoNumero,
        estado: 'ocupado',
        pasajero: {
          uid: pasajeroId,
          nombre: nombrePasajero,
          asiento: asientoNumero,
          paradero: paradero,
        }
      };

      tx.update(viajeRef, {
        asientosListaOcupados: ocupados,
        asientos: asientosMapa,
        asientosOcupados: ocupados.length,
        ingresoTotal: (vData.ingresoTotal || 0) + 15
      });

      const codigo = Math.random().toString(36).substring(2, 7).toUpperCase();

      if (!resSnap.empty) {
        tx.update(resSnap.docs[0].ref, {
          estado: 'confirmada',
          paymentId: paymentId.toString(),
          codigoVerificacion: codigo,
          confirmadoEn: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      // CP02: Notificar pasajero
      await enviarPushUsuario(pasajeroId, {
        notification: {
          title: "Tu pago fue confirmado",
          body: `Asiento ${asientoNumero} reservado con éxito.`
        }
      });

      // RF09 CP01: Generar Comprobante
      if (!resSnap.empty) {
        await generarComprobanteConReintento(resSnap.docs[0], vData, paymentId);
      }

      // CP02: Notificar conductor
      await enviarPushUsuario(vData.conductorUid, {
        notification: {
          title: "Nueva reserva confirmada",
          body: `${nombrePasajero} - Asiento ${asientoNumero} - Paradero ${paradero}.`
        }
      });

      // CP02: Notificar admin (RF48)
      await notificarAdminPagoExitoso(15, resSnap.docs[0].ref);
    });

    const viajeDoc = await db.collection('viajes').doc(viajeId).get();
    const vData = viajeDoc.data();
    if (vData.asientosOcupados >= vData.capacidad && vData.estado === 'activo') {
      await enviarNotificacionLlenado(viajeId, vData.conductorUid);
    }

  } catch (e) {
    console.error("Error en registrarReservaExitosa:", e);
  }
}

async function enviarNotificacionLlenado(viajeId, conductorUid) {
  const db = admin.firestore();
  try {
    const conductorDoc = await db.collection("usuarios").doc(conductorUid).get();
    const fcmToken = conductorDoc.data().fcmToken;

    if (fcmToken) {
      const payload = {
        notification: {
          title: "¡Colectivo lleno!",
          body: "Todos los asientos están ocupados. Puedes arrancar.",
        },
        data: {
          tipo: "colectivo_lleno",
          viajeId: viajeId
        }
      };
      await admin.messaging().send({ token: fcmToken, ...payload });
    }
  } catch (e) {
    console.error("Error enviando notificación de llenado:", e);
  }
}

async function enviarNotificacionReserva(viajeId, nombrePasajero, asientoNumero, paradero) {
  const db = admin.firestore();
  try {
    const viajeDoc = await db.collection("viajes").doc(viajeId).get();
    const conductorUid = viajeDoc.data().conductorUid;

    const conductorDoc = await db.collection("usuarios").doc(conductorUid).get();
    const fcmToken = conductorDoc.data().fcmToken;

    const payload = {
      notification: {
        title: "Nueva reserva confirmada",
        body: `${nombrePasajero} reservó el asiento ${asientoNumero}. Recógelo en ${paradero}.`,
      },
      data: {
        tipo: "nueva_reserva",
        viajeId: viajeId
      }
    };

    if (fcmToken) {
      await admin.messaging().send({ token: fcmToken, ...payload });
    }
  } catch (e) {
    console.error("Error enviando notificación:", e.message);
  }
}

exports.verificarExpiracionBloqueos = onSchedule("every 1 minutes", async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  try {
    const bloqueosExpirados = await db.collection("reservas")
      .where("estado", "==", "bloqueada")
      .where("expira_en", "<=", now)
      .get();

    for (const resDoc of bloqueosExpirados.docs) {
      const data = resDoc.data();
      await liberarAsientoBloqueado(data.viajeId, data.numeroAsiento, resDoc.ref, "expirado", data.pasajeroUid);
    }

    const avisoThreshold = new Date(now.toDate());
    avisoThreshold.setMinutes(avisoThreshold.getMinutes() + 2);

    const bloqueosPorExpirar = await db.collection("reservas")
      .where("estado", "==", "bloqueada")
      .where("notificado_8min", "==", false)
      .where("expira_en", "<=", admin.firestore.Timestamp.fromDate(avisoThreshold))
      .get();

    for (const resDoc of bloqueosPorExpirar.docs) {
      const data = resDoc.data();
      await enviarAvisoExpiracion(data.pasajeroUid, resDoc.ref);
    }

  } catch (e) {
    console.error("Error en verificarExpiracionBloqueos:", e);
  }
});

async function liberarAsientoBloqueado(viajeId, numeroAsiento, resRef, motivo, pasajeroUid) {
  const db = admin.firestore();
  try {
    await db.runTransaction(async (tx) => {
      const vRef = db.collection("viajes").doc(viajeId);
      const vSnap = await tx.get(vRef);
      if (!vSnap.exists) return;

      const vData = vSnap.data();
      const asientos = { ...(vData.asientos || {}) };
      const key = `asiento_${numeroAsiento}`;

      if (asientos[key] && asientos[key].estado === 'bloqueado') {
        asientos[key] = {
          numero: numeroAsiento,
          estado: 'libre',
          pasajero: null
        };
        tx.update(vRef, { asientos });
        tx.update(resRef, { estado: 'expirada' });
      }
    });

    if (motivo === "expirado") {
      await enviarNotificacionExpiracion(pasajeroUid);
    }
  } catch (e) {
    console.error(`Error liberando asiento ${numeroAsiento}:`, e);
  }
}

async function enviarAvisoExpiracion(pasajeroUid, resRef) {
  const db = admin.firestore();
  try {
    const userDoc = await db.collection("usuarios").doc(pasajeroUid).get();
    const token = userDoc.data()?.fcmToken;

    if (token) {
      await admin.messaging().send({
        token,
        notification: {
          title: "⏳ Reserva por expirar",
          body: "Tu tiempo de reserva está por expirar (2 minutos restantes). Completa tu pago pronto.",
        }
      });
      await resRef.update({ notificado_8min: true });
    }
  } catch (e) {
    console.error("Error aviso expiración:", e);
  }
}

async function enviarNotificacionExpiracion(pasajeroUid) {
  const db = admin.firestore();
  try {
    const userDoc = await db.collection("usuarios").doc(pasajeroUid).get();
    const token = userDoc.data()?.fcmToken;

    if (token) {
      await admin.messaging().send({
        token,
        notification: {
          title: "❌ Reserva expirada",
          body: "Tu tiempo de reserva expiró. Los asientos fueron liberados.",
        }
      });
    }
  } catch (e) {
    console.error("Error notificación expiración:", e);
  }
}

exports.changePassword = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    const uid = request.data.uid;
    const newPassword = request.data.newPassword;
    if (!uid || !newPassword || newPassword.length < 6) {
      throw new HttpsError("invalid-argument", "Datos inválidos.");
    }
    try {
      await admin.auth().updateUser(uid.trim(), { password: newPassword });
      return { success: true };
    } catch (error) {
      throw new HttpsError("internal", error.message);
    }
  }
);

exports.triggerNotificarIncidencia = onDocumentCreated(
  {
    document: "incidencias/{id}",
    region: "us-central1",
  },
  async (event) => {
    const ahora = event.data.data();
    if (!ahora) return;
    const { viajeId, tipo, minutosRetraso } = ahora;
    if (!viajeId) return;
    try {
      if (tipo === "Desvío de ruta") {
        await enviarPushAPasajeros(viajeId, {
          notification: {
            title: "Cambio en tu ruta",
            body: "El conductor se ha desviado de la ruta original.",
          },
          data: { tipo: "desvio_ruta", viajeId }
        });
      }
      if (tipo === "Retraso" && minutosRetraso && minutosRetraso >= 5) {
        await enviarPushAPasajeros(viajeId, {
          notification: {
            title: "⚠️ Retraso en llegada",
            body: `Tu colectivo presenta un retraso. Nuevo tiempo estimado: +${minutosRetraso} min.`,
          },
          data: { tipo: "retraso_llegada", viajeId }
        });
      }
    } catch (error) {
      console.error("ERROR en triggerNotificarIncidencia:", error.message);
    }
  }
);

async function enviarPushAPasajeros(viajeId, payload) {
  const reservasSnap = await admin.firestore().collection("reservas")
    .where("viajeId", "==", viajeId)
    .where("estado", "==", "confirmada")
    .get();
  if (reservasSnap.empty) return;
  const promesas = [];
  for (const resDoc of reservasSnap.docs) {
    const pasajeroUid = resDoc.data().pasajeroUid;
    const pasajeroDoc = await admin.firestore().collection("usuarios").doc(pasajeroUid).get();
    const fcmToken = pasajeroDoc.exists ? pasajeroDoc.data().fcmToken : null;
    if (fcmToken) {
      promesas.push(admin.messaging().send({ token: fcmToken, ...payload }));
    }
  }
  return Promise.all(promesas);
}

exports.notificarNuevoConductorPendiente = onDocumentUpdated(
  {
    document: "usuarios/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const antes = event.data.before.data();
    const ahora = event.data.after.data();
    if (ahora.rol === 'conductor' && ahora.estado === 'pendiente_aprobacion' && antes.estado !== 'pendiente_aprobacion') {
      try {
        const adminsSnap = await admin.firestore().collection("admins").get();
        const payload = {
          notification: { title: "Nuevo conductor", body: "Nuevo conductor pendiente de aprobación" },
          data: { tipo: "nuevo_conductor_pendiente", userId: event.params.userId }
        };
        const promesas = [];
        for (const adminDoc of adminsSnap.docs) {
          const fcmToken = adminDoc.data().fcmToken;
          if (fcmToken) promesas.push(admin.messaging().send({ token: fcmToken, ...payload }));
        }
        await Promise.all(promesas);
      } catch (error) {
        console.error("ERROR en notificarNuevoConductorPendiente:", error.message);
      }
    }
  }
);

exports.notificarViajeFinalizado = onDocumentUpdated(
  {
    document: "viajes/{viajeId}",
    region: "us-central1",
  },
  async (event) => {
    const antes = event.data.before.data();
    const ahora = event.data.after.data();
    if (antes.estado === "finalizado" || ahora.estado !== "finalizado") return;
    const viajeId = event.params.viajeId;
    try {
      const reservasSnap = await admin.firestore().collection("reservas")
        .where("viajeId", "==", viajeId)
        .where("estado", "==", "finalizada")
        .get();
      if (reservasSnap.empty) return;
      const promesas = [];
      for (const resDoc of reservasSnap.docs) {
        const resData = resDoc.data();
        const pasajeroDoc = await admin.firestore().collection("usuarios").doc(resData.pasajeroUid).get();
        const fcmToken = pasajeroDoc.exists ? pasajeroDoc.data().fcmToken : null;
        if (fcmToken) {
          const payload = {
            notification: {
              title: "✅ Viaje finalizado",
              body: "Tu viaje ha finalizado. ¿Cómo fue tu experiencia? Toca aquí para calificar.",
            },
            data: {
              tipo: "viaje_finalizado",
              viajeId: viajeId,
              reservaId: resDoc.id,
              conductorUid: ahora.conductorUid,
              conductorNombre: ahora.conductorNombre
            }
          };
          promesas.push(admin.messaging().send({ token: fcmToken, ...payload }));
        }
      }
      await Promise.all(promesas);
    } catch (error) {
      console.error("ERROR en notificarViajeFinalizado:", error.message);
    }
  }
);

exports.notificarCancelacionReserva = onDocumentUpdated(
  {
    document: "reservas/{reservaId}",
    region: "us-central1",
  },
  async (event) => {
    const antes = event.data.before.data();
    const ahora = event.data.after.data();
    if (antes.estado === "cancelada" || ahora.estado !== "cancelada") return;
    const { viajeId, nombreViajero, numeroAsiento, paradero } = ahora;
    if (!viajeId) return;
    try {
      const viajeSnap = await admin.firestore().collection("viajes").doc(viajeId).get();
      if (!viajeSnap.exists) return;
      const conductorUid = viajeSnap.data().conductorUid;
      const conductorDoc = await admin.firestore().collection("usuarios").doc(conductorUid).get();
      const fcmToken = conductorDoc.exists ? conductorDoc.data().fcmToken : null;
      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Cancelación de reserva",
            body: `${nombreViajero} canceló su reserva. Asiento ${numeroAsiento} libre en ${paradero || 'paradero'}.`,
          },
          data: { tipo: "cancelacion_reserva", viajeId: viajeId },
        });
      }

      // CP01: Notificar a otros pasajeros si el viaje NO ha arrancado (RF28)
      if (viajeSnap.data().estado === "activo") {
        const payloadPasajeros = {
          notification: {
            title: "🪑 Asiento disponible",
            body: `Se liberó el asiento ${numeroAsiento}. ¿Deseas cambiarte a este asiento?`,
          },
          data: {
            tipo: "asiento_liberado",
            viajeId: viajeId,
            asientoLibre: numeroAsiento.toString()
          }
        };

        const otrasReservas = await admin.firestore().collection("reservas")
            .where("viajeId", "==", viajeId)
            .where("estado", "==", "confirmada")
            .get();

        for (const resDoc of otrasReservas.docs) {
          const pUid = resDoc.data().pasajeroUid;
          if (pUid === ahora.pasajeroUid) continue;

          const pDoc = await admin.firestore().collection("usuarios").doc(pUid).get();
          const pToken = pDoc.data()?.fcmToken;
          if (pToken) {
            await admin.messaging().send({ token: pToken, ...payloadPasajeros });
          }
        }
      }
    } catch (error) {
      console.error("ERROR en notificarCancelacionReserva:", error.message);
    }
  }
);

exports.notificarProximidadLlegada = onDocumentUpdated(
  {
    document: "viajes/{viajeId}",
    region: "us-central1",
  },
  async (event) => {
    const ahora = event.data.after.data();
    const antes = event.data.before.data();
    if (!ahora || !ahora.ubicacionActual || ahora.estado !== 'en_camino') return;
    const pos = ahora.ubicacionActual;
    const posAntes = antes.ubicacionActual;
    if (posAntes && pos.lat === posAntes.lat && pos.lng === posAntes.lng) return;
    try {
      const db = admin.firestore();
      const reservasSnap = await db.collection("reservas")
        .where("viajeId", "==", event.params.viajeId)
        .where("estado", "==", "confirmada")
        .get();
      for (const resDoc of reservasSnap.docs) {
        const resData = resDoc.data();
        const paradero = resData.paradero;
        const coords = PARADEROS_COORDS[paradero];
        if (coords) {
          const dist = getDistance(pos.lat, pos.lng, coords.lat, coords.lng);
          if (dist <= 300 && !resData.notificado_proximidad) {
            const pasajeroDoc = await db.collection("usuarios").doc(resData.pasajeroUid).get();
            const token = pasajeroDoc.data().fcmToken;
            if (token) {
              await admin.messaging().send({
                token,
                notification: { title: "🚌 Tu colectivo está llegando", body: "¡Prepárate!" }
              });
              await resDoc.ref.update({ notificado_proximidad: true });
            }
          }
        }
      }
    } catch (e) { console.error(e); }
  }
);

exports.notificarLlegadaManual = onCall({ region: "us-central1" }, async (request) => {
  const { nombrePasajero } = request.data;
  const db = admin.firestore();
  try {
    const resSnap = await db.collection("reservas").where("nombreViajero", "==", nombrePasajero).where("estado", "==", "confirmada").limit(1).get();
    if (resSnap.empty) return { success: false };
    const resData = resSnap.docs[0].data();
    const pasajeroDoc = await db.collection("usuarios").doc(resData.pasajeroUid).get();
    const token = pasajeroDoc.data().fcmToken;
    if (token) {
      await admin.messaging().send({
        token,
        notification: { title: "✅ Tu colectivo llegó", body: "¡Sal ahora!" }
      });
      await resSnap.docs[0].ref.update({ llegada_conductor_at: admin.firestore.FieldValue.serverTimestamp() });
      return { success: true };
    }
  } catch (e) { throw new HttpsError("internal", e.message); }
});

exports.enviarRecordatoriosViaje = onSchedule("every 5 minutes", async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now().toMillis();
  const rangeStart = now + (25 * 60 * 1000);
  const rangeEnd = now + (35 * 60 * 1000);
  try {
    const viajesSnap = await db.collection("viajes").where("estado", "==", "activo").where("fechaSalida", ">=", admin.firestore.Timestamp.fromMillis(rangeStart)).where("fechaSalida", "<=", admin.firestore.Timestamp.fromMillis(rangeEnd)).get();
    for (const vDoc of viajesSnap.docs) {
      const reservasSnap = await db.collection("reservas").where("viajeId", "==", vDoc.id).where("estado", "==", "confirmada").get();
      for (const rDoc of reservasSnap.docs) {
        const rData = rDoc.data();
        if (rData.recordatorio_enviado === true) continue;
        const pasajeroDoc = await db.collection("usuarios").doc(rData.pasajeroUid).get();
        const fcmToken = pasajeroDoc.exists ? pasajeroDoc.data().fcmToken : null;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title: "🚌 Tu viaje sale pronto", body: "Tu colectivo sale en 30 minutos." }
          });
          await rDoc.ref.update({ recordatorio_enviado: true });
        }
      }
    }
  } catch (error) { console.error(error); }
});

const PARADEROS_COORDS = {
  "Plaza de Armas de Chosica": { lat: -11.9347, lng: -76.6952 },
  "Ñaña": { lat: -11.9100, lng: -76.6300 },
  "Huachipa": { lat: -11.8900, lng: -76.5800 },
  "Ate Vitarte": { lat: -11.9050, lng: -76.9900 },
  "La Molina": { lat: -12.0400, lng: -76.9800 },
  "Javier Prado": { lat: -12.0650, lng: -77.0000 },
  "Petit Thouars": { lat: -12.0950, lng: -77.0450 },
};

async function notificarAdmin(titulo, cuerpo) {
  const db = admin.firestore();
  const adminsSnap = await db.collection("admins").get();

  const payload = {
    notification: {
      title: titulo,
      body: cuerpo,
    },
    data: {
      tipo: "alerta_admin_general"
    }
  };

  const promesas = [];
  for (const adminDoc of adminsSnap.docs) {
    const fcmToken = adminDoc.data().fcmToken;
    if (fcmToken) {
      promesas.push(admin.messaging().send({ token: fcmToken, ...payload }));
    }
  }
  return Promise.all(promesas);
}

async function notificarAdminPagoExitoso(montoTotal, resDocRef) {
  // RF48: Notificación al Administrador de Pago Exitoso
  // El desglose es fijo por cada S/15.00: Conductor 10, Operador 4, Plataforma 1.
  // Si el montoTotal es múltiplo, el admin verá la notificación por la transacción.

  const titulo = '💰 Nuevo pago recibido';
  const cuerpo = `Pago de S/${montoTotal.toFixed(2)} procesado. Conductor: S/${(montoTotal * 10 / 15).toFixed(2)} | Operador: S/${(montoTotal * 4 / 15).toFixed(2)} | Plataforma: S/${(montoTotal * 1 / 15).toFixed(2)}`;

  let intentos = 0;
  let exito = false;

  while (intentos < 3 && !exito) {
    try {
      await notificarAdmin(titulo, cuerpo);
      exito = true;
      console.log(`✅ RF48: Notificación admin enviada para pago de S/${montoTotal}`);
    } catch (e) {
      intentos++;
      console.error(`❌ RF48: Error notificacion admin (intento ${intentos}):`, e.message);
      if (intentos < 3) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }

  if (!exito) {
    // Si fallan todos los reintentos, guardar en Firestore (reserva o registro de pago)
    await resDocRef.update({ notificacion_admin_pendiente: true });
    console.log("⚠️ RF48: Notificación admin marcada como pendiente en Firestore.");
  }
}

async function enviarAlertaAdmin(titulo, cuerpo) {
  await notificarAdmin(titulo, cuerpo);
}

async function generarComprobanteConReintento(resDoc, vData, paymentId) {
  const resData = resDoc.data();

  const comprobante = {
    codigoComprobante: `CMP-${resDoc.id.substring(0, 8).toUpperCase()}`,
    viajeroNombre: resData.nombreViajero || "-",
    asiento: resData.numeroAsiento,
    paradero: resData.paradero || "-",
    conductorNombre: vData.conductorNombre || "Conductor Sicol",
    placaVehiculo: vData.vehiculo?.placa || "-",
    ruta: vData.rutaLabel || "Chosica - Lima",
    monto: resData.monto || 15.0,
    fechaEmision: admin.firestore.FieldValue.serverTimestamp(),
    codigoVerificacion: resData.codigoVerificacion || "-",
    paymentId: paymentId
  };

  let intentos = 0;
  let exito = false;

  while (intentos < 3 && !exito) {
    try {
      await resDoc.ref.update({
        comprobante: comprobante,
        comprobante_generado: true,
        comprobante_pendiente: false
      });
      exito = true;
      console.log(`✅ Comprobante generado para reserva ${resDoc.id}`);
    } catch (e) {
      intentos++;
      console.error(`❌ Fallo generación comprobante (intento ${intentos}):`, e.message);
      if (intentos === 3) {
        await resDoc.ref.update({ comprobante_pendiente: true });
      } else {
        // Pequeña espera antes de reintentar
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }
  }
}

function getDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
  const phi1 = lat1 * Math.PI / 180;
  const phi2 = lat2 * Math.PI / 180;
  const deltaPhi = (lat2 - lat1) * Math.PI / 180;
  const deltaLambda = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) + Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

exports.abandonarViajesHuerfanos = onSchedule("every 1 hours", async (event) => {
  const db = admin.firestore();
  const threshold = new Date();
  threshold.setHours(threshold.getHours() - 8);

  try {
    const viajesHuerfanos = await db.collection("viajes")
      .where("estado", "in", ["activo", "en_camino"])
      .where("iniciadoEn", "<=", admin.firestore.Timestamp.fromDate(threshold))
      .get();

    if (viajesHuerfanos.empty) return;

    const batch = db.batch();
    for (const vDoc of viajesHuerfanos.docs) {
      const data = vDoc.data();
      batch.update(vDoc.ref, {
        estado: "abandonado",
        abandonadoEn: admin.firestore.FieldValue.serverTimestamp()
      });

      // Liberar al conductor
      if (data.conductorUid) {
        batch.update(db.collection("usuarios").doc(data.conductorUid), {
          disponible: true,
          viajeActivoId: null
        });
      }
    }

    await batch.commit();
    console.log(`✅ ${viajesHuerfanos.size} viajes marcados como abandonados.`);
  } catch (e) {
    console.error("Error en abandonarViajesHuerfanos:", e);
  }
});

// ── Notificaciones de Simulación (Debug) ───────────────────────────────────

exports.simularColectivoLlegando = onCall({ region: "us-central1" }, async (request) => {
  const { viajeId, pasajeroId } = request.data;
  if (!viajeId || !pasajeroId) throw new HttpsError("invalid-argument", "Faltan IDs.");

  try {
    await enviarPushUsuario(pasajeroId, {
      notification: { title: "🚌 Tu colectivo está llegando (Simulado)", body: "¡Prepárate! El bus está muy cerca." },
      data: { tipo: "colectivo_llegando_sim", viajeId }
    });
    return { success: true };
  } catch (e) { throw new HttpsError("internal", e.message); }
});

exports.simularRecordatorio = onCall({ region: "us-central1" }, async (request) => {
  const { viajeId } = request.data;
  if (!viajeId) throw new HttpsError("invalid-argument", "Falta viajeId.");

  try {
    const reservasSnap = await admin.firestore().collection("reservas")
      .where("viajeId", "==", viajeId)
      .where("estado", "==", "confirmada")
      .get();

    const promesas = reservasSnap.docs.map(resDoc => {
      return enviarPushUsuario(resDoc.data().pasajeroUid, {
        notification: { title: "🚌 Recordatorio de viaje (Simulado)", body: "Tu colectivo sale en aproximadamente 30 minutos." },
        data: { tipo: "recordatorio_sim", viajeId }
      });
    });

    await Promise.all(promesas);
    return { success: true, count: reservasSnap.size };
  } catch (e) { throw new HttpsError("internal", e.message); }
});

// ── Notificaciones Faltantes ───────────────────────────────────────────────

exports.forzarCancelacionViajeAdmin = onCall({ region: "us-central1" }, async (request) => {
  const { viajeId, motivo } = request.data;
  const adminId = request.auth?.uid;
  if (!viajeId) throw new HttpsError("invalid-argument", "Falta viajeId.");

  const db = admin.firestore();
  try {
    const viajeRef = db.collection("viajes").doc(viajeId);
    const viajeSnap = await viajeRef.get();
    if (!viajeSnap.exists) throw new HttpsError("not-found", "Viaje no existe.");

    const vData = viajeSnap.data();
    const conductorUid = vData.conductorUid;

    // 1. Obtener todas las reservas activas
    const reservasSnap = await db.collection("reservas")
      .where("viajeId", "==", viajeId)
      .where("estado", "in", ["confirmada", "abordado"])
      .get();

    const batch = db.batch();

    // 2. Cancelar el viaje
    batch.update(viajeRef, {
      estado: "cancelado_admin",
      canceladoPor: adminId || "sistema",
      motivoCancelacion: motivo || "Cancelación forzada por administrador",
      canceladoEn: admin.firestore.FieldValue.serverTimestamp()
    });

    // 3. Liberar al conductor
    if (conductorUid) {
      batch.update(db.collection("usuarios").doc(conductorUid), {
        disponible: true,
        viajeActivoId: null
      });
    }

    // 4. Cancelar reservas y preparar notificaciones
    const promesasPush = [];
    for (const resDoc of reservasSnap.docs) {
      batch.update(resDoc.ref, { estado: "cancelada_viaje" });
      promesasPush.push(enviarPushUsuario(resDoc.data().pasajeroUid, {
        notification: {
          title: "🚨 Viaje cancelado",
          body: `Tu viaje con ${vData.conductorNombre} ha sido cancelado por el administrador. Se liberó tu asiento.`
        },
        data: { tipo: "viaje_cancelado_admin", viajeId }
      }));
    }

    await batch.commit();
    await Promise.all(promesasPush);

    return { success: true, reservasAfectadas: reservasSnap.size };
  } catch (e) { throw new HttpsError("internal", e.message); }
});

exports.notificarDecisionVehiculo = onDocumentUpdated(
  {
    document: "usuarios/{userId}",
    region: "us-central1",
  },
  async (event) => {
    const antes = event.data.before.data();
    const ahora = event.data.after.data();

    const vehiculoAntes = antes.vehiculo || {};
    const vehiculoAhora = ahora.vehiculo || {};

    if (ahora.rol === 'conductor' && vehiculoAhora.estado !== vehiculoAntes.estado) {
      let titulo = "";
      let cuerpo = "";

      if (vehiculoAhora.estado === 'aprobado') {
        titulo = "✅ Vehículo aprobado";
        cuerpo = "Ya puedes iniciar viajes con tu unidad.";
      } else if (vehiculoAhora.estado === 'rechazado') {
        titulo = "❌ Vehículo rechazado";
        cuerpo = `Motivo: ${vehiculoAhora.motivoRechazo || "Contacta al administrador."}`;
      }

      if (titulo !== "") {
        await enviarPushUsuario(event.params.userId, {
          notification: { title: titulo, body: cuerpo },
          data: { tipo: "decision_vehiculo", userId: event.params.userId }
        });
      }
    }
  }
);
