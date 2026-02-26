import agoraToken from "agora-token";
const { RtcTokenBuilder, RtcRole } = agoraToken;

/**
 * Generates an Agora RTC token for a given channel and user.
 *
 * Both participants receive PUBLISHER role so they can send and receive
 * audio/video. The token is valid for 1 hour (3600 seconds).
 *
 * @param channelName - Unique Agora channel name for the call.
 * @param uid - Numeric user ID for Agora (0 means Agora will assign one).
 * @returns The generated RTC token string.
 */
export function generateAgoraToken(channelName: string, uid: number): string {
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  if (!appId || !appCertificate) {
    throw new Error(
      "AGORA_APP_ID and AGORA_APP_CERTIFICATE must be set in environment variables",
    );
  }

  const role = RtcRole.PUBLISHER;
  const tokenExpirationSeconds = 3600; // 1 hour
  const privilegeExpirationSeconds = 3600;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    role,
    tokenExpirationSeconds,
    privilegeExpirationSeconds,
  );

  return token;
}
