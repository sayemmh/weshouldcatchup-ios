# We Should Catch Up

A native iOS app that enables spontaneous voice conversations between people who've mutually agreed they want to catch up. Instead of scheduling calls, you tap "I'm Free" when you have a spare moment, and the app finds someone in your queue who's also available.

Voice only. 1-on-1. No scheduling. No calendar invites.

## Project Structure

```
WeShouldCatchUp/
├── WeShouldCatchUp/          # iOS app (Swift / SwiftUI)
│   ├── App/                  # App entry point, AppDelegate
│   ├── Models/               # Data models (User, CatchUp, Call, QueueItem)
│   ├── Views/                # SwiftUI views
│   │   ├── Onboarding/       # Phone auth, notifications, display name
│   │   ├── Main/             # Queue list + "I'm Free" button
│   │   ├── Live/             # Waiting screen, incoming ping
│   │   ├── Call/             # Voice call UI, call ended
│   │   ├── Invite/           # Send/accept catch-up invites
│   │   └── History/          # Past calls
│   ├── ViewModels/           # Auth, Queue, Live, Call view models
│   ├── Services/             # Auth, API, Agora, Push, DeepLink
│   └── Utilities/            # Constants, Extensions
│
└── backend/                  # Node.js / Fastify backend
    └── src/
        ├── routes/           # API endpoints
        ├── services/         # Rotation engine, Agora tokens, push, Firestore
        ├── middleware/        # Firebase auth verification
        └── types/            # TypeScript type definitions
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS App | Swift / SwiftUI (iOS 16+) |
| Voice/RTC | Agora Voice SDK |
| Push Notifications | APNs via Firebase Cloud Messaging |
| Auth | Firebase Auth (phone number) |
| Database | Firestore |
| Backend | Node.js (Fastify) on Google Cloud Run |
| Deep Links | Universal Links |

## How It Works

1. **Send a catch-up link** to a friend via text, DM, wherever
2. **Tap "I'm Free"** when you have a spare moment (walking the dog, doing dishes, in the car)
3. **The app pings your queue** one person at a time, starting with whoever you haven't talked to in the longest time
4. **If someone responds**, you're connected for a voice call right in the app
5. **If nobody's around**, you stay live for 10 minutes in case someone pops in

---

## Setup — What You Need To Do Next

### 1. Create the Xcode Project

The Swift source files are scaffolded, but you need to create the actual Xcode project to tie them together:

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - Product Name: `WeShouldCatchUp`
   - Team: Your Apple Developer account
   - Organization Identifier: `com.yourname` (e.g., `com.sayem`)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
4. Save it inside the `WeShouldCatchUp/` directory (at the same level as the existing `WeShouldCatchUp/` folder with the Swift files)
5. **Delete the auto-generated** `ContentView.swift` and `WeShouldCatchUpApp.swift` that Xcode creates
6. **Drag all the existing folders** (`App/`, `Models/`, `Views/`, `ViewModels/`, `Services/`, `Utilities/`) into the Xcode project navigator
7. Make sure "Copy items if needed" is **unchecked** (they're already in the right place)

### 2. Set Up Firebase

1. Go to [Firebase Console](https://console.firebase.google.com) → Create a new project
2. Add an **iOS app** with your bundle identifier
3. Download `GoogleService-Info.plist` and add it to your Xcode project
4. Enable **Phone Authentication** in Firebase Console → Authentication → Sign-in method
5. Create a **Firestore database** (production mode)
6. Enable **Cloud Messaging** for push notifications
7. Deploy the Firestore security rules from the spec

### 3. Add iOS Dependencies (Swift Package Manager)

In Xcode → File → Add Package Dependencies:

- **Firebase iOS SDK**: `https://github.com/firebase/firebase-ios-sdk`
  - Select: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseMessaging`
- **Agora RTC Engine**: `https://github.com/AgoraIO/AgoraRtcEngine_iOS`
  - Select: `RtcBasic` (voice only, no video)

### 4. Set Up Agora

1. Create an account at [Agora Console](https://console.agora.io)
2. Create a new project and enable **App Certificate**
3. Copy the App ID and App Certificate
4. Add the App ID to `Utilities/Constants.swift` → `agoraAppID`
5. Add both to the backend `.env` file

### 5. Configure Push Notifications

1. In your Apple Developer account, create an **APNs Key** (or certificate)
2. Upload the APNs key to Firebase Console → Project Settings → Cloud Messaging
3. In Xcode, add the **Push Notifications** capability to your target
4. Add the **Background Modes** capability and check **Remote notifications** and **Voice over IP**

### 6. Set Up the Backend

```bash
cd backend
cp .env.example .env
# Fill in your Agora and Firebase credentials in .env

npm install
npm run dev    # Starts dev server on port 8080
```

### 7. Configure Universal Links (Deep Links)

1. Add the **Associated Domains** capability in Xcode: `applinks:weshouldcatchup.app`
2. Host an `apple-app-site-association` file on your domain
3. Update `Constants.swift` with your actual domain

### 8. Update Backend URL

Once your backend is deployed (or running locally), update `Constants.swift`:

```swift
static let backendBaseURL = "https://your-cloud-run-url.run.app"
```

For local development, use your machine's IP: `http://192.168.x.x:8080`

---

## Backend Deployment (Google Cloud Run)

```bash
cd backend

# Build and deploy
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/we-should-catch-up-backend
gcloud run deploy we-should-catch-up-backend \
  --image gcr.io/YOUR_PROJECT_ID/we-should-catch-up-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "AGORA_APP_ID=xxx,AGORA_APP_CERTIFICATE=xxx,FIREBASE_PROJECT_ID=xxx"
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/go-live` | Set status to live, start rotation |
| POST | `/cancel-live` | Cancel live status |
| POST | `/accept-ping` | Accept a catch-up ping, get Agora tokens |
| POST | `/end-call` | End a call, update stats |
| POST | `/create-catchup` | Create invite link |
| POST | `/accept-catchup` | Accept an invite |
| POST | `/remove-catchup` | Remove from queue |
| GET | `/my-queue` | Get catch-up queue |
| GET | `/call-history` | Get past calls |
| GET | `/health` | Health check |

All endpoints except `/health` require a Firebase Auth token in the `Authorization: Bearer <token>` header.

## Design System

### Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#B5695A` | Muted terracotta — buttons, accents, brand color |
| `primaryDark` | `#96524A` | Pressed/hover states |
| `primaryLight` | `#F0DDD7` | Light terracotta tint (badges, highlights) |
| `background` | `#FBF7F4` | Cream — main screen background |
| `backgroundDark` | `#F5EDE8` | Slightly darker cream for depth |
| `cardBackground` | `#FFFFFF` | Cards, input fields |
| `textPrimary` | `#2D2926` | Warm charcoal — headings, body text |
| `textSecondary` | `#6B6560` | Muted — secondary labels, subtitles |
| `textTertiary` | `#9A9490` | Warm light — placeholders, icons |
| `border` | `#E8E0DA` | Input borders, dividers |
| `destructive` | `#FB2C36` | Errors, delete actions |
| `success` | `rgb(77,179,115)` | Success states |
| `callBackground` | `#2D2926` | Dark background for voice call screen |

### Typography

| Style | Font | Usage |
|-------|------|-------|
| Display / Headings | **Fraunces** (serif) | Screen titles, hero text |
| Body / UI | **Inter** (sans-serif) | Buttons, labels, body copy |

### Contrast Rules

> **Never put light text on a light background.**

- **White text** (`.white`) is only allowed on dark or primary-colored backgrounds (`primary`, `primaryDark`, `callBackground`).
- Disabled/loading buttons use `primary.opacity(0.4–0.5)` — **not** `Color.gray.opacity(0.3)` — so white text stays readable.
- On cream/white backgrounds, use `textPrimary`, `textSecondary`, or `textTertiary` for text.
- `textTertiary` (`#9A9490`) is the lightest text allowed on light backgrounds — use only for placeholders and icons.

### Layout

| Token | Value |
|-------|-------|
| Horizontal padding | 24pt |
| Section spacing | 32pt |
| Corner radius | 12pt (cards), 8pt (small), 28pt (pill buttons) |
| Button height | 56pt |
| "I'm Free" button | 160pt circle |

## Key Design Decisions

- **Sequential pinging, not broadcast**: When you go live, the app pings one person at a time (60s timeout each), starting with whoever you haven't talked to in the longest time. No group blasts.
- **Voice only**: No video, no text, no feed. Voice fits the use case — you're catching up while doing something else.
- **Zero-pressure notifications**: If you get pinged and you're busy, just ignore it. It quietly moves on to the next person. No missed call guilt.
- **10-minute live window**: After the queue is exhausted, you stay "live" for 10 minutes in case someone from your queue opens the app.

## Out of Scope (v1)

Video calls, text chat, group calls, Android, contact book sync, availability scheduling, read receipts, payments, social profiles.
