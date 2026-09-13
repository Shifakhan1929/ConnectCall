# ConnectCall – 1-to-1 Audio & Video Calling App

ConnectCall is a 1-to-1 audio and video calling mobile application built with Flutter, Firebase, and the Agora RTC Engine. It provides complete communication capabilities including secure user authentication, real-time presence, searchable contacts, incoming call signaling, high-definition voice and video calls, call history, device permission management, and resilient error handling.

---

## Table of Contents
1. [Project Title](#1-project-title)
2. [Project Overview](#2-project-overview)
3. [Features](#3-features)
4. [Technology Stack](#4-technology-stack)
5. [Architecture](#5-architecture)
6. [Architecture & Data Flow](#6-architecture--data-flow)
7. [Why Agora?](#7-why-agora)
8. [Permissions](#8-permissions)
9. [Error Handling](#9-error-handling)
10. [Setup Instructions](#10-setup-instructions)
11. [Important Security Note](#11-important-security-note)
12. [Testing](#12-testing)
13. [Known Limitations](#13-known-limitations)
14. [AI Tools Used](#14-ai-tools-used)

---

## 1. Project Title
**ConnectCall – 1-to-1 Audio & Video Calling App**

---

## 2. Project Overview

ConnectCall enables two users to discover each other, verify online availability, and engage in high-quality 1-to-1 audio and video calls.

In real-world applications, robust real-time communication requires a clean separation of concerns:
- **Signaling, presence, and persistence** are handled asynchronously via cloud database state management.
- **Ultra-low latency audio/video streaming** is handled directly via dedicated real-time media network pipelines.

ConnectCall bridges these domains using Cloud Firestore for signaling and Agora RTC for high-performance voice and video streams.

---

## 3. Features

- **Firebase Authentication**: Email and password user registration, login, and secure session persistence.
- **User Registration, Login & Logout**: Streamlined onboarding with profile initialization in Firestore and clean logout state reset.
- **User Contacts & Search**: Real-time directory of registered users with instant filtering by name or email.
- **Online/Offline Status**: Real-time presence indicators reflecting live user availability.
- **1-to-1 Audio Calling**: High-definition, low-latency two-way voice communication with acoustic echo cancellation.
- **1-to-1 Video Calling**: Full-screen remote video rendering accompanied by a floating local camera preview.
- **Incoming Calls**: Real-time Firestore stream listeners that trigger incoming call alerts on the recipient's device.
- **Accept / Reject**: Immediate call acceptance with channel join or call rejection with state updates for both participants.
- **Mic Mute / Unmute**: Instant toggle to silence local microphone without dropping the call.
- **Speaker Control**: In-call hardware audio routing between earpiece and speakerphone.
- **Camera ON / OFF**: Quick camera toggle that mutes video publishing and displays a placeholder while keeping audio intact.
- **Front / Rear Camera Switch**: Instant flip between front-facing and rear-facing camera sensors.
- **Call Duration**: Real-time on-screen call timer (`mm:ss`) tracking connected duration.
- **Call History**: Automatic logging of completed, rejected, and missed calls with timestamps, duration, and direction.
- **Search & Filter Call History**: Dynamic search bar by contact name along with category filter chips (**All**, **Audio**, **Video**).
- **Permission Handling**: Clean pre-call checks for microphone and camera with actionable guidance when access is denied or permanently blocked.
- **Error Handling**: Comprehensive guards against network dropouts, Agora connection failures, duplicate taps, and premature disconnects.

---

## 4. Technology Stack

- **Flutter / Dart**: Cross-platform UI toolkit and language (Flutter SDK `^3.10.4+`, Dart 3)
- **Firebase Authentication**: Secure user identity, credential verification, and session management (`firebase_auth: ^6.6.1`)
- **Cloud Firestore**: Real-time NoSQL cloud database for user presence, call signaling, and call history (`cloud_firestore: ^6.9.0`)
- **Agora RTC Engine**: Global Software-Defined Real-time Network (SD-RTN) for sub-second voice and video transmission (`agora_rtc_engine: ^6.6.4`)
- **permission_handler**: Android and iOS device runtime hardware permission management (`permission_handler: ^11.3.1`)

---

## 5. Architecture

ConnectCall is organized into modular layers following clean code and service-oriented design:

```
lib/
├── core/
│   ├── constants/       # AgoraConstants (App ID, testing tokens, channel name)
│   ├── theme/           # AppTheme (Dark & light theme tokens, color palettes)
│   └── utils/           # PermissionHelper, NetworkHelper
├── models/              # CallModel, UserModel
├── screens/
│   ├── auth/            # LoginScreen, RegisterScreen
│   ├── call/            # AudioCallingScreen, VideoCallingScreen, IncomingCallScreen
│   ├── contacts/        # ContactsScreen
│   ├── history/         # CallHistoryScreen
│   ├── home/            # HomeScreen, HomeFeedView
│   └── profile/         # ProfileScreen
├── services/            # AuthService, UserService, CallingService,
│                        # CallSignalingService, CallHistoryService
└── widgets/             # CallButton, UserTile, shared components
```

### Component Breakdown
- **Models**: Strongly-typed data models (`UserModel`, `CallModel`) with Firestore serialization (`toMap()`, `fromMap()`) and copy utilities.
- **Screens**: Presentation widgets managing screen lifecycle, user interactions, and UI updates.
- **Services**:
  - `AuthService`: Manages Firebase user registration, login, and authentication state stream.
  - `UserService`: Manages Firestore `/users` records, profile updates, and online/offline status.
  - `CallingService`: Encapsulates the Agora RTC Engine lifecycle, channel join/leave, camera flipping, mic mute, speaker toggle, and media event callbacks.
  - `CallSignalingService`: Creates and manages `/calls` documents in Firestore (`calling`, `connected`, `rejected`, `ended`, `missed`).
  - `CallHistoryService`: Provides client-side sorted streams and queries for the user's call logs.
- **Core Utilities & Constants**:
  - `AgoraConstants`: Centralized configuration for Agora App ID, channel identifiers, and token assignments.
  - `PermissionHelper`: Reusable permission check workflows for microphone and camera.
  - `NetworkHelper`: Pre-call internet reachability checks.
- **Reusable Widgets**: Reusable UI components (`CallButton`, `UserTile`, custom text inputs) maintaining consistent aesthetics.

---

## 6. Architecture & Data Flow

```
1. User Authentication
   User ───► AuthService ───► Firebase Authentication (JWT / UID)

2. Call Initiation & Signaling
   Caller ───► CallSignalingService ───► Cloud Firestore (/calls/{callId})
                                                │
                                                ▼ (Firestore Stream)
3. Incoming Call Alert                          │
   Receiver ◄─── IncomingCallScreen ◄───────────┘
        │
        ├── Reject ───► Update status: 'rejected' ──► Caller notified & navigates back
        │
        └── Accept ───► Update status: 'connected'
                             │
                             ▼
4. Real-time Audio & Video Media
   Caller ──────┐
                ├─────► Agora RTC Engine (Channel: 'connectcall') ◄───── Receiver
   (UID 1001)   │       (Ultra-low latency audio & video streaming)      (UID 1002)
                └──────────────────────────────────────────────────────────┘
                             │
                             ▼ (Call ends or hangs up)
5. Call History Persistence
   CallingScreen ───► CallHistoryService ───► Cloud Firestore (/calls/{callId})
   (Merged single record: duration, start/end timestamps, call direction, final status)
```

1. **User -> Firebase Auth**: User logs in with email/password; Firebase Auth establishes credentials and returns a secure user ID.
2. **User/Call Signaling -> Firestore**: When initiating a call, a document is created in Firestore `/calls` with initial status `calling`.
3. **Firestore -> Incoming Call**: The recipient's active Firestore listener detects the incoming call targeting their UID and launches `IncomingCallScreen`.
4. **Agora -> Real-time Audio/Video**: Upon acceptance, both devices connect to the Agora channel (`"connectcall"`). Agora handles camera capture, encoding, transmission, decoding, and rendering.
5. **Firestore -> Call History**: When either user ends the call, the call record updates to `ended` with calculated duration. The call record is saved idempotently in Firestore and immediately visible in Call History.

---

## 7. Why Agora?

ConnectCall pairs **Cloud Firestore** with **Agora RTC** because each tool solves a distinct technical requirement:

- **Firebase Cloud Firestore**: Ideal for state signaling, user presence, metadata storage, and call logs. However, database polling or WebSockets are not designed for transmitting high-bandwidth, 60fps raw video or low-latency voice frames.
- **Agora RTC Engine**: Purpose-built for real-time audio and video over its global Software-Defined Real-time Network (SD-RTN):
  - Sub-second latency (typically <200ms globally).
  - Built-in hardware echo cancellation, background noise reduction, and automatic gain control.
  - Dynamic bandwidth estimation and video quality adaptation during packet loss or weak mobile data signals.
  - Native hardware-accelerated video rendering.

---

## 8. Permissions

ConnectCall manages device hardware permissions via `PermissionHelper` backed by `permission_handler`:

- **Audio Calls**: Requests runtime `Permission.microphone`.
- **Video Calls**: Requests both `Permission.microphone` and `Permission.camera`.
- **User Denied**: If a user declines permission, the call is blocked from starting and an informative `SnackBar` appears explaining that microphone/camera access is required to place the call.
- **Permanently Denied**: When permission has been permanently denied ("Don't ask again"), an interactive dialog alerts the user and provides a direct **"Open Settings"** action using `openAppSettings()`, allowing them to enable permissions in device settings without confusion.

---

## 9. Error Handling

ConnectCall incorporates layered defense-in-depth error handling across networking, signaling, and media layers:

- **Network Failure Check**: `NetworkHelper.hasInternetConnection()` performs a native DNS check before any call is created. If the device lacks connectivity, the call is halted immediately with user feedback.
- **Agora Engine & Join Failures**: If Agora encounters an initialization error or fails to join the channel, the screen displays a connection failure status and cleanly exits after 2 seconds rather than freezing.
- **Rejected Calls**: When the receiver taps Decline, Firestore updates status to `rejected`. The caller's screen listens to this change in real time, displays a "Call Declined" toast/status, and dismisses the call screen.
- **Disconnected / Remote User Left**: When a remote user leaves the channel or hangs up (`onUserOffline`), the local client triggers end-call procedures, frees hardware resources, and navigates back to the app home.
- **Duplicate Tap Protection**: Outgoing call buttons implement an `_isStartingCall` guard lock to prevent rapid repeated taps from dispatching duplicate call documents or corrupting the signaling state.
- **Back-Button (PopScope) Interception**: `PopScope` on calling screens prevents accidental OS back gestures from leaving orphaned Agora channels running in the background.

---

## 10. Setup Instructions

### 1. Prerequisites
- Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.4 or higher).
- Install Android Studio or VS Code with Flutter and Dart extensions.
- Ensure two physical devices (or emulators with camera and audio enabled) are available.

### 2. Clone the Repository
```bash
git clone https://github.com/Shifakhan1929/ConnectCall.git
cd ConnectCall
flutter pub get
```

### 3. Firebase Configuration
1. Create a new Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Email/Password** authentication under **Authentication > Sign-in method**.
3. Create a **Cloud Firestore** database.
4. Add your Android application:
   - Configure your package name (e.g., `com.connectcall.app`).
   - Download the generated `google-services.json` and place it at:
     ```
     android/app/google-services.json
     ```
   - Alternatively, configure using the FlutterFire CLI:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```

### 4. Agora Configuration & Development Tokens
1. Create a project in the [Agora Console](https://console.agora.io/).
2. Copy your **Agora App ID** and place it in `lib/core/constants/agora_constants.dart`:
   ```dart
   static const String defaultAppId = 'YOUR_AGORA_APP_ID';
   ```
3. Generate two temporary RTC tokens for the channel named `"connectcall"`:
   - Token 1 for **UID 1001** (Phone 1 / Caller) -> assign to `callerTestingToken`.
   - Token 2 for **UID 1002** (Phone 2 / Receiver) -> assign to `receiverTestingToken`.

### 5. Run the Application
```bash
# Run on Device 1
flutter run -d <device-1-id>

# Run on Device 2
flutter run -d <device-2-id>
```

---

## 11. Important Security Note

> [!CAUTION]
> **Agora Temporary Tokens vs. Production Architecture**:
> - The temporary tokens provided by the Agora Console are intended solely for development, prototyping, and testing (typically expiring within 24 hours).
> - **In production environments**, tokens must be generated dynamically on-demand by a secure backend server (using an Agora Token Server / TokenBuilder with user authentication).
> - **Never embed the Agora App Certificate in client-side Flutter code.** The App Certificate must reside exclusively on your secure backend server.
> - **Never commit active tokens, private keys, or sensitive credentials to a public GitHub repository.** Use environment variables, secure storage, or build flavors for credential injection.

---

## 12. Testing

ConnectCall was thoroughly validated using static code analysis, automated test suites, and physical multi-device testing:

### Static Analysis
```bash
flutter analyze
```
*Result: `No issues found!` (0 errors, 0 warnings, 0 lints).*

### Automated Unit & Widget Tests
```bash
flutter test
```
*Result: `All tests passed!` (100% passing tests for models, services, and widgets).*

### Physical Two-Device Testing
Verification was executed between two physical Android devices:
- **Audio Call Flow**: Caller dials receiver, receiver answers, two-way audio confirmed, post-join speakerphone active, mute/unmute verified, call ended cleanly.
- **Video Call Flow**: Caller dials video call, receiver accepts, remote video rendered full-screen, local preview displayed in floating box, front/rear camera flip verified, camera mute placeholder verified.
- **Signaling & Decline**: Incoming call prompt appears within 500ms; declining call updates caller status immediately.
- **History Verification**: Completed and rejected calls logged with precise durations in Cloud Firestore without duplicate records.

---

## 13. Known Limitations

1. **Temporary Agora Development Tokens**: Temporary tokens generated from the Agora Console expire after 24 hours. For extended testing beyond 24 hours, fresh tokens must be generated in the Agora Console for channel `"connectcall"` with UIDs `1001` and `1002`.
2. **Fixed UIDs for Certificate-Secured Testing**: In projects where Agora Primary Certificate is enforced, testing tokens are cryptographically bound to specific UIDs (`1001` for caller and `1002` for receiver). A production deployment avoids this by having the backend generate a token dynamically matching each authenticated user's numeric Agora UID.

---

## 14. AI Tools Used

AI-assisted coding and agentic pair-programming were utilized during the development of this project for:
- Initial project scaffolding, architecture planning, and boilerplate generation.
- Diagnostic log analysis of the Agora RTC audio pipeline and Android hardware routing.
- Crafting defensive error handling, double-tap prevention, and permission workflows.

All AI-assisted implementations were thoroughly reviewed, refactored to align with Flutter best practices, validated against static analysis (`flutter analyze`), verified through unit tests (`flutter test`), and tested on physical Android devices.
