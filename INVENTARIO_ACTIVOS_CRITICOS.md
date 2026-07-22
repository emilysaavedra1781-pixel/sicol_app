# Inventario de Activos Críticos de Seguridad - SICOL

Este documento identifica y clasifica los activos de información y técnicos que son fundamentales para la seguridad del sistema SICOL (Colectivos Chosica-Lima). La protección de estos activos garantiza la integridad de los pagos, la privacidad de los usuarios y la continuidad del servicio.

| Orden | Activo | ¿Por qué es crítico? | Amenaza si no se protege | Control Aplicado | Estado | Observaciones |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Contraseña del usuario | El acceso principal a la cuenta del usuario (pasajero, conductor o admin). | Suplantación de identidad, robo de información, acceso a pagos. | Hashing automático en Firebase Auth; longitud mínima (lib/features/auth/register/register_view.dart). | ✅ Protegido | - |
| 2 | Token de Sesión (JWT) | Mantiene al usuario autenticado sin reingresar credenciales. | Secuestro de sesión (Session Hijacking), acceso no autorizado a datos. | Manejo automático por Firebase Auth SDK con rotación de tokens (main.dart). | ✅ Protegido | - |
| 3 | Correo Sintético ($celular@sicol.pe) | Identificador único en Firebase Auth para desacoplar el email real. | Exposición del esquema de identidad interno. | Generación algorítmica en AuthService.dart (línea 108). | ✅ Protegido | - |
| 4 | Email Real del Usuario | Canal de comunicación para recuperación de cuenta y OTP. | Phishing, Spam, fuga de privacidad (PII). | Restringido por firestore.rules (línea 16 - solo dueño o admin). | ✅ Protegido | - |
| 5 | Número de Celular | Utilizado para login de pasajeros y comunicación crítica. | Acoso, suplantación de identidad. | Restringido por firestore.rules (línea 16). | ✅ Protegido | - |
| 6 | Número de DNI | Identificador legal del ciudadano. | Robo de identidad, fraude financiero. | Cifrado en reposo por Google Cloud; reglas de acceso UID-based. | ✅ Protegido | - |
| 7 | Token FCM (Push) | Permite enviar notificaciones directas al dispositivo físico. | Envío de mensajes fraudulentos (Ghost Push). | Escritura restringida al dueño en firestore.rules (usuarios/{uid}). | ✅ Protegido | - |
| 8 | Número de Licencia de Conducir | Requisito legal para operar el servicio. | Multas, suplantación de conductores no autorizados. | Validación de formato en register_view.dart (línea 485). | ✅ Protegido | - |
| 9 | Documento DNI (PDF) | Imagen del documento físico subido por el conductor. | Falsificación, usurpación de identidad grave. | storage.rules restringido a dueño y admin (línea 22). | ✅ Protegido | - |
| 10 | Licencia de Conducir (PDF) | Imagen de la licencia física del conductor. | Falsificación, riesgos legales para la empresa. | storage.rules restringido a dueño y admin (línea 22). | ✅ Protegido | - |
| 11 | Tarjeta de Propiedad (PDF) | Imagen del documento del vehículo. | Información sensible sobre propiedad vehicular. | storage.rules restringido a dueño y admin (línea 22). | ✅ Protegido | - |
| 12 | Fotografía del Conductor | Validada por el administrador para seguridad del pasajero. | Suplantación de conductores (perfil falso). | storage.rules permite lectura solo a usuarios autenticados. | ✅ Protegido | - |
| 13 | Fotografía del Vehículo | Permite al pasajero identificar el colectivo correcto. | Engaño al pasajero, riesgos de seguridad física. | storage.rules permite lectura pública a usuarios autenticados. | ✅ Protegido | - |
| 14 | Placa del Vehículo | Identificador único del transporte. | Rastreo de flotas, riesgos de seguridad física. | Almacenado en usuarios/{uid}/vehiculo y protegido por reglas. | ✅ Protegido | - |
| 15 | MP Access Token | Clave secreta para procesar pagos y crear preferencias. | Fraude financiero masivo, desvío de fondos. | Firebase Secret Manager (functions/index.js línea 246). | ✅ Protegido | - |
| 16 | SMTP User (Email Soporte) | Cuenta de correo para envío de OTP y alertas. | Uso de la cuenta para spam o campañas de phishing. | Firebase Secret Manager (functions/index.js línea 44). | ✅ Protegido | - |
| 17 | SMTP Pass (Email Soporte) | Contraseña de la cuenta de correo de soporte. | Acceso total al correo corporativo. | Firebase Secret Manager (functions/index.js línea 44). | ✅ Protegido | - |
| 18 | Google Maps API Key (Android) | Permite el uso de mapas y geolocalización. | Robo de cuotas, uso no autorizado del servicio pagado. | Hardcodeado en AndroidManifest.xml (línea 13). | ⚠️ Pendiente | Se recomienda restringir por SHA-1 en la consola de GCP. |
| 19 | Google Maps API Key (iOS) | Permite el uso de mapas en dispositivos Apple. | Robo de cuotas de facturación. | Hardcodeado en firebase_options.dart (línea 70). | ⚠️ Pendiente | Se recomienda restringir por Bundle ID en GCP. |
| 20 | API Key de Firebase | Conecta la app con los servicios de Google Cloud. | Reconocimiento de infraestructura. | Hardcodeado (estándar de Firebase); restringido en consola. | ✅ Protegido | - |
| 21 | ID del Proyecto Firebase | Identificador único del backend. | Ataques dirigidos a la infraestructura. | Configurado en firebase_options.dart. | ✅ Protegido | - |
| 22 | Mercado Pago Public Key | Identifica la cuenta para el Checkout Pro. | Clonación de interfaz de pago (bypass sandbox). | lib/services/payment_service.dart (línea 5). | ✅ Protegido | - |
| 23 | Ubicación en Tiempo Real (GPS) | Coordenadas Lat/Lng del conductor en curso. | Rastreo físico, riesgo de secuestro o asalto. | firestore.rules (línea 52) restringe escritura al dueño. | ✅ Protegido | - |
| 24 | Ingresos Totales del Conductor | Dinero acumulado por pasajes. | Manipulación de balances, fraude. | firestore.rules (línea 34) prohíbe escritura al usuario. | ✅ Protegido | Controlado vía Cloud Functions. |
| 25 | Código OTP de Recuperación | Clave de 6 dígitos enviada por email. | Cambio de contraseña no autorizado. | Expira en 60s y tiene límite de 3 intentos (functions/index.js). | ✅ Protegido | - |
| 26 | Código de Verificación de Reserva | Código de 5 dígitos para abordar. | Robo de asientos, uso de pasajes ajenos. | Generado en servidor y solo lectura para el pasajero. | ✅ Protegido | - |
| 27 | Código de Encuentro (Grupal) | Agrupa múltiples reservas en un solo código corto. | Suplantación de grupos de pasajeros. | Generación aleatoria en functions/index.js. | ✅ Protegido | - |
| 28 | Flag de Administrador | Atributo que otorga permisos totales en la app. | Escalación de privilegios a nivel de sistema. | Colección /admins/ protegida por firestore.rules (línea 105). | ✅ Protegido | - |
| 29 | Reglas de Seguridad (Firestore) | Código que gobierna el acceso a los datos. | Fuga masiva de datos (Data Leak). | Archivo firestore.rules integrado en el deploy de Firebase. | ✅ Protegido | - |
| 30 | Reglas de Seguridad (Storage) | Código que gobierna el acceso a los archivos. | Exposición de fotos y documentos privados. | Archivo storage.rules integrado en el deploy de Firebase. | ✅ Protegido | - |
| 31 | Código Fuente de Cloud Functions | Lógica de negocio del lado del servidor. | Descubrimiento de vulnerabilidades lógicas. | Protegido en el entorno de ejecución de Google Cloud. | ✅ Protegido | - |
| 32 | Keystore de Release (sicol_release.jks) | Certificado digital para firmar la APK. | Suplantación de la app oficial en la tienda. | Archivo físico en root (debería estar fuera de control de versiones). | ⚠️ Pendiente | Mover fuera del repo y usar variables de entorno CI/CD. |
| 33 | Configuración de Nodemailer | Parámetros del transporte de correo. | Intercepción de correos salientes. | Configurado vía TLS/SSL en functions/index.js. | ✅ Protegido | - |
| 34 | External Reference (Mercado Pago) | Metadata enviada a la pasarela de pago. | Inyección de datos en la confirmación de pago. | Validado en functions/index.js durante el webhook. | ✅ Protegido | - |
| 35 | ID de Pago (paymentId) | Registro de la transacción bancaria. | Reutilización de pagos (Double Spend). | Verificación de idempotencia en functions/index.js. | ✅ Protegido | - |
| 36 | Rol del Usuario (rol) | Define si es pasajero, conductor o admin. | Acceso a funciones administrativas. | firestore.rules prohíbe su edición por el usuario (línea 21). | ✅ Protegido | - |
| 37 | Estado del Usuario (estado) | Controla si la cuenta está bloqueada o activa. | Activación de cuentas fraudulentas. | firestore.rules prohíbe su edición por el usuario (línea 21). | ✅ Protegido | - |
| 38 | Intentos Fallidos de Login | Contador para bloquear ataques de fuerza bruta. | Bruteforce exitoso contra cuentas de usuarios. | Lógica en AuthService.dart (línea 204). | ✅ Protegido | Bloqueo automático tras 3 intentos. |
| 39 | Estado del Viaje (estado) | Controla el ciclo de vida (activo, en_camino, finalizado). | Finalización de viajes sin pagar o sin llegar al destino. | firestore.rules restringe edición de campos financieros. | ✅ Protegido | - |
| 40 | Mapa de Asientos | Estado de ocupación en tiempo real. | Sobreventa de asientos (Overbooking). | Transacciones atómicas en functions/index.js. | ✅ Protegido | - |
| 41 | Historial de Reservas | Registro histórico de movimientos del usuario. | Fuga de privacidad sobre hábitos de viaje. | firestore.rules filtra por pasajeroUid. | ✅ Protegido | - |
| 42 | Detalle de Incidencias | Reportes de accidentes o problemas. | Manipulación de evidencias en disputas. | Reglas de solo lectura para el emisor y el admin. | ✅ Protegido | - |
| 43 | Calificaciones y Reseñas | Reputación de conductores y pasajeros. | Daño reputacional por falsas reseñas. | firestore.rules permite creación solo a pasajeros con reserva. | ✅ Protegido | - |
| 44 | messagingSenderId (FCM) | Identificador del remitente de push. | Suplantación del servidor de notificaciones. | Configurado en firebase_options.dart. | ✅ Protegido | - |
| 45 | App ID de Firebase | Identificador de la instancia de la aplicación. | Clonación de la aplicación. | Configurado en firebase_options.dart. | ✅ Protegido | - |
| 46 | Dependencias de Node.js | Librerías externas en el backend. | Ataques de cadena de suministro (Supply Chain). | package-lock.json fija versiones (functions/package-lock.json). | ✅ Protegido | - |
| 47 | Dependencias de Flutter | Librerías externas en el frontend. | Inyección de código malicioso vía plugins. | pubspec.lock fija versiones (pubspec.lock). | ✅ Protegido | - |
| 48 | Back URLs (Mercado Pago) | Redirecciones tras el pago. | Redirección a sitios de phishing. | Hardcodeado en functions/index.js (línea 23) sobre HTTPS. | ✅ Protegido | - |
| 49 | Esquema de Deep Link (sicolapp) | Permite abrir la app desde el navegador. | Secuestro de enlaces de pago. | Definido en AndroidManifest.xml (línea 38). | ✅ Protegido | - |
| 50 | Permiso de Ubicación (Runtime) | Acceso al hardware de GPS del teléfono. | Espionaje del usuario en segundo plano. | Solicitado explícitamente en location_service.dart (línea 81). | ✅ Protegido | - |
| 51 | Radio de Geofencing (500m) | Umbral de distancia para inicio/fin de viaje. | Fraude de ubicación por parte del conductor. | Lógica cliente en location_service.dart (línea 34). | ⚠️ Pendiente | Validar coordenadas finales en el servidor (Cloud Functions). |
| 52 | Gestión de Secretos SMTP | Credenciales de envío de correo. | Robo de credenciales si el código se expone. | secrets property en funciones V2 (functions/index.js línea 44). | ✅ Protegido | - |
| 53 | Endpoint de Webhook (MP) | URL que recibe confirmaciones de pago. | Inyección de pagos falsos. | Validado mediante consulta directa a API de MP (functions/index.js). | ✅ Protegido | - |
| 54 | Token FCM de Administrador | Permite enviar alertas de seguridad al admin. | Rastreo de actividad administrativa. | Almacenado en colección privada /admins/. | ✅ Protegido | - |

## Resumen de Estado
*   **Total de Activos Identificados**: 54
*   **Activos Protegidos (✅)**: 51
*   **Activos con Observaciones (⚠️)**: 3

**Acciones Recomendadas Prioritarias:**
1. Implementar restricciones de API Key en Google Cloud Console para Maps (SHA-1 y Bundle ID).
2. Mover el archivo `.jks` fuera del repositorio de código fuente.
3. Migrar la lógica de validación de geofencing de inicio de viaje al backend para evitar spoofing desde la app cliente.
