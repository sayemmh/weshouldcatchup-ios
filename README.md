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

---

## Release Workflow

Everything release-related is scripted so no Xcode GUI clicks are needed.

### One-time dev machine setup

```bash
# SVG → PNG rendering for App Store screenshots
brew install librsvg

# GitHub CLI (only needed once, for repo creation)
brew install gh
```

**App Store Connect API key** (one-time):

1. Go to https://appstoreconnect.apple.com/access/integrations/api
2. Create an API key with **App Manager** role (or higher)
3. Download the `.p8` file (Apple only lets you download it once)
4. Place it at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`
5. Create `~/.appstoreconnect/credentials.env` with mode `600`:

   ```bash
   export ASC_KEY_ID="<your key id>"
   export ASC_ISSUER_ID="<your issuer uuid>"
   export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
   ```

   Issuer ID is at the top of the App Store Connect API page. Neither file is committed — both are `.gitignore`'d by the fact that they live outside the repo.

**Git remote** (already configured on this machine):

```
origin  git@github.com:sayemmh/weshouldcatchup-ios.git  (push + fetch)
```

### Cutting a new TestFlight build

```bash
# 1. Bump the build number (edit both Debug and Release in project.pbxproj)
#    CURRENT_PROJECT_VERSION = N+1

# 2. Commit your changes
git add -A
git commit -m "…"
git push origin main

# 3. Archive, sign, export, and upload — one command
./scripts/upload-testflight.sh
```

The script:

1. Cleans + archives in Release configuration
2. Exports a signed `.ipa` using automatic signing (fetches the distribution cert + provisioning profile from App Store Connect on demand)
3. Uploads via `xcrun altool` using the API key

Processing on Apple's side takes 5–15 min. Watch TestFlight in App Store Connect → Builds.

**Dry-run** (skip upload, just build the IPA):

```bash
./scripts/upload-testflight.sh --dry
```

### Regenerating App Store screenshots

The screenshots under `screenshots/0[1-5]_*.png` are rendered from `*.svg` mockups at 1284×2778 (the accepted 6.5" iPhone display size).

```bash
# Make sure librsvg is installed first (see setup above)

# Create the fontconfig override so rsvg-convert can find Fraunces + Inter
mkdir -p /tmp/wscu-fontconf
cat > /tmp/wscu-fontconf/fonts.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>__REPO_ROOT__/WeShouldCatchUp/Resources/Fonts</dir>
  <include ignore_missing="yes">/opt/homebrew/etc/fonts/fonts.conf</include>
  <cachedir>/tmp/wscu-fontconf/cache</cachedir>
</fontconfig>
EOF
# Replace __REPO_ROOT__ with the absolute path to your repo checkout
# e.g. /Users/sayemhoque/Documents/WeShouldCatchUp

# Render all 5 screenshots
cd screenshots
for f in 01_main_queue 02_live_searching 03_incoming_ping 04_voice_call 05_call_ended; do
  FONTCONFIG_FILE=/tmp/wscu-fontconf/fonts.conf \
    rsvg-convert -w 1284 -h 2778 "${f}.svg" -o "${f}.png"
done
```

Do **not** keep any PNGs at non-standard sizes in `screenshots/` — Apple's upload slot only accepts `1242×2688`, `2688×1242`, `1284×2778`, or `2778×1284`. Anything else gets rejected.

### Commit message conventions

Imperative mood, ~70 char subject, body explains the why. Examples from history:

```
Add 15s rotation cycles, rotation progress UI, and silent push updates
Use Fraunces serif font consistently, swap filled icons for clean outlines
Remove stale 1320x2868 screenshots, keep only App Store 6.5" size
```

No co-author trailers on commits to this repo.

---

## App Store Connect — Submission Copy

Copy-paste ready. Character counts are verified.

### Previews and Screenshots

- **6.5" Display**: drag all 5 PNGs from `screenshots/` (1284×2778). Apple uses these for every other iPhone size.
- No App Previews (video) — leave empty, not required.
- No iPad / Apple Watch — leave empty, not required.

### Promotional Text (170 char max — editable without resubmission)

```
Tap "I'm Free" and we'll find a friend who's also around to talk right now. No scheduling, no pressure — just real voice conversations when the moment is right.
```

### Description (4,000 char max)

```
We Should Catch Up is for the friends you keep meaning to call but never do.

Instead of scheduling, you tap "I'm Free" when you have a spare moment — on a walk, in the car, doing dishes — and the app pings one friend at a time from your queue. If they're around, you're instantly connected for a voice call. If not, it quietly moves on. No calendar invites, no missed-call guilt, no group texts.

HOW IT WORKS

• Invite a friend with a simple link. They install the app, and you land in each other's queues.
• When you have a few free minutes, tap "I'm Free".
• The app reaches out to one person from your queue at a time, starting with whoever you haven't caught up with in the longest.
• If they're also free, the voice call starts immediately inside the app.
• If nobody answers, you stay live for 10 minutes in case a friend pops in.

WHAT MAKES IT DIFFERENT

Voice only. One-on-one. No feeds, no likes, no read receipts, no video. The best conversations happen when two people just happen to be free at the same time. This app makes those moments easier to find.

PERFECT FOR

• Long-distance friends you've been meaning to call for months
• College friends scattered across time zones
• Family who always text but never call
• The friend who's always "we should grab coffee soon"

PRIVACY

Your queue is private. Only you see who's in it, and only you decide when you're free. We don't sell your data, track your location, or show ads.
```

### Keywords (100 char max, comma-separated, no spaces after commas)

```
voice call,catch up,friends,phone call,keep in touch,reconnect,talk,call app,calling,chat
```

### Support URL

```
https://weshouldcatchup.app/support
```

> If that page doesn't exist yet, point it to the main marketing site: `https://weshouldcatchup.app/`

### Marketing URL

```
https://weshouldcatchup.app/
```

### Version

```
1.0
```

### Copyright

```
© 2026 Sayem Hoque
```

### App Review Information

**Sign-in required?** ✅ Yes (phone auth required)

**Demo Account — configure a Firebase Test Phone Number before submitting:**

1. Firebase Console → Authentication → Sign-in method → Phone → **Phone numbers for testing**
2. Add: `+1 650-555-1234` with code `123456`
3. Save. This lets reviewers sign in without a real SMS being sent.

**User name field:**
```
+1 650-555-1234
```

**Password field:**
```
123456
```

**Contact Information:**

| Field | Value |
|---|---|
| First name | Sayem |
| Last name | Hoque |
| Phone number | *(your real number — reviewer may call if they hit a blocker)* |
| Email | sayem@flexbone.ai |

**Notes (4,000 char max):**

```
Thank you for reviewing We Should Catch Up.

SIGN-IN
The app uses phone-number authentication via Firebase Auth. A Firebase Test Phone Number is configured so you can sign in without receiving a real SMS:

  Phone: +1 650-555-1234
  Code:  123456

After signing in, you'll be asked for a display name. Enter anything (e.g. "Reviewer").

TESTING THE CORE FLOW

1. On the main screen, you'll see "YOUR QUEUE". New test accounts start with an empty queue — this is expected.

2. Tap the "I'm Free" button at the bottom. The app enters live-waiting mode and shows "Looking for someone…". Because the test account has no friends in its queue, nothing will connect. After a short wait you can tap "Never mind" to return.

3. To see a full end-to-end voice call, two test devices are needed. The app will send a push notification to a friend in the queue, they accept, and you're connected via Agora voice SDK. If you'd like us to provision a second test account for a reviewer's device, please email sayem@flexbone.ai and we'll add it within minutes.

PERMISSIONS

On first launch the app will request:
- Notifications (required — used to tell a user they've been pinged)
- Microphone (required — used during voice calls via Agora)

Please allow both to fully exercise the app.

FEATURES IN THIS BUILD
- Phone auth sign-in and display-name onboarding
- Queue of friends ordered by time since last call
- Edit mode on the queue list: drag to reorder, swipe or tap minus to remove
- "I'm Free" → sequential rotation through queue with 15-second ping cycles
- Inbound ping handling with Accept / Not now
- 1-on-1 voice calling via Agora SDK
- Call-ended summary screen

There are no in-app purchases, no ads, and no third-party data sharing beyond Firebase (auth/push) and Agora (voice transport). No content moderation is needed because the app is voice-only and 1-on-1 (no user-generated content is stored or broadcast).

Thank you!
```

**Attachment**: leave empty (none needed).

### App Store Version Release

Recommended for v1.0 first submission:

✅ **Manually release this version**

Lets you flip the switch after approval, so you can announce on your own schedule and confirm the build is live before telling anyone.

### Fields to leave empty / untouched

- App Clip — skip
- iMessage App — skip
- Game Center — skip
- Routing App Coverage File — skip
- App Previews (video) — skip

### Before tapping "Add for Review"

- [ ] All 5 screenshots uploaded to 6.5" slot
- [ ] Description, keywords, promotional text filled
- [ ] Support URL reachable
- [ ] Copyright filled
- [ ] Firebase test phone number configured and verified working
- [ ] Build 22 (or latest) uploaded, processed, and selected in the "Build" section
- [ ] Export compliance answered on the selected build (HTTPS-only → "No" to custom encryption)
- [ ] App Privacy questionnaire complete (separate section — covered under "App Privacy" in the left sidebar)
- [ ] Age rating complete (under "App Information")
- [ ] Pricing set (under "Pricing and Availability") — free

