# ITC Conecta

Aplicación de mensajería institucional para el **Tecnológico Nacional de México en Celaya (TecNM Celaya)**, desarrollada con Flutter y Firebase. Permite la comunicación en tiempo real entre alumnos y docentes con videollamadas P2P, tablón académico, historias efímeras y gestión de grupos.

---

## Índice

1. [Cumplimiento de requerimientos de la práctica](#cumplimiento-de-requerimientos-de-la-práctica)
2. [Características](#características)
3. [Stack tecnológico](#stack-tecnológico)
4. [Estructura del proyecto](#estructura-del-proyecto)
5. [Diseño](#diseño)
6. [Flujo de autenticación](#flujo-de-autenticación)
7. [Colecciones Firestore](#colecciones-firestore)
8. [Reglas de seguridad](#reglas-de-seguridad)
9. [Sistema de roles](#sistema-de-roles)
10. [Instalación y configuración](#instalación-y-configuración)
11. [Compilar APK](#compilar-apk)
12. [Usuarios de prueba](#usuarios-de-prueba)
13. [Demo: flujo ideal](#demo-flujo-ideal)

---

## Cumplimiento de requerimientos de la práctica

A continuación se describe cómo cada punto solicitado en la práctica fue cubierto dentro de la aplicación.

---

### 1. Interfaz para ver, escribir y enviar mensajes entre alumnos y profesores

Se implementó un módulo completo de mensajería en tiempo real sobre **Cloud Firestore**. Cada conversación es un documento en la colección `conversations` con una subcolección `messages`. Los mensajes se actualizan en la pantalla al instante mediante `StreamProvider` de Riverpod.

**Archivos clave:**
- [lib/features/chat/screens/chat_screen.dart](lib/features/chat/screens/chat_screen.dart)
- [lib/features/chat/controllers/chat_controller.dart](lib/features/chat/controllers/chat_controller.dart)

**Extras implementados sobre el requisito base:**
- Indicador de «Escribiendo…» en tiempo real mediante el mapa `typingUsers` en el documento de conversación.
- Confirmación de lectura con doble paloma (✓✓) al abrir el mensaje.
- Soporte de múltiples tipos de contenido: texto, imagen, video, emoji, PDF.

---

### 2. Pantalla de registro con número de teléfono y autenticación de dos pasos (Firebase)

La autenticación utiliza **Firebase Phone Auth** que envía un SMS con un código OTP de 6 dígitos al número registrado, cumpliendo el requisito de autenticación de dos pasos: primero el número (algo que el usuario sabe) y luego el código recibido vía SMS (algo que el usuario posee).

**Flujo:**
1. `PhoneInputScreen` — el usuario ingresa su número con prefijo +52.
2. Firebase envía el SMS y devuelve un `verificationId`.
3. `OtpVerifyScreen` — el usuario ingresa el código de 6 dígitos.
4. Firebase valida el código y crea/recupera la sesión de usuario.

**Archivos clave:**
- [lib/features/auth/screens/phone_input_screen.dart](lib/features/auth/screens/phone_input_screen.dart)
- [lib/features/auth/screens/otp_verify_screen.dart](lib/features/auth/screens/otp_verify_screen.dart)
- [lib/features/auth/controllers/auth_controller.dart](lib/features/auth/controllers/auth_controller.dart)

---

### 3. Pantalla de perfil con avatar, correo institucional y datos adicionales

Al completar el registro por primera vez, el usuario pasa por `ProfileSetupScreen` donde configura su perfil. Los datos almacenados en Firestore (`users/{uid}`) son:

| Campo | Descripción |
|---|---|
| `displayName` | Nombre completo del usuario |
| `phone` | Número de teléfono registrado |
| `role` | Rol institucional: `student` o `professor` |
| `career` | Carrera (10 opciones del TecNM Celaya) |
| `avatarUrl` | URL de la foto de perfil subida a Cloudinary |
| `createdAt` | Fecha de registro |

La foto de perfil se selecciona desde galería o cámara y se sube a Cloudinary antes de guardar el documento.

**Archivos clave:**
- [lib/features/profile/screens/profile_setup_screen.dart](lib/features/profile/screens/profile_setup_screen.dart)
- [lib/features/profile/screens/profile_edit_screen.dart](lib/features/profile/screens/profile_edit_screen.dart)
- [lib/features/profile/controllers/profile_controller.dart](lib/features/profile/controllers/profile_controller.dart)

---

### 4. Agregar contactos únicamente por número de teléfono

Un usuario puede agregar contactos mediante `AddContactScreen`, ingresando el número de teléfono de otro usuario registrado en la app. El controlador realiza una consulta a Firestore buscando el documento en `users` cuyo campo `phone` coincida; si existe, lo agrega a la subcolección `contacts` del usuario actual.

Solo se pueden agregar usuarios que ya estén registrados en la plataforma, garantizando que todos los contactos sean miembros institucionales.

**Archivos clave:**
- [lib/features/contacts/screens/add_contact_screen.dart](lib/features/contacts/screens/add_contact_screen.dart)
- [lib/features/contacts/controllers/contacts_controller.dart](lib/features/contacts/controllers/contacts_controller.dart)

---

### 5. El profesor puede crear grupos y ocultar los números de los integrantes

La creación de grupos está restringida exclusivamente a usuarios con `role == 'professor'`, validado tanto en la app como en las reglas de Firestore. Durante la creación, el docente dispone de un toggle **«Ocultar números de teléfono»** que, al activarse, establece `hidePhoneNumbers: true` en el documento de la conversación.

Cuando este campo está activo, la pantalla de detalle del grupo (`GroupDetailScreen`) omite el número de teléfono de cada miembro en la lista, mostrando únicamente nombre, carrera y rol.

**Archivos clave:**
- [lib/features/groups/screens/create_group_screen.dart](lib/features/groups/screens/create_group_screen.dart)
- [lib/features/groups/screens/group_detail_screen.dart](lib/features/groups/screens/group_detail_screen.dart)
- [lib/features/groups/controllers/groups_controller.dart](lib/features/groups/controllers/groups_controller.dart)

---

### 6. Pantalla con lista de conversaciones más recientes

`ConversationsScreen` es la pantalla principal de la app. Muestra todas las conversaciones del usuario ordenadas por `lastMessageAt` de forma descendente, incluyendo:

- Avatar del contacto o del grupo.
- Nombre del contacto o nombre del grupo.
- Vista previa del último mensaje.
- Marca de tiempo relativa.
- Badge con el conteo de mensajes no leídos.

Además cuenta con **cuatro tabs de filtro**: Todos, No leídos, Grupos y Tablón (con badge de publicaciones nuevas).

**Archivos clave:**
- [lib/features/conversations/screens/conversations_screen.dart](lib/features/conversations/screens/conversations_screen.dart)
- [lib/features/conversations/controllers/conversations_controller.dart](lib/features/conversations/controllers/conversations_controller.dart)

---

### 7. Al seleccionar una conversación se muestra su detalle

Al tocar cualquier conversación de la lista, `go_router` navega a `/chat/:id`, cargando `ChatScreen` con el historial completo de mensajes en orden cronológico. La pantalla incluye:

- AppBar con nombre del contacto/grupo y estado de «Escribiendo…».
- Historial de mensajes paginado por Firestore en tiempo real.
- Campo de texto, selector de emoji y menú de adjuntos.
- Para grupos: botón ⓘ que abre `GroupDetailScreen` (miembros, multimedia).
- Para chats directos: botón de videollamada.

**Archivos clave:**
- [lib/features/chat/screens/chat_screen.dart](lib/features/chat/screens/chat_screen.dart)
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart)

---

### 8. Envío de fotos, videos, animaciones y emoticonos en conversaciones

El chat soporta los siguientes tipos de contenido multimedia, cada uno con su propio widget de burbuja:

| Tipo | Cómo se envía | Cómo se muestra |
|---|---|---|
| **Texto** | Campo de texto | Burbuja de texto |
| **Emoji / animación** | Selector de emojis integrado (`emoji_picker_flutter`) | Emoji a tamaño 40 px sin burbuja |
| **Imagen** | Galería o cámara (`image_picker`) → sube a Cloudinary | `CachedNetworkImage` dentro de burbuja |
| **Video** | Galería (`image_picker`) → sube a Cloudinary | Reproductor inline con control play/pausa |
| **PDF / archivo** | `file_picker` → sube a Cloudinary | Chip con ícono PDF y botón «Toca para abrir» |

Los archivos multimedia se comprimen antes de subir (`flutter_image_compress`) y se sirven vía CDN de Cloudinary.

**Archivos clave:**
- [lib/features/chat/screens/chat_screen.dart](lib/features/chat/screens/chat_screen.dart)
- [lib/features/chat/controllers/chat_controller.dart](lib/features/chat/controllers/chat_controller.dart)
- [lib/data/repositories/cloudinary_service.dart](lib/data/repositories/cloudinary_service.dart)

---

### 9. Realizar videollamadas a contactos registrados

Las videollamadas P2P se implementaron con **Agora RTC Engine 6.x**. El flujo completo es:

1. El emisor toca el ícono de cámara en el AppBar del chat → `CallScreen` crea un documento en `calls/{id}` con `status: 'calling'` y un `channelName` único (UUID v4).
2. El receptor es notificado por `incomingCallProvider` (StreamProvider que escucha llamadas entrantes en Firestore) y ve `IncomingCallScreen`.
3. Al aceptar, el receptor ejecuta `joinCall()` y navega a `CallScreen` con `isReceiver: true` (para no re-iniciar la llamada).
4. Ambos dispositivos solicitan permisos de CÁMARA y MICRÓFONO en runtime (`permission_handler`) antes de inicializar el motor Agora.
5. Cuando cualquiera cuelga, Firestore actualiza `status: 'ended'` y ambos dispositivos cierran la pantalla mediante un `StreamSubscription`.

**Archivos clave:**
- [lib/features/calls/controllers/calls_controller.dart](lib/features/calls/controllers/calls_controller.dart)
- [lib/features/calls/screens/call_screen.dart](lib/features/calls/screens/call_screen.dart)
- [lib/features/calls/screens/incoming_call_screen.dart](lib/features/calls/screens/incoming_call_screen.dart)
- [lib/main.dart](lib/main.dart) — `_IncomingCallListener` global

---

### 10. Funcionalidad adicional a consideración del estudiante — Tablón Académico *(5 pts)*

Se implementó un **Tablón Académico** como canal de comunicación unidireccional del docente hacia los alumnos, cubriendo una necesidad real del entorno institucional del TecNM Celaya.

**Funcionalidades:**

- **Tipos de publicación:** Tarea, Aviso, Examen y Material, cada uno con color y etiqueta distintivos.
- **Fecha límite opcional:** el docente puede fijar una fecha y hora de entrega que se muestra en la tarjeta de la publicación.
- **Archivo adjunto:** soporte para PDF, Word, PowerPoint y Excel. El archivo se sube a Cloudinary y los alumnos pueden abrirlo directamente desde la app con su aplicación preferida.
- **Control de lectura:** cada publicación registra qué usuarios la han visto (`readBy`) y muestra el contador «Leído por X/N». El badge del tab «Tablón» en la pantalla de conversaciones indica cuántas publicaciones nuevas hay.
- **Filtros:** los alumnos pueden filtrar las publicaciones por tipo desde la barra de chips horizontal.
- **Seguridad:** las reglas de Firestore impiden que un alumno cree o elimine publicaciones; solo puede marcar como leído (`readBy`).

**Archivos clave:**
- [lib/features/board/screens/academic_board_screen.dart](lib/features/board/screens/academic_board_screen.dart)
- [lib/features/board/controllers/board_controller.dart](lib/features/board/controllers/board_controller.dart)
- [lib/data/models/board_post_model.dart](lib/data/models/board_post_model.dart)
- [firestore.rules](firestore.rules)

---

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

## Desarrollado con

- [Flutter](https://flutter.dev) — framework de UI multiplataforma
- [Firebase](https://firebase.google.com) — Auth, Firestore, Messaging
- [Agora](https://www.agora.io) — videollamadas en tiempo real
- [Cloudinary](https://cloudinary.com) — almacenamiento y entrega de medios
- [Riverpod](https://riverpod.dev) — gestión de estado reactiva

---

*Proyecto académico desarrollado para el TecNM Celaya — uso institucional interno.*
