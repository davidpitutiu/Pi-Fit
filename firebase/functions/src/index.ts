import {initializeApp} from "firebase-admin/app";
import {getAppCheck} from "firebase-admin/app-check";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {defineBoolean, defineSecret, defineString} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import {coachInstructions, createCoachHandler, providerConversation} from "./handler";
import {checkLimit, extractReply} from "./validation";

initializeApp();
const openAiKey = defineSecret("OPENAI_API_KEY");
const model = defineString("AI_MODEL", {default: "gpt-4.1"});
const allowedOrigins = defineString("ALLOWED_ORIGINS", {default: ""});
const requireAppCheck = defineBoolean("REQUIRE_APP_CHECK", {default: false});

export const coach = onRequest({
  region: "europe-west1",
  secrets: [openAiKey],
  timeoutSeconds: 60,
  memory: "256MiB",
  maxInstances: 5,
  concurrency: 20,
  cors: false,
}, createCoachHandler({
  allowedOrigins: () => allowedOrigins.value(),
  requireAppCheck: () => requireAppCheck.value(),
  authenticate: async (token) => {
    const identity = await getAuth().verifyIdToken(token, true);
    return {uid: identity.uid, anonymous: identity.firebase?.sign_in_provider === "anonymous"};
  },
  verifyAppCheck: async (token) => {
    await getAppCheck().verifyToken(token);
  },
  consumeLimit: async (uid) => {
    const database = getFirestore();
    const limitRef = database.doc(`_coachRateLimits/${uid}`);
    return database.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(limitRef);
      const limit = checkLimit(snapshot.data() ?? {}, Date.now());
      if (!limit.allowed) return false;
      transaction.set(limitRef, limit.next);
      return true;
    });
  },
  askProvider: async (input) => {
    const upstream = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: model.value(),
        store: false,
        max_output_tokens: 1800,
        instructions: coachInstructions,
        input: providerConversation(input),
      }),
      signal: AbortSignal.timeout(35_000),
    });
    if (!upstream.ok) {
      logger.warn("AI provider request failed", {status: upstream.status});
      return null;
    }
    return extractReply(await upstream.json());
  },
  logFailure: () => {
    // Neither credentials nor profile/workout messages are logged.
    logger.error("Coach request could not be completed");
  },
}));
