# App Scaffold Guide

Everything learned building **We Should Catch Up** — architecture, design system, deployment, gotchas — distilled into a reusable playbook for the next app.

---

## Table of Contents

1. [Tech Stack](#tech-stack)
2. [Project Structure](#project-structure)
3. [Design System](#design-system)
4. [iOS App Architecture](#ios-app-architecture)
5. [Backend Architecture](#backend-architecture)
6. [Landing Page](#landing-page)
7. [Authentication](#authentication)
8. [Push Notifications](#push-notifications)
9. [Deep Links & Universal Links](#deep-links--universal-links)
10. [Deployment](#deployment)
11. [App Store Submission](#app-store-submission)
12. [Firebase Setup](#firebase-setup)
13. [Gotchas & Lessons Learned](#gotchas--lessons-learned)
14. [Checklist: New App from Scratch](#checklist-new-app-from-scratch)

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| iOS App | SwiftUI (iOS 16+) | Declarative, fast iteration |
| Backend | Fastify (Node.js/TypeScript) | Lightweight, fast, great TS support |
| Database | Firebase Firestore | Schemaless, real-time, free tier generous |
| Auth | Firebase Phone Auth | Drop-in phone/SMS verification |
| Push | Firebase Cloud Messaging (FCM) | Free, reliable iOS/Android push |
| Hosting (API) | Google Cloud Run | Scales to zero, Docker-based, $0 at low traffic |
| Hosting (Web) | Cloudflare Pages + Workers | Free tier, global edge, Next.js support |
| Email | Resend | Simple API, generous free tier (3k/month) |
| Domain | Cloudflare Registrar | Cheap, integrated DNS |

---

## Project Structure

### iOS App

```
AppName/
├── App/
│   ├── AppNameApp.swift          # @main, scene setup, .onOpenURL
│   └── AppDelegate.swift         # Firebase init, APNs, push handling
├── Models/
│   ├── User.swift                # Codable user model
│   └── [Domain]Item.swift        # Domain-specific models
├── Services/
│   ├── APIService.swift          # Singleton HTTP client
│   ├── AuthService.swift         # Firebase Auth wrapper
│   ├── PushNotificationService.swift  # FCM token + payload parsing
│   └── DeepLinkService.swift     # Universal link handler
├── ViewModels/
│   ├── AuthViewModel.swift       # Onboarding state machine
│   └── [Feature]ViewModel.swift  # Per-feature state
├── Views/
│   ├── Onboarding/               # Auth + setup flow
│   ├── Main/                     # Home screen
│   ├── [Feature]/                # Feature-specific screens
│   └── History/                  # Activity/history
├── Utilities/
│   ├── Constants.swift           # Colors, fonts, layout, API URLs
│   └── Extensions.swift          # Color(hex:), Font helpers, String validation
├── Resources/
│   └── Fonts/                    # .ttf files (Fraunces, Inter)
├── Assets.xcassets/              # App icon, images
├── Info.plist
└── AppName.entitlements
```

### Backend

```
backend/
├── src/
│   ├── index.ts                  # Fastify server, Firebase init, route registration
│   ├── middleware/
│   │   └── auth.ts               # Firebase ID token verification
│   ├── routes/
│   │   ├── profile.ts            # User CRUD
│   │   ├── [feature].ts          # Feature endpoints
│   │   ├── waitlist.ts           # Public waitlist signup
│   │   └── report.ts             # Safety/moderation
│   ├── services/
│   │   ├── firestoreService.ts   # All Firestore read/write operations
│   │   └── pushService.ts        # FCM notification sending
│   └── types/
│       └── index.ts              # All TypeScript interfaces
├── Dockerfile                    # Multi-stage Node 20 build
├── package.json
├── tsconfig.json
└── .env.example
```

### Scripts

```
scripts/
├── upload-testflight.sh          # Archive + upload iOS app
└── ExportOptions.plist           # App Store Connect export config
```

---

## Design System

### Color Palette (Coffee/Warm Theme)

```swift
enum Colors {
    // Brand
    static let primary     = Color(hex: 0x6F4E37)  // coffee brown
    static let primaryDark = Color(hex: 0x553A28)  // espresso
    static let primaryLight = Color(hex: 0xE8D5C4) // latte

    // Backgrounds
    static let background     = Color(hex: 0xFAF6F1)  // cream
    static let backgroundDark = Color(hex: 0xF0E8DF)  // oat milk
    static let cardBackground = Color.white

    // Text (3-level hierarchy)
    static let textPrimary   = Color(hex: 0x2C2119)  // dark roast
    static let textSecondary = Color(hex: 0x5C4F44)  // medium roast
    static let textTertiary  = Color(hex: 0x8C7E73)  // light roast

    // Borders & Utility
    static let border      = Color(hex: 0xDDD3C8)
    static let destructive = Color(hex: 0xFB2C36)
    static let success     = Color(red: 0.30, green: 0.70, blue: 0.45)
}
```

**CSS equivalent (for landing page):**
```css
:root {
    --primary: #6F4E37;
    --primary-dark: #553A28;
    --primary-light: #E8D5C4;
    --bg: #FAF6F1;
    --bg-dark: #F0E8DF;
    --text-primary: #2C2119;
    --text-secondary: #5C4F44;
    --text-tertiary: #8C7E73;
    --border: #DDD3C8;
}
```

### Typography

Two fonts, consistent across iOS and web:

| Role | Font | Weights | Usage |
|------|------|---------|-------|
| Display/Headlines | **Fraunces** (serif) | Regular, Medium, SemiBold, Bold | Titles, names, branding |
| Body/UI | **Inter** (sans-serif) | Regular, Medium, SemiBold | Labels, buttons, body text |

**iOS font extension (copy this verbatim):**

```swift
extension Font {
    static func fraunces(_ size: CGFloat, weight: FrauncesWeight = .regular) -> Font {
        .custom(weight.fontName, size: size)
    }
    static func inter(_ size: CGFloat, weight: InterWeight = .regular) -> Font {
        .custom(weight.fontName, size: size)
    }
    enum FrauncesWeight {
        case regular, medium, semiBold, bold
        var fontName: String {
            switch self {
            case .regular:  return "Fraunces-Regular"
            case .medium:   return "Fraunces-Medium"
            case .semiBold: return "Fraunces-SemiBold"
            case .bold:     return "Fraunces-Bold"
            }
        }
    }
    enum InterWeight {
        case regular, medium, semiBold
        var fontName: String {
            switch self {
            case .regular:  return "Inter-Regular"
            case .medium:   return "Inter-Medium"
            case .semiBold: return "Inter-SemiBold"
            }
        }
    }
}
```

**Info.plist font registration:**
```xml
<key>UIAppFonts</key>
<array>
    <string>Fraunces-Regular.ttf</string>
    <string>Fraunces-Medium.ttf</string>
    <string>Fraunces-SemiBold.ttf</string>
    <string>Fraunces-Bold.ttf</string>
    <string>Inter-Regular.ttf</string>
    <string>Inter-Medium.ttf</string>
    <string>Inter-SemiBold.ttf</string>
</array>
```

### Layout Constants

```swift
enum Layout {
    static let horizontalPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 32
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let buttonHeight: CGFloat = 56
}
```

### Color Hex Extension

```swift
extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
```

### Common UI Patterns

**Primary button:**
```swift
Button("Action") { }
    .font(.inter(16, weight: .semiBold))
    .foregroundColor(.white)
    .frame(maxWidth: .infinity)
    .frame(height: Constants.Layout.buttonHeight)
    .background(Constants.Colors.primary)
    .cornerRadius(28)
```

**Card row:**
```swift
HStack(spacing: 12) { /* content */ }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color.white)
    .cornerRadius(12)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Constants.Colors.border, lineWidth: 1)
    )
```

**Avatar circle with initials:**
```swift
ZStack {
    Circle()
        .fill(Constants.Colors.primary.opacity(0.10))
        .frame(width: 44, height: 44)
    Text("A")
        .font(.fraunces(16, weight: .semiBold))
        .foregroundColor(Constants.Colors.primary)
}
```

**Section header:**
```swift
Text("SECTION TITLE")
    .font(.inter(11, weight: .semiBold))
    .foregroundColor(Constants.Colors.textTertiary)
    .tracking(1.2)
```

---

## iOS App Architecture

### App Entry Point

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var deepLinkService = DeepLinkService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(deepLinkService)
                .preferredColorScheme(.light)  // force light mode
                .onOpenURL { url in
                    _ = deepLinkService.handleIncomingURL(url)
                }
        }
    }
}
```

### Root View (Auth-Gated Navigation)

```swift
struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !authService.isAuthenticated || !hasCompletedOnboarding {
                OnboardingFlow(onComplete: { hasCompletedOnboarding = true })
            } else if let pendingDeepLink = deepLinkService.pendingId {
                DeepLinkHandlerView(id: pendingDeepLink)
            } else {
                MainView()
            }
        }
        // Global overlays (modals that can appear from anywhere)
        .fullScreenCover(item: $globalState) { state in ... }
    }
}
```

### Service Layer Pattern (Singleton + async/await)

```swift
final class APIService {
    static let shared = APIService()

    private let baseURL: String = Constants.backendBaseURL
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // Auto-inject Firebase ID token
    private func authorizedRequest(path: String, method: String, body: [String: Any]? = nil) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let token = try await Auth.auth().currentUser!.getIDToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: msg)
        }
        return try decoder.decode(T.self, from: data)
    }
}
```

### ViewModel Pattern

```swift
@MainActor
class FeatureViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchItems() async {
        isLoading = true
        do {
            items = try await APIService.shared.fetchItems()
        } catch {
            if items.isEmpty {  // only show error if no cached data
                errorMessage = "Couldn't load items."
            }
        }
        isLoading = false
    }
}
```

### Onboarding State Machine

```swift
@MainActor
class AuthViewModel: ObservableObject {
    enum OnboardingStep {
        case phoneEntry
        case codeVerification
        case notificationPermission
        case termsAgreement
        case displayNameEntry
        case inviteFriends
        case complete
    }

    @Published var currentStep: OnboardingStep = .phoneEntry

    // Each step calls the next:
    func verifyCode() async {
        // ... verify ...
        currentStep = isReturningUser ? .inviteFriends : .notificationPermission
    }
    func notificationsEnabled() { currentStep = .termsAgreement }
    func termsAccepted() { currentStep = .displayNameEntry }
}
```

Then in the view:
```swift
struct OnboardingFlow: View {
    @StateObject private var viewModel = AuthViewModel()
    var body: some View {
        switch viewModel.currentStep {
        case .phoneEntry, .codeVerification: PhoneAuthView(viewModel: viewModel)
        case .notificationPermission: NotificationPermissionView(...)
        case .termsAgreement: TermsAgreementView(...)
        case .displayNameEntry: DisplayNameView(...)
        case .inviteFriends: InviteFriendsView(...)
        case .complete: Color.clear.onAppear { onComplete() }
        }
    }
}
```

### Navigation Patterns

- **NavigationStack** for push-based navigation (main → detail)
- **.sheet()** for modal forms (invite, settings)
- **.fullScreenCover()** for immersive takeovers (calls, incoming alerts)
- **.confirmationDialog()** for action sheets (account menu)
- **.alert()** for confirmations (delete, report)
- **NotificationCenter** for cross-component communication (push events, data refresh)

### String Validation Extensions

```swift
extension String {
    var isValidPhoneNumber: Bool {
        let digits = self.filter { $0.isNumber }
        return self.hasPrefix("+") && digits.count >= 10
    }
    var isValidDisplayName: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 30
    }
}
```

### Duration/Date Formatting

```swift
extension Int {
    func formattedDuration() -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60
        if hours > 0 { return minutes > 0 ? "\(hours) hr \(minutes) min" : "\(hours) hr" }
        if minutes > 0 { return seconds > 0 ? "\(minutes) min \(seconds) sec" : "\(minutes) min" }
        return "\(seconds) sec"
    }
    func callTimerString() -> String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}
```

---

## Backend Architecture

### Server Bootstrap (index.ts)

```typescript
import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";
import admin from "firebase-admin";

// Firebase Admin — auto-detects Cloud Run ADC vs local service-account.json
const serviceAccountPath = resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS || "./service-account.json");
if (existsSync(serviceAccountPath)) {
    const sa = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
    admin.initializeApp({ credential: admin.credential.cert(sa), projectId: process.env.FIREBASE_PROJECT_ID });
} else {
    admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID });
}

const server = Fastify({ logger: true });
await server.register(cors, { origin: true });

// Register route plugins
await server.register(profileRoutes);
await server.register(featureRoutes);
// ...

server.get("/health", async () => ({ status: "ok" }));

const PORT = Number(process.env.PORT) || 8080;
await server.listen({ port: PORT, host: "0.0.0.0" });

// Graceful shutdown
process.on("SIGINT", async () => { await server.close(); process.exit(0); });
process.on("SIGTERM", async () => { await server.close(); process.exit(0); });
```

### Auth Middleware

```typescript
import admin from "firebase-admin";

export async function authMiddleware(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        reply.code(401).send({ error: "Missing or malformed Authorization header" });
        return;
    }
    try {
        const decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
        request.userId = decoded.uid;
    } catch (err) {
        reply.code(401).send({ error: "Invalid or expired token" });
    }
}

// Augment Fastify types
declare module "fastify" {
    interface FastifyRequest { userId: string; }
}
```

### Route Pattern

```typescript
import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middleware/auth.js";
import { firestoreService } from "../services/firestoreService.js";

export default async function featureRoutes(server: FastifyInstance) {
    server.post("/do-thing", { preHandler: authMiddleware }, async (request, reply) => {
        const userId = request.userId;
        const { someField } = request.body as { someField: string };

        // Business logic...
        const result = await firestoreService.doThing(userId, someField);

        return { status: "ok", result };
    });
}
```

### Firestore Service Pattern

```typescript
import admin from "firebase-admin";
const db = admin.firestore();

export const firestoreService = {
    async getUser(userId: string): Promise<UserDoc | null> {
        const doc = await db.collection("users").doc(userId).get();
        return doc.exists ? (doc.data() as UserDoc) : null;
    },

    async updateUser(userId: string, data: Partial<UserDoc>): Promise<void> {
        await db.collection("users").doc(userId).set(data, { merge: true });
    },

    // Always use .set({ merge: true }) instead of .update() — safer, handles missing docs
};
```

### Push Notification Service

```typescript
import admin from "firebase-admin";

export async function sendPushNotification(
    fcmToken: string,
    title: string,
    body: string,
    data: Record<string, string>,
    collapseKey?: string
) {
    const message: admin.messaging.Message = {
        token: fcmToken,
        notification: { title, body },
        data,
        android: { priority: "high", ...(collapseKey ? { collapseKey } : {}) },
        apns: {
            headers: {
                "apns-priority": "10",
                ...(collapseKey ? { "apns-collapse-id": collapseKey } : {}),
            },
            payload: { aps: { sound: "default" } },
        },
    };
    try {
        await admin.messaging().send(message);
    } catch (err: any) {
        // Stale token — log but don't crash
        if (err.code === "messaging/invalid-registration-token" ||
            err.code === "messaging/registration-token-not-registered") {
            console.warn("Stale FCM token:", fcmToken);
        } else {
            throw err;
        }
    }
}

// Silent push (data-only, no notification banner)
export async function sendSilentPush(fcmToken: string, data: Record<string, string>) {
    await admin.messaging().send({
        token: fcmToken,
        data,
        apns: { payload: { aps: { "content-available": 1 } } },
        android: { priority: "high" },
    });
}
```

### TypeScript Config (tsconfig.json)

```json
{
    "compilerOptions": {
        "target": "ES2022",
        "module": "NodeNext",
        "moduleResolution": "NodeNext",
        "outDir": "dist",
        "rootDir": "src",
        "strict": true,
        "esModuleInterop": true,
        "skipLibCheck": true,
        "forceConsistentCasingInFileNames": true,
        "resolveJsonModule": true,
        "declaration": true,
        "sourceMap": true
    },
    "include": ["src/**/*"],
    "exclude": ["node_modules", "dist"]
}
```

### Dockerfile (Multi-Stage)

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ ./src/
RUN npx tsc

# Production stage
FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev
COPY --from=builder /app/dist ./dist
EXPOSE 8080
CMD ["node", "dist/index.js"]
```

### Backend Dependencies (package.json)

```json
{
    "dependencies": {
        "@fastify/cors": "^10.0.0",
        "dotenv": "^17.3.1",
        "fastify": "^5.0.0",
        "firebase-admin": "^12.0.0",
        "resend": "^6.12.2"
    },
    "devDependencies": {
        "@types/node": "^22.0.0",
        "tsx": "^4.0.0",
        "typescript": "^5.0.0"
    },
    "scripts": {
        "dev": "tsx watch src/index.ts",
        "build": "npx tsc",
        "start": "node dist/index.js"
    }
}
```

### Environment Variables

```bash
# .env
FIREBASE_PROJECT_ID=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json
PORT=8080
RESEND_API_KEY=re_xxxxxxxxxxxx   # optional, for email notifications
```

---

## Landing Page

### Stack
- **Next.js** on **Cloudflare Pages** via `@opennextjs/cloudflare`
- Tailwind CSS v4

### Deploy
```bash
npm run deploy   # builds + deploys to Cloudflare Workers
```

### Key Pages
```
app/
├── layout.tsx          # Nav bar, footer, metadata, Google Fonts
├── page.tsx            # Hero + signup form
├── about/page.tsx      # About / CTA
├── privacy/page.tsx    # Privacy policy
├── terms/page.tsx      # Terms of service
├── support/page.tsx    # FAQ / contact
├── invite/[id]/page.tsx  # Deep link handler (redirects to app)
├── api/waitlist/route.ts  # Waitlist signup API (proxies to backend)
└── .well-known/apple-app-site-association/route.ts  # Universal links
```

### Waitlist/Signup Form Pattern
```typescript
// app/api/waitlist/route.ts — proxy to backend
export async function POST(request: Request) {
    const body = await request.json();
    const res = await fetch(`${BACKEND_URL}/waitlist-signup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
    return new Response(await res.text(), { status: res.status });
}
```

### Email Notification on Signup (Resend)
```typescript
// In backend /waitlist-signup handler
import { Resend } from "resend";
const resend = new Resend(process.env.RESEND_API_KEY);

await resend.emails.send({
    from: "App Name <noreply@yourdomain.com>",
    to: ["you@yourdomain.com"],
    subject: `New signup: ${email}`,
    text: `Email: ${email}\nWants TestFlight: ${wantTestFlight}\nComment: ${comment}`,
});
```

### Analytics
- **Cloudflare Web Analytics** — add the JS snippet to layout.tsx
- Free, privacy-first, no cookies

---

## Authentication

### Firebase Phone Auth (iOS)

**AuthService.swift** — singleton wrapper:

```swift
final class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published var isAuthenticated = false
    @Published var currentUserId: String?

    init() {
        // Listen for Firebase auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
            }
        }
    }

    func sendVerificationCode(phoneNumber: String) async throws {
        #if targetEnvironment(simulator)
        // Simulator can't receive SMS — use anonymous auth for dev
        let result = try await Auth.auth().signInAnonymously()
        await MainActor.run { self.isAuthenticated = true; self.currentUserId = result.user.uid }
        #else
        let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
        await MainActor.run { self.verificationId = id }
        #endif
    }

    func signOut() throws {
        PushNotificationService.shared.clearFCMToken()
        try Auth.auth().signOut()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}
```

### Test Phone Numbers (Firebase Console)

Set up test numbers in Firebase Console → Authentication → Phone → Phone numbers for testing:

| Number | Code | Purpose |
|--------|------|---------|
| +1 555-123-4567 | 123456 | App Store reviewer |
| +1 555-555-5555 | 123456 | Dev testing |

**Critical:** Apple requires a demo account. Set these up BEFORE submitting.

---

## Push Notifications

### AppDelegate Setup

```swift
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // APNs token → Firebase
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        PushNotificationService.shared.updateFCMToken(token)
    }

    // Foreground push handling
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        // Parse and handle...
        return [.banner, .sound]
    }
}
```

### PushNotificationService Pattern

```swift
final class PushNotificationService {
    static let shared = PushNotificationService()

    enum NotificationType {
        case someAction(userId: String, data: String)
        case dataRefresh
    }

    func handleNotification(userInfo: [AnyHashable: Any]) -> NotificationType? {
        guard let type = userInfo["type"] as? String else { return nil }
        switch type {
        case "some_action":
            guard let userId = userInfo["userId"] as? String else { return nil }
            return .someAction(userId: userId, data: userInfo["data"] as? String ?? "")
        case "data_refresh":
            return .dataRefresh
        default: return nil
        }
    }

    func persistTokenIfReady() {
        guard let token = cachedToken, AuthService.shared.isAuthenticated else { return }
        Task { try? await APIService.shared.updateFCMToken(token) }
    }
}
```

### Notification Types to Plan For

| Type | Banner? | Sound? | Purpose |
|------|---------|--------|---------|
| User action alert | Yes | Yes | Someone did something relevant |
| Data refresh | No (silent) | No | Trigger background data fetch |
| Expiry/replacement | Yes (replaces) | No | Update/replace a previous notification |

### Key Push Concepts

- **Collapse keys** — same key = new push replaces old one (use for time-sensitive alerts)
- **Silent pushes** — `content-available: 1`, no banner, triggers background fetch
- **APNs expiration** — set short TTL for time-sensitive notifications
- **Stale token handling** — catch `invalid-registration-token` errors, log but don't crash

---

## Deep Links & Universal Links

### Apple App Site Association

Serve from `/.well-known/apple-app-site-association` (no file extension):

```json
{
    "applinks": {
        "apps": [],
        "details": [{
            "appID": "TEAMID.com.your.bundleid",
            "paths": ["/invite/*"]
        }]
    }
}
```

On Cloudflare/Next.js, serve as a dynamic route:
```typescript
// app/.well-known/apple-app-site-association/route.ts
export async function GET() {
    return new Response(JSON.stringify({
        applinks: {
            apps: [],
            details: [{ appID: "345UAJF999.com.sayem.AppName", paths: ["/invite/*"] }]
        }
    }), { headers: { "Content-Type": "application/json" } });
}
```

### iOS Deep Link Handling

```swift
class DeepLinkService: ObservableObject {
    @Published var pendingInviteId: String?

    func handleIncomingURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "yourdomain.app",
              components.path.hasPrefix("/invite/") else { return false }
        let id = String(components.path.dropFirst("/invite/".count))
        guard !id.isEmpty else { return false }
        pendingInviteId = id
        return true
    }

    // Deferred deep linking: check clipboard after install
    func checkClipboardForInvite() {
        guard let string = UIPasteboard.general.string,
              let url = URL(string: string) else { return }
        _ = handleIncomingURL(url)
    }
}
```

### Entitlements

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourdomain.app</string>
</array>
```

---

## Deployment

### iOS → TestFlight

**One-time setup:**
1. Sign into Apple Developer account in Xcode → Settings → Accounts
2. Create `scripts/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>destination</key><string>upload</string>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>YOUR_TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>stripSwiftSymbols</key><true/>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
```

3. Create `scripts/upload-testflight.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SCHEME="AppName"
PROJECT="AppName.xcodeproj"
BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$REPO_ROOT/scripts/ExportOptions.plist"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates clean archive

xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates
```

**Each release:**
```bash
# 1. Bump build number in project.pbxproj (CURRENT_PROJECT_VERSION)
# 2. Commit
# 3. Upload
./scripts/upload-testflight.sh
# Wait 5-15 min for Apple processing
```

### Backend → Cloud Run

```bash
cd backend
gcloud run deploy your-api-name \
    --source . \
    --region us-east1 \
    --allow-unauthenticated \
    --project your-firebase-project-id
```

If `--source` fails (sometimes does), use two-step:
```bash
gcloud builds submit --tag gcr.io/PROJECT_ID/api-name --project PROJECT_ID
gcloud run deploy api-name --image gcr.io/PROJECT_ID/api-name \
    --region us-east1 --allow-unauthenticated --project PROJECT_ID
```

### Landing Page → Cloudflare

```bash
cd landing-page-repo
npm run deploy   # opennextjs-cloudflare build && opennextjs-cloudflare deploy
```

### Full Deploy Sequence

```bash
# 1. Backend
cd backend && gcloud run deploy api-name --source . --region us-east1 --allow-unauthenticated --project PROJECT_ID

# 2. Landing page
cd ../landing-page && npm run deploy

# 3. iOS (bump build number first)
cd ../ios-app && ./scripts/upload-testflight.sh

# 4. Push code
git add -A && git commit -m "Release v1.x" && git push
```

---

## App Store Submission

### Required Before Submission

1. **App icon** — 1024x1024 in Assets.xcassets
2. **Screenshots** — 6.7" (1290x2796) and 6.5" (1284x2778), optionally 6.9" (1320x2868)
3. **Privacy policy URL** — hosted on your landing page
4. **Support URL** — can be same domain
5. **Description** — under 4000 chars
6. **Keywords** — comma-separated, 100 char max
7. **Age rating** — answer the questionnaire honestly; if there's user-generated content or social features, expect 17+/18+
8. **Test account** — Firebase test phone number + verification code

### Info.plist Keys You'll Need

```xml
<!-- Skip export compliance popup -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<!-- Permissions (include ALL that SDK might request, even if unused) -->
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice calls.</string>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Entitlements

```xml
<!-- Production push -->
<key>aps-environment</key>
<string>production</string>

<!-- Universal links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourdomain.app</string>
</array>
```

### Common Rejection Reasons & Fixes

| Issue | Fix |
|-------|-----|
| **4.5.4 Push notifications required** | Add "Not now" / skip button on notification permission screen |
| **1.2 User-generated content** | Add report/block UI, terms agreement in onboarding, contact support in settings |
| **2.1 Demo account broken** | Use Firebase test phone numbers, verify they work before submission |
| **Age rating too low** | Social/1-on-1 communication apps need 17+/18+ |

### Reviewer Notes Template

```
To test the app:
1. Open the app and enter phone number: +1 555-123-4567
2. Enter verification code: 123456
3. Allow notifications (or tap "Not now")
4. Agree to terms
5. Enter a display name
6. [App-specific testing steps]

Safety features:
- Users can report/block via long-press context menu
- Terms of service agreement required during onboarding
- Contact support available in account settings
- All reports reviewed within 24 hours
```

---

## Firebase Setup

### Console Setup Checklist

1. Create project at console.firebase.google.com
2. Add iOS app (bundle ID, team ID)
3. Download `GoogleService-Info.plist` → add to Xcode project
4. Enable Authentication → Phone
5. Add test phone numbers (Authentication → Phone → Phone numbers for testing)
6. Create Firestore database (production mode)
7. Generate service account key (Project Settings → Service Accounts → Generate New Private Key)
8. Save as `backend/service-account.json` (DO NOT commit to git)

### Firestore Collections (Template)

```
users/{userId}
    phone: string
    displayName: string
    fcmToken: string | null
    status: "idle" | "active" | "busy"
    createdAt: ISO-8601
    updatedAt: ISO-8601

[domain]/{docId}
    userA: string (creator)
    userB: string (other party)
    status: "pending" | "active" | "removed"
    createdAt: ISO-8601
    ...domain-specific fields

waitlist/{docId}
    email: string
    createdAt: ISO-8601
    comment: string | null

reports/{docId}
    reporterId: string
    reportedUserId: string
    createdAt: ISO-8601
    status: "pending"
```

### Security Rules (Starter)

```javascript
rules_version = '2';
service cloud.firestore {
    match /databases/{database}/documents {
        // Users can only read/write their own doc
        match /users/{userId} {
            allow read, write: if request.auth != null && request.auth.uid == userId;
        }
        // Everything else goes through the backend (admin SDK bypasses rules)
        match /{document=**} {
            allow read, write: if false;
        }
    }
}
```

---

## Gotchas & Lessons Learned

### SwiftUI

- **Never put List inside ScrollView** — it collapses to zero height. Use `VStack` + `ForEach` inside `ScrollView` instead.
- **List's .onDelete + swipeActions conflict** — removing List entirely in favor of VStack with explicit buttons avoids crashes.
- **@AppStorage("hasCompletedOnboarding") must be cleared on sign-out** — otherwise returning users get stuck in a broken state.
- **Simulator can't do phone auth** — use anonymous auth fallback with `#if targetEnvironment(simulator)`.
- **Force light mode** with `.preferredColorScheme(.light)` at the root — design for one mode first, add dark mode later.

### Backend

- **Cloud Run `--source` deploy sometimes fails** — use two-step build+deploy as fallback.
- **Firestore `.set({ merge: true })` is safer than `.update()`** — handles missing docs gracefully.
- **FCM tokens go stale** — always wrap push sends in try/catch, check for specific error codes.
- **Fire-and-forget background tasks** — don't await long-running operations in request handlers. Start them and return immediately.
- **CORS `origin: true`** is fine for dev — lock down to specific domains for production.

### App Store

- **Push notifications must be optional** — Apple rejects if the app says "notifications required".
- **Social apps need 17+/18+ age rating** — any 1-on-1 communication feature triggers this.
- **Test phone numbers must actually work** — verify in Firebase Console before submitting.
- **`ITSAppUsesNonExemptEncryption = NO`** — add to Info.plist to skip the export compliance question every TestFlight upload.
- **`aps-environment` must be `production`** in entitlements for App Store builds.
- **Include report/block, terms, and contact support** from day one — Apple requires these for any social app.

### Deployment

- **Xcode session auth expires** — if TestFlight upload fails with 401, restart Xcode and re-sign into your Apple ID.
- **Bump `CURRENT_PROJECT_VERSION`** before every TestFlight upload — Apple rejects duplicate build numbers.
- **Cloud Run uses Application Default Credentials** — no need to upload service-account.json to Cloud Run; it uses the project's default service account.
- **Cloudflare Workers can't fetch custom fonts** at build time for OG images — use system fonts for `opengraph-image.tsx`.

### Data

- **Deduplicate relationships** — when querying bidirectional relationships (userA/userB), deduplicate by the other user to prevent showing duplicates.
- **Cascade soft-deletes** — when deleting an account, mark related documents as `removed` rather than hard-deleting, so the other party's UI updates cleanly.
- **Always handle the invite lifecycle** — if a user starts creating an invite but cancels, clean up the dangling record. Track `wasShared` state.

---

## Checklist: New App from Scratch

### Day 0: Infrastructure

- [ ] Create Firebase project
- [ ] Add iOS app in Firebase Console, download GoogleService-Info.plist
- [ ] Enable Phone Authentication + add test numbers
- [ ] Create Firestore database
- [ ] Generate service account key → `backend/service-account.json`
- [ ] Register domain (Cloudflare)
- [ ] Create GitHub repo (private)

### Day 1: Backend

- [ ] `mkdir backend && cd backend && npm init -y`
- [ ] Install: `fastify @fastify/cors firebase-admin dotenv`
- [ ] Install dev: `typescript @types/node tsx`
- [ ] Copy `tsconfig.json`, `Dockerfile`, `.env.example` from templates above
- [ ] Create `src/index.ts` (server bootstrap)
- [ ] Create `src/middleware/auth.ts` (Firebase token verification)
- [ ] Create `src/services/firestoreService.ts`
- [ ] Create `src/routes/profile.ts` (user CRUD)
- [ ] Create `src/types/index.ts`
- [ ] Test locally: `npm run dev`
- [ ] Deploy: `gcloud run deploy --source .`

### Day 2: iOS App Shell

- [ ] Create Xcode project (SwiftUI, iOS 16+)
- [ ] Add SPM packages: `firebase-ios-sdk`
- [ ] Add fonts to `Resources/Fonts/`, register in Info.plist
- [ ] Create `Utilities/Constants.swift` (colors, fonts, layout, URLs)
- [ ] Create `Utilities/Extensions.swift` (Color hex, Font helpers)
- [ ] Create `Services/AuthService.swift`
- [ ] Create `Services/APIService.swift`
- [ ] Create `App/AppDelegate.swift` (Firebase init)
- [ ] Create `App/AppNameApp.swift` (root scene)
- [ ] Create RootView with auth-gated navigation

### Day 3: Onboarding

- [ ] Create `ViewModels/AuthViewModel.swift` (step state machine)
- [ ] Create `Views/Onboarding/PhoneAuthView.swift`
- [ ] Create `Views/Onboarding/NotificationPermissionView.swift` (with skip button!)
- [ ] Create `Views/Onboarding/TermsAgreementView.swift`
- [ ] Create `Views/Onboarding/DisplayNameView.swift`
- [ ] Wire up OnboardingFlow switch statement

### Day 4: Core Feature

- [ ] Backend routes for core feature
- [ ] iOS models (Codable structs)
- [ ] iOS ViewModel
- [ ] iOS Views (main screen + detail)
- [ ] Pull-to-refresh + foreground reload

### Day 5: Push + Deep Links

- [ ] Create `Services/PushNotificationService.swift`
- [ ] Wire up AppDelegate for FCM
- [ ] Backend push service
- [ ] Create `Services/DeepLinkService.swift`
- [ ] Serve `apple-app-site-association` from web
- [ ] Add associated domains entitlement
- [ ] Add report/block UI + backend endpoint

### Day 6: Landing Page

- [ ] Create Next.js project with Tailwind
- [ ] Install `@opennextjs/cloudflare`
- [ ] Create pages: home, about, privacy, terms, support
- [ ] Create waitlist API route
- [ ] Set up Resend email notifications
- [ ] Deploy to Cloudflare: `npm run deploy`
- [ ] Add Cloudflare Web Analytics

### Day 7: Ship

- [ ] Create `scripts/upload-testflight.sh` + `ExportOptions.plist`
- [ ] Add app icon (1024x1024)
- [ ] Take screenshots (6.7" + 6.5")
- [ ] Set `ITSAppUsesNonExemptEncryption = NO` in Info.plist
- [ ] Set `aps-environment = production` in entitlements
- [ ] Upload to TestFlight
- [ ] Fill out App Store Connect (description, keywords, age rating, privacy URL, support URL, reviewer credentials)
- [ ] Submit for review

---

*Generated from the We Should Catch Up codebase — April 2026*
