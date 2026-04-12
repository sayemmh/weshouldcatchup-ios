import type { FastifyRequest } from "fastify";

// ---------------------------------------------------------------------------
// Enums / Literal Types
// ---------------------------------------------------------------------------

export type UserStatus = "idle" | "live" | "in_call";
export type CatchUpStatus = "pending" | "active" | "removed";

// ---------------------------------------------------------------------------
// Firestore Document Types
// ---------------------------------------------------------------------------

export interface UserDoc {
  phone: string;
  displayName: string;
  fcmToken: string | null;
  status: UserStatus;
  liveSince: string | null;      // ISO-8601 timestamp
  liveTTL: string | null;        // ISO-8601 timestamp (when the live window expires)
  queueOrder: string[] | null;   // ordered catchupIds for custom queue priority
  createdAt: string;             // ISO-8601 timestamp
  updatedAt: string;             // ISO-8601 timestamp
}

export interface CatchUpDoc {
  userA: string;                 // userId who created the catch-up
  userB: string;                 // userId who accepted the invite
  status: CatchUpStatus;
  createdAt: string;             // ISO-8601 timestamp
  acceptedAt: string | null;     // ISO-8601 timestamp
  removedBy: string | null;      // userId who removed the catch-up
  lastCallAt: string | null;     // ISO-8601 timestamp of most recent call
  callCount: number;
}

export interface CallDoc {
  catchupId: string;
  participants: string[];        // [userA, userB]
  agoraChannel: string;
  startedAt: string;             // ISO-8601 timestamp
  endedAt: string | null;        // ISO-8601 timestamp
  duration: number | null;       // seconds
}

// ---------------------------------------------------------------------------
// Request / Response Types
// ---------------------------------------------------------------------------

// POST /go-live
export interface GoLiveResponse {
  status: string;
  liveTTL: string;               // ISO-8601 timestamp indicating when live expires
}

// POST /accept-ping
export interface AcceptPingRequest {
  catchupId: string;
  callId: string;
}

export interface AcceptPingResponse {
  agoraChannel: string;
  agoraToken: string;
  callId: string;
}

// POST /join-call
export interface JoinCallRequest {
  callId: string;
}

export interface JoinCallResponse {
  agoraChannel: string;
  agoraToken: string;
  callId: string;
}

// POST /end-call
export interface EndCallRequest {
  callId: string;
}

export interface EndCallResponse {
  duration: number;              // seconds
}

// POST /create-catchup
export interface CreateCatchupResponse {
  catchupId: string;
  inviteLink: string;
}

// POST /accept-catchup
export interface AcceptCatchupRequest {
  catchupId: string;
}

// POST /remove-catchup
export interface RemoveCatchupRequest {
  catchupId: string;
}

// GET /my-queue item
export interface QueueItemResponse {
  catchupId: string;
  otherUser: {
    name: string;
    userId: string;
  };
  lastCallAt: string | null;
  callCount: number;
  status: CatchUpStatus;
}

// GET /call-history item
export interface CallHistoryItemResponse {
  callId: string;
  otherUser: {
    name: string;
    userId: string;
  };
  startedAt: string;
  duration: number;
}

// ---------------------------------------------------------------------------
// Fastify Augmentation
// ---------------------------------------------------------------------------

declare module "fastify" {
  interface FastifyRequest {
    userId: string;
  }
}
