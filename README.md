# ITC Conecta

Aplicación de mensajería institucional para el **Tecnológico Nacional de México en Celaya (TecNM Celaya)**, desarrollada con Flutter y Firebase. Permite la comunicación en tiempo real entre alumnos y docentes con videollamadas P2P, tablón académico, historias efímeras y gestión de grupos.

---

## Índice

1. [Características](#características)
2. [Stack tecnológico](#stack-tecnológico)
3. [Estructura del proyecto](#estructura-del-proyecto)
4. [Diseño](#diseño)
5. [Flujo de autenticación](#flujo-de-autenticación)
6. [Colecciones Firestore](#colecciones-firestore)
7. [Reglas de seguridad](#reglas-de-seguridad)
8. [Sistema de roles](#sistema-de-roles)
9. [Instalación y configuración](#instalación-y-configuración)
10. [Compilar APK](#compilar-apk)
11. [Usuarios de prueba](#usuarios-de-prueba)
12. [Demo: flujo ideal](#demo-flujo-ideal)
13. [Mejoras futuras](#mejoras-futuras)

---

## Características

| Módulo | Funcionalidades implementadas |
|---|---|
| **Autenticación** | OTP por número de teléfono (Firebase Auth), setup inicial de perfil con foto |
| **Conversaciones** | Lista en tiempo real, filtros (Todos / No leídos / Grupos / Tablón), badge de no leídos |
| **Chat** | Texto, imágenes, videos, emojis, PDFs; indicador «Escribiendo…»; doble paloma de lectura |
| **Grupos** | Creación exclusiva para docentes, foto de grupo, opción de ocultar teléfonos a alumnos |
| **Detalle de grupo** | Lista de miembros con rol y badge de admin, cuadrícula multimedia, agregar miembros |
| **Videollamadas** | P2P con Agora RTC Engine, cámara frontal/trasera, silenciar, colgar, permiso en runtime |
| **Tablón académico** | Tipos Tarea/Aviso/Examen/Material, fecha límite, archivo adjunto (PDF/Word/PPT), contador de lecturas |
| **Historias** | Estados efímeros de 24 h (imagen o video), barra de progreso, contador de vistas |
| **Contactos** | Búsqueda por número de teléfono, lista de contactos guardados |
| **Perfil** | Nombre, carrera, rol, avatar vía Cloudinary |

---

## Stack tecnológico

| Capa | Tecnología | Versión |
|---|---|---|
| UI | Flutter / Dart | 3.x / 3.10.7 |
| Estado | flutter_riverpod | 2.6 |
| Navegación | go_router | 14.x |
| Autenticación | Firebase Auth (Phone OTP) | 5.x |
| Base de datos | Cloud Firestore | 5.x |
| Notificaciones | Firebase Messaging | 15.x |
| Almacenamiento de medios | Cloudinary | API REST |
| Videollamadas | Agora RTC Engine | 6.x |
| Permisos Android | permission_handler | 11.x |
| Picker de archivos | file_picker | 8.x |
| Apertura de URLs | url_launcher | 6.x |
| Internacionalización | flutter_localizations | SDK |

---

## Estructura del proyecto

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart      # Agora App ID, Cloudinary config,
│   │                               # roles, tipos de mensaje, carpetas
│   ├── router/
│   │   └── app_router.dart         # GoRouter con redirección por auth
│   └── theme/
│       └── app_theme.dart          # Paleta monocromática ITC Conecta
│
├── data/
│   ├── models/
│   │   ├── board_post_model.dart
│   │   ├── contact_model.dart
│   │   ├── conversation_model.dart
│   │   ├── message_model.dart
│   │   ├── story_model.dart
│   │   └── user_model.dart
│   └── repositories/
│       └── cloudinary_service.dart # uploadFile() genérico
│
├── features/
│   ├── auth/
│   │   ├── controllers/auth_controller.dart
│   │   └── screens/
│   │       ├── phone_input_screen.dart
│   │       └── otp_verify_screen.dart
│   ├── board/
│   │   ├── controllers/board_controller.dart
│   │   └── screens/academic_board_screen.dart
│   ├── calls/
│   │   ├── controllers/calls_controller.dart
│   │   └── screens/
│   │       ├── call_screen.dart
│   │       └── incoming_call_screen.dart
│   ├── chat/
│   │   ├── controllers/chat_controller.dart
│   │   └── screens/chat_screen.dart
│   ├── contacts/
│   │   ├── controllers/contacts_controller.dart
│   │   └── screens/
│   │       ├── contacts_list_screen.dart
│   │       └── add_contact_screen.dart
│   ├── conversations/
│   │   ├── controllers/conversations_controller.dart
│   │   └── screens/conversations_screen.dart
│   ├── groups/
│   │   ├── controllers/groups_controller.dart
│   │   └── screens/
│   │       ├── create_group_screen.dart
│   │       └── group_detail_screen.dart
│   ├── profile/
│   │   ├── controllers/profile_controller.dart
│   │   └── screens/
│   │       ├── profile_setup_screen.dart
│   │       └── profile_edit_screen.dart
│   └── stories/
│       ├── controllers/stories_controller.dart
│       ├── screens/
│       │   ├── add_story_screen.dart
│       │   └── story_view_screen.dart
│       └── widgets/stories_bar.dart
│
├── firebase_options.dart
└── main.dart                       # Inicialización + _IncomingCallListener
```

---

## Diseño

El sistema de diseño sigue una paleta **monocromática institucional**:

| Token | Valor hex | Uso principal |
|---|---|---|
| `primary` | `#0B0B0B` | Botones, AppBar, burbujas enviadas |
| `navy` | `#1A2540` | Botón «Publicar» del tablón (acento docente) |
| `surface` | `#FFFFFF` | Fondo de tarjetas, sheets |
| `surfaceAlt` | `#F5F5F5` | Fondos secundarios, chips de archivo |
| `background` | `#F8F8F8` | Fondo general de pantallas |
| `hairline` | `#E0E0E0` | Bordes y divisores |
| `bubbleSent` | `#0B0B0B` | Burbuja del emisor |
| `bubbleReceived` | `#FFFFFF` + borde hairline | Burbuja del receptor |
| `textPrimary` | `#0B0B0B` | Texto principal |
| `textSecondary` | `#6B7280` | Subtítulos, metadatos |
| `textFaint` | `#9CA3AF` | Marcas de tiempo, contadores |

---

## Flujo de autenticación

```
Inicio de app
  └─ ¿currentUser != null?
       ├─ No  ──→ /auth/phone ──→ /auth/otp ──→ ...
       └─ Sí  ──→ ¿documento en users/{uid}?
                    ├─ No  ──→ /auth/profile-setup ──→ /home
                    └─ Sí  ──→ /home
```

La redirección está implementada con `GoRouter.redirect` + `_AuthNotifier` (ChangeNotifier que escucha `FirebaseAuth.authStateChanges()`).

---

## Colecciones Firestore

### `users/{uid}`
```json
{
  "uid": "string",
  "displayName": "string",
  "phone": "string",
  "role": "student | professor",
  "career": "string",
  "avatarUrl": "string | null",
  "createdAt": "Timestamp"
}
```

### `conversations/{id}`
```json
{
  "participants":     ["uid1", "uid2"],
  "isGroup":          false,
  "groupName":        "string | null",
  "groupAvatarUrl":   "string | null",
  "adminUid":         "string | null",
  "hidePhoneNumbers": false,
  "lastMessage":      "string | null",
  "lastMessageAt":    "Timestamp | null"
}
```

### `conversations/{id}/messages/{msgId}`
```json
{
  "senderUid": "string",
  "content":   "string",
  "type":      "text | image | video | emoji | file",
  "mediaUrl":  "string | null",
  "readBy":    ["uid1"],
  "createdAt": "Timestamp"
}
```

### `board_posts/{id}`
```json
{
  "authorUid":        "string",
  "authorName":       "string",
  "groupId":          "string | null",
  "title":            "string",
  "body":             "string",
  "type":             "tarea | aviso | examen | material",
  "deadline":         "Timestamp | null",
  "readBy":           ["uid1"],
  "totalParticipants": 0,
  "fileUrl":          "string | null",
  "fileName":         "string | null",
  "createdAt":        "Timestamp"
}
```

### `calls/{id}`
```json
{
  "callerUid":   "string",
  "receiverUid": "string",
  "channelName": "string (UUID v4)",
  "status":      "calling | ongoing | ended",
  "createdAt":   "Timestamp"
}
```

### `stories/{id}`
```json
{
  "authorUid": "string",
  "mediaUrl":  "string",
  "type":      "image | video",
  "seenBy":    ["uid1"],
  "createdAt": "Timestamp",
  "expiresAt": "Timestamp (createdAt + 24 h)"
}
```

---

## Reglas de seguridad

| Colección | Leer | Crear | Actualizar | Eliminar |
|---|---|---|---|---|
| `users` | Autenticado | Propio documento | Propio documento | ✗ |
| `conversations` | Participante | Autenticado | Participante | ✗ |
| `messages` | Participante de la conv. | Participante | Solo campo `readBy` | ✗ |
| `board_posts` | Autenticado | Solo docentes | Autor **o** solo campo `readBy` | Autor |
| `calls` | Caller o receiver | Autenticado | Caller o receiver | ✗ |
| `stories` | Autenticado | Autenticado | Solo campo `seenBy` | Autor |

Las reglas utilizan helpers como `isAuthenticated()`, `isProfessor()` e `isAuthor()` para mantener el código DRY.

---

## Sistema de roles

| Rol | Valor Firestore | Capacidades exclusivas |
|---|---|---|
| **Docente** | `professor` | Crear grupos, publicar en el tablón, agregar miembros a grupos |
| **Alumno** | `student` | Ver tablón, enviar mensajes, iniciar videollamadas |

El rol se asigna en el setup de perfil y se valida **en el backend (Firestore rules)**, por lo que el cliente no puede escalarlo.

---

## Instalación y configuración

### Requisitos previos

- Flutter SDK ≥ 3.10.7 (`flutter --version`)
- Java 17+ — Android Studio incluye JBR 21 (ya configurado en `gradle.properties`)
- Android Studio o VS Code con extensión Flutter/Dart
- Cuenta en [Firebase](https://firebase.google.com) con proyecto configurado
- Cuenta en [Cloudinary](https://cloudinary.com) con preset **Unsigned** que acepte raw (PDFs)
- Cuenta en [Agora](https://console.agora.io) con proyecto en **Testing Mode** (sin token)

### Pasos

1. **Clonar el repositorio**
   ```bash
   git clone <url-del-repositorio>
   cd tecnm_chat
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase**
   - Coloca `google-services.json` en `android/app/`
   - Regenera `lib/firebase_options.dart` con FlutterFire CLI si usas tu propio proyecto:
     ```bash
     flutterfire configure
     ```

4. **Configurar Agora y Cloudinary** (`lib/core/constants/app_constants.dart`)
   ```dart
   static const String agoraAppId          = '<tu-app-id>';
   static const String cloudinaryCloudName  = '<tu-cloud-name>';
   static const String cloudinaryUploadPreset = '<tu-upload-preset>';
   ```

5. **Desplegar reglas e índices de Firestore**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

6. **Ejecutar en dispositivo**
   ```bash
   flutter run
   ```

> **Nota Java:** si tu sistema tiene Java < 17, `android/gradle.properties` ya apunta al JBR de Android Studio mediante `org.gradle.java.home`. Verifica que la ruta coincida con tu instalación.

---

## Compilar APK

```bash
# Debug — para pruebas internas
flutter build apk --debug
# Salida: build/app/outputs/flutter-apk/app-debug.apk

# Release — para distribución
flutter build apk --release
# Salida: build/app/outputs/flutter-apk/app-release.apk

# Instalar directamente en el dispositivo conectado
flutter run --release
```

---

## Usuarios de prueba

Para agregar teléfonos de prueba sin SMS reales:
**Firebase Console → Authentication → Sign-in method → Números de teléfono para pruebas**

Firebase permite hasta **10 números de prueba** simultáneos.

| Nombre | Teléfono | Código OTP | Rol |
|---|---|---|---|
| Clara (docente) | +52 461 250 2504 | `123456` | `professor` |
| Alumno 1 | +52 461 234 4567 | `123456` | `student` |
| Alumno 2 | +52 461 234 4568 | `123456` | `student` |

Cada número debe pasar por el flujo OTP al menos una vez para que Firebase Auth lo registre como usuario. Luego se crea el documento en `users/{uid}` automáticamente al completar el setup de perfil.

---

## Demo: flujo ideal

### 1. Autenticación
- Ingresar número de teléfono con código +52.
- Recibir código OTP → ingresar → completar perfil (nombre, carrera, rol, foto).

### 2. Chat directo
- Contactos → buscar número → agregar → abrir conversación.
- Enviar texto, emoji, imagen de galería, y PDF.
- Observar el indicador «Escribiendo…» en el otro dispositivo.
- Verificar la doble paloma cuando el receptor abre el mensaje.

### 3. Videollamada
- Desde el AppBar del chat directo → ícono de cámara.
- En el receptor: aparece `IncomingCallScreen` → Aceptar.
- Ambos dispositivos transmiten video y audio bidireccional.
- Colgar desde cualquiera de los dos finaliza la sesión en ambos.

### 4. Grupo académico
- Como **docente**: Conversaciones → «+» → Nuevo grupo → seleccionar alumnos → crear.
- Dentro del grupo: enviar mensajes; tocar ⓘ en el AppBar para ver el detalle.
- En el detalle: lista de miembros, cuadrícula multimedia, botón «Agregar miembros».

### 5. Tablón académico
- Tab «Tablón» en Conversaciones → botón «Publicar» (solo visible para docentes).
- Seleccionar tipo (Tarea / Aviso / Examen / Material), llenar título, contenido.
- Opcionalmente: agregar fecha límite y adjuntar un archivo PDF o Word.
- Los alumnos ven el chip de adjunto y pueden abrirlo con el visor externo.

### 6. Historias
- Tocar el avatar propio en la barra superior → seleccionar imagen o video.
- Los demás ven el anillo de color en el avatar; tocar reproduce la historia a pantalla completa.

---

## Mejoras futuras

- [ ] **Notificaciones push** — FCM para mensajes y llamadas con la app en segundo plano
- [ ] **Token de Agora** — generación de tokens mediante Cloud Functions para producción
- [ ] **Cloud Function** — actualizar `totalParticipants` en `board_posts` automáticamente
- [ ] **Llamadas grupales** — extender Agora a canales con más de 2 participantes
- [ ] **Firma y distribución** — keystore de release + Firebase App Distribution
- [ ] **Reacciones a mensajes** — emojis de reacción en burbujas de chat

---

## Desarrollado con

- [Flutter](https://flutter.dev) — framework de UI multiplataforma
- [Firebase](https://firebase.google.com) — Auth, Firestore, Messaging
- [Agora](https://www.agora.io) — videollamadas en tiempo real
- [Cloudinary](https://cloudinary.com) — almacenamiento y entrega de medios
- [Riverpod](https://riverpod.dev) — gestión de estado reactiva

---

*Proyecto académico desarrollado para el TecNM Celaya — uso institucional interno.*
