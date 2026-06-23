import { createServer } from "node:http";
import { connect as connectHttp2 } from "node:http2";
import { createSign, timingSafeEqual } from "node:crypto";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { resolve as resolvePath } from "node:path";

const PORT = Number.parseInt(process.env.PORT ?? "8787", 10);
const APNS_ENV = (process.env.APNS_ENV ?? "development").toLowerCase() === "production"
  ? "production"
  : "development";
const APNS_HOST = APNS_ENV === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

const APNS_TEAM_ID = (process.env.APNS_TEAM_ID ?? "").trim();
const APNS_KEY_ID = (process.env.APNS_KEY_ID ?? "").trim();
const APNS_PRIVATE_KEY = loadPrivateKey();
const APP_BUNDLE_ID = (process.env.APP_BUNDLE_ID ?? "").trim();
const RELAY_API_KEY = (process.env.RELAY_API_KEY ?? "").trim();
const REGISTRATION_STORE_PATH = resolvePath(
  process.cwd(),
  process.env.REGISTRATION_STORE_PATH ?? "data/registrations.json"
);
const parsedRegistrationMaxAgeSeconds = Number.parseInt(
  process.env.REGISTRATION_MAX_AGE_SECONDS ?? String(12 * 60 * 60),
  10
);
const REGISTRATION_MAX_AGE_SECONDS = Number.isFinite(parsedRegistrationMaxAgeSeconds)
  && parsedRegistrationMaxAgeSeconds > 0
  ? parsedRegistrationMaxAgeSeconds
  : 12 * 60 * 60;

if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_PRIVATE_KEY) {
  console.error("Missing APNs config. Set APNS_TEAM_ID, APNS_KEY_ID, and APNS_PRIVATE_KEY or APNS_PRIVATE_KEY_PATH.");
  process.exit(1);
}

const storeStatus = {
  path: REGISTRATION_STORE_PATH,
  loaded: false,
  loadError: null,
  lastPersistedAtUnix: null,
  lastPersistError: null,
  lastPrunedAtUnix: null,
  lastPrunedCount: 0
};
const registrations = loadRegistrationStore();
let lastApnsError = null;
let jwtCache = { token: "", expiresAtUnix: 0 };

const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 60;
const rateLimitMap = new Map();

function rateLimitMiddleware(req, res) {
  const ip = req.socket?.remoteAddress ?? "unknown";
  const now = Date.now();
  const entry = rateLimitMap.get(ip);

  if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(ip, { windowStart: now, count: 1 });
    return true;
  }

  entry.count += 1;
  if (entry.count > RATE_LIMIT_MAX) {
    sendJson(res, 429, { ok: false, error: "too_many_requests" });
    return false;
  }
  return true;
}

pruneStaleRegistrations("startup");

createServer(async (req, res) => {
  try {
    if (!rateLimitMiddleware(req, res)) {
      return;
    }
    if (!isAuthorized(req)) {
      sendJson(res, 401, { ok: false, error: "unauthorized" });
      return;
    }
    pruneStaleRegistrations(req.url ?? "request");

    if (req.method === "GET" && req.url === "/healthz") {
      sendJson(res, 200, {
        ok: true,
        env: APNS_ENV,
        registrations: registrations.size,
        persistentRegistrations: registrations.size,
        store: storeStatus,
        lastApnsError,
        time: new Date().toISOString()
      });
      return;
    }

    if (req.method === "POST" && req.url === "/api/live-activity/register") {
      const body = await readJsonBody(req);
      const activityId = asNonEmptyString(body.activityId);
      const sessionId = asNonEmptyString(body.sessionId);
      const pushToken = normalizePushToken(body.pushToken);
      const bundleId = asNonEmptyString(body.bundleId) ?? APP_BUNDLE_ID;

      if (!activityId || !sessionId || !pushToken || !bundleId) {
        sendJson(res, 400, { ok: false, error: "activityId, sessionId, pushToken, and bundleId are required" });
        return;
      }

      registrations.set(activityId, {
        activityId,
        sessionId,
        pushToken,
        bundleId,
        avatarAssetName: asNonEmptyString(body.avatarAssetName) ?? "",
        userDisplayName: asNonEmptyString(body.userDisplayName),
        sessionStartUnix: asUnixSecond(body.sessionStartUnix),
        updatedAtUnix: unixNow()
      });
      persistRegistrationStore();

      sendJson(res, 200, {
        ok: true,
        activityId,
        sessionId,
        bundleId,
        registeredAtUnix: unixNow()
      });
      return;
    }

    if (req.method === "POST" && req.url === "/api/live-activity/update") {
      const body = await readJsonBody(req);
      const activityId = asNonEmptyString(body.activityId);
      if (!activityId) {
        sendJson(res, 400, { ok: false, error: "activityId is required" });
        return;
      }

      const registration = registrations.get(activityId);
      if (!registration) {
        sendJson(res, 404, { ok: false, error: "activity not registered" });
        return;
      }

      const contentState = normalizeContentState(body.contentState);
      if (!contentState) {
        sendJson(res, 400, { ok: false, error: "contentState is required" });
        return;
      }

      registration.updatedAtUnix = unixNow();
      persistRegistrationStore();

      const apnsResponse = await pushLiveActivityEvent({
        pushToken: registration.pushToken,
        bundleId: registration.bundleId,
        event: "update",
        timestampUnix: asUnixSecond(body.sentAtUnix) ?? unixNow(),
        contentState,
        apnsPriority: asApnsPriority(body.apnsPriority),
        staleDateUnix: asUnixSecond(body.staleDateUnix),
        relevanceScore: asRelevanceScore(body.relevanceScore)
      });

      sendJson(res, 200, {
        ok: true,
        activityId,
        apnsStatus: apnsResponse.statusCode,
        apnsBody: apnsResponse.body
      });
      return;
    }

    if (req.method === "POST" && req.url === "/api/live-activity/end") {
      const body = await readJsonBody(req);
      const activityId = asNonEmptyString(body.activityId);
      if (!activityId) {
        sendJson(res, 400, { ok: false, error: "activityId is required" });
        return;
      }

      const registration = registrations.get(activityId);
      if (!registration) {
        sendJson(res, 404, { ok: false, error: "activity not registered" });
        return;
      }

      const finalState = normalizeContentState(body.finalState) ?? {
        postureStatus: "unknown",
        sessionScorePercent: 100,
        tiltDegrees: 0,
        leanDegrees: 0,
        elapsedSeconds: 0,
        isSessionPaused: false,
        lastUpdate: unixToSwiftReferenceDate(unixNow())
      };

      const immediate = Boolean(body.immediate);
      const endTimestamp = asUnixSecond(body.endedAtUnix) ?? unixNow();
      const dismissalDateUnix = immediate ? endTimestamp : endTimestamp + 60;

      const apnsResponse = await pushLiveActivityEvent({
        pushToken: registration.pushToken,
        bundleId: registration.bundleId,
        event: "end",
        timestampUnix: endTimestamp,
        contentState: finalState,
        dismissalDateUnix,
        apnsPriority: 10
      });

      registrations.delete(activityId);
      persistRegistrationStore();

      sendJson(res, 200, {
        ok: true,
        activityId,
        apnsStatus: apnsResponse.statusCode,
        apnsBody: apnsResponse.body
      });
      return;
    }

    sendJson(res, 404, { ok: false, error: "not_found" });
  } catch (error) {
    if (error instanceof RequestError) {
      sendJson(res, error.statusCode, { ok: false, error: error.message });
      return;
    }

    if (error instanceof ApnsError) {
      lastApnsError = {
        statusCode: error.statusCode,
        detail: error.detail,
        atUnix: unixNow()
      };
      sendJson(res, 502, {
        ok: false,
        error: "apns_error",
        statusCode: error.statusCode,
        detail: error.detail
      });
      return;
    }

    console.error("Unhandled relay error:", error);
    sendJson(res, 500, { ok: false, error: "internal_error" });
  }
}).listen(PORT, () => {
  console.log(`Live Activity relay listening on port ${PORT}`);
  console.log(`APNs environment: ${APNS_ENV}`);
});

function gracefulShutdown(signal) {
  console.log(`Received ${signal}, shutting down gracefully`);
  process.exit(0);
}

process.on("SIGTERM", gracefulShutdown);
process.on("SIGINT", gracefulShutdown);

function isAuthorized(req) {
  if (!RELAY_API_KEY) {
    return true;
  }

  const headerApiKey = asNonEmptyString(req.headers["x-relay-api-key"]);
  if (headerApiKey && timingSafeEqual(Buffer.from(headerApiKey), Buffer.from(RELAY_API_KEY))) {
    return true;
  }

  const bearerValue = parseBearerToken(req.headers.authorization);
  return bearerValue != null && timingSafeEqual(Buffer.from(bearerValue), Buffer.from(RELAY_API_KEY));
}

async function pushLiveActivityEvent({
  pushToken,
  bundleId,
  event,
  timestampUnix,
  contentState,
  dismissalDateUnix,
  apnsPriority = 10,
  staleDateUnix,
  relevanceScore
}) {
  const jwt = getApnsJwt();
  const payload = {
    aps: {
      timestamp: timestampUnix,
      event,
      "content-state": contentState
    }
  };

  if (typeof dismissalDateUnix === "number") {
    payload.aps["dismissal-date"] = dismissalDateUnix;
  }
  if (typeof staleDateUnix === "number") {
    payload.aps["stale-date"] = staleDateUnix;
  }
  if (typeof relevanceScore === "number") {
    payload.aps["relevance-score"] = relevanceScore;
  }

  return await sendApnsRequest({
    pushToken,
    bundleId,
    jwt,
    payload,
    apnsPriority
  });
}

function sendApnsRequest({ pushToken, bundleId, jwt, payload, apnsPriority }) {
  return new Promise((resolve, reject) => {
    const client = connectHttp2(APNS_HOST);
    const request = client.request({
      ":method": "POST",
      ":path": `/3/device/${pushToken}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": `${bundleId}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": String(apnsPriority)
    });

    let statusCode = 0;
    let responseText = "";
    request.setEncoding("utf8");

    request.on("response", (headers) => {
      statusCode = Number.parseInt(String(headers[":status"] ?? "0"), 10);
    });

    request.on("data", (chunk) => {
      responseText += chunk;
    });

    request.on("end", () => {
      safeClose(client);
      const parsedBody = parseJsonSafe(responseText) ?? {};
      if (statusCode >= 200 && statusCode < 300) {
        resolve({ statusCode, body: parsedBody });
      } else {
        reject(new ApnsError(statusCode, parsedBody));
      }
    });

    request.on("error", (error) => {
      safeClose(client);
      reject(error);
    });

    client.on("error", (error) => {
      safeClose(client);
      reject(error);
    });

    request.write(JSON.stringify(payload));
    request.end();
  });
}

function getApnsJwt() {
  const now = unixNow();
  if (jwtCache.token && now < jwtCache.expiresAtUnix) {
    return jwtCache.token;
  }

  const header = { alg: "ES256", kid: APNS_KEY_ID, typ: "JWT" };
  const payload = { iss: APNS_TEAM_ID, iat: now };
  const encodedHeader = base64urlJson(header);
  const encodedPayload = base64urlJson(payload);
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signer = createSign("sha256");
  signer.update(signingInput);
  signer.end();
  const signature = signer.sign(APNS_PRIVATE_KEY, "base64url");
  const token = `${signingInput}.${signature}`;

  jwtCache = {
    token,
    expiresAtUnix: now + (50 * 60)
  };

  return token;
}

function loadRegistrationStore() {
  try {
    const raw = readFileSync(REGISTRATION_STORE_PATH, "utf8");
    const parsed = parseJsonSafe(raw);
    const entries = Array.isArray(parsed?.registrations) ? parsed.registrations : [];
    const restored = new Map();

    for (const entry of entries) {
      const registration = normalizeStoredRegistration(entry);
      if (registration) {
        restored.set(registration.activityId, registration);
      }
    }

    storeStatus.loaded = true;
    storeStatus.loadError = null;
    console.log(`Loaded ${restored.size} Live Activity registrations from ${REGISTRATION_STORE_PATH}`);
    return restored;
  } catch (error) {
    if (error && error.code === "ENOENT") {
      storeStatus.loaded = true;
      storeStatus.loadError = null;
      return new Map();
    }

    storeStatus.loaded = false;
    storeStatus.loadError = String(error?.message ?? error);
    console.error(`Failed to load registration store ${REGISTRATION_STORE_PATH}:`, error);
    return new Map();
  }
}

function persistRegistrationStore() {
  try {
    mkdirSync(resolvePath(REGISTRATION_STORE_PATH, ".."), { recursive: true });
    const payload = {
      version: 1,
      savedAtUnix: unixNow(),
      registrations: [...registrations.values()]
    };
    const tempPath = `${REGISTRATION_STORE_PATH}.tmp`;
    writeFileSync(tempPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    renameSync(tempPath, REGISTRATION_STORE_PATH);
    storeStatus.lastPersistedAtUnix = payload.savedAtUnix;
    storeStatus.lastPersistError = null;
  } catch (error) {
    storeStatus.lastPersistError = String(error?.message ?? error);
    console.error(`Failed to persist registration store ${REGISTRATION_STORE_PATH}:`, error);
  }
}

function pruneStaleRegistrations(reason) {
  const now = unixNow();
  let prunedCount = 0;

  for (const [activityId, registration] of registrations) {
    const updatedAtUnix = asUnixSecond(registration.updatedAtUnix) ?? 0;
    if (updatedAtUnix > 0 && now - updatedAtUnix <= REGISTRATION_MAX_AGE_SECONDS) {
      continue;
    }

    registrations.delete(activityId);
    prunedCount += 1;
  }

  storeStatus.lastPrunedAtUnix = now;
  storeStatus.lastPrunedCount = prunedCount;

  if (prunedCount > 0) {
    console.log(`Pruned ${prunedCount} stale Live Activity registrations (${reason})`);
    persistRegistrationStore();
  }
}

function normalizeStoredRegistration(input) {
  if (!input || typeof input !== "object") {
    return null;
  }

  const activityId = asNonEmptyString(input.activityId);
  const sessionId = asNonEmptyString(input.sessionId);
  const pushToken = normalizePushToken(input.pushToken);
  const bundleId = asNonEmptyString(input.bundleId);
  const updatedAtUnix = asUnixSecond(input.updatedAtUnix);

  if (!activityId || !sessionId || !pushToken || !bundleId || !updatedAtUnix) {
    return null;
  }

  return {
    activityId,
    sessionId,
    pushToken,
    bundleId,
    avatarAssetName: asNonEmptyString(input.avatarAssetName) ?? "",
    userDisplayName: asNonEmptyString(input.userDisplayName),
    sessionStartUnix: asUnixSecond(input.sessionStartUnix),
    updatedAtUnix
  };
}

function loadPrivateKey() {
  const inlineKey = asNonEmptyString(process.env.APNS_PRIVATE_KEY);
  if (inlineKey) {
    return inlineKey.replaceAll("\\n", "\n");
  }

  const keyPath = asNonEmptyString(process.env.APNS_PRIVATE_KEY_PATH);
  if (!keyPath) {
    return "";
  }

  try {
    return readFileSync(resolvePath(process.cwd(), keyPath), "utf8");
  } catch (error) {
    console.error(`Failed to read APNS private key from ${keyPath}:`, error);
    return "";
  }
}

async function readJsonBody(req) {
  let rawBody = "";
  for await (const chunk of req) {
    rawBody += chunk;
    if (rawBody.length > 1_000_000) {
      throw new RequestError(413, "payload_too_large");
    }
  }

  if (!rawBody.trim()) {
    return {};
  }

  const parsed = parseJsonSafe(rawBody);
  if (!parsed || typeof parsed !== "object") {
    throw new RequestError(400, "invalid_json");
  }
  return parsed;
}

function normalizeContentState(input) {
  if (!input || typeof input !== "object") {
    return null;
  }

  const rawStatus = asNonEmptyString(input.postureStatus);
  const postureStatus = rawStatus === "good" || rawStatus === "poor" || rawStatus === "unknown"
    ? rawStatus
    : "unknown";
  const lastUpdateUnix = asUnixSecond(input.lastUpdateUnix) ?? unixNow();
  const lastUpdate = asNumber(input.lastUpdate) ?? unixToSwiftReferenceDate(lastUpdateUnix);

  return {
    postureStatus,
    sessionScorePercent: clamp(asNumber(input.sessionScorePercent) ?? 100, 0, 100),
    tiltDegrees: asNumber(input.tiltDegrees) ?? 0,
    leanDegrees: asNumber(input.leanDegrees) ?? 0,
    elapsedSeconds: Math.max(0, Math.floor(asNumber(input.elapsedSeconds) ?? 0)),
    isSessionPaused: Boolean(input.isSessionPaused),
    lastUpdate
  };
}

function normalizePushToken(value) {
  const token = asNonEmptyString(value);
  if (!token) {
    return null;
  }
  return token.toLowerCase().replaceAll(/\s+/g, "");
}

function parseBearerToken(rawAuthorization) {
  const value = asNonEmptyString(rawAuthorization);
  if (!value) {
    return null;
  }
  const parts = value.split(" ");
  if (parts.length !== 2 || parts[0].toLowerCase() !== "bearer") {
    return null;
  }
  return parts[1];
}

function base64urlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(body)
  });
  res.end(body);
}

function parseJsonSafe(raw) {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function asNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim()) {
    const numeric = Number(value);
    if (Number.isFinite(numeric)) {
      return numeric;
    }
  }
  return null;
}

function asUnixSecond(value) {
  const numeric = asNumber(value);
  if (numeric === null) {
    return null;
  }
  return Math.max(0, Math.floor(numeric));
}

function asApnsPriority(value) {
  const numeric = asNumber(value);
  return numeric === 5 ? 5 : 10;
}

function asRelevanceScore(value) {
  const numeric = asNumber(value);
  if (numeric === null) {
    return null;
  }

  return clamp(numeric, 0, 100);
}

function asNonEmptyString(value) {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed ? trimmed : null;
  }
  return null;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function unixNow() {
  return Math.floor(Date.now() / 1000);
}

function unixToSwiftReferenceDate(unixSeconds) {
  return unixSeconds - 978307200;
}

function safeClose(client) {
  try {
    client.close();
  } catch {
    // no-op
  }
}

class RequestError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

class ApnsError extends Error {
  constructor(statusCode, detail) {
    super("APNs request failed");
    this.statusCode = statusCode;
    this.detail = detail;
  }
}
