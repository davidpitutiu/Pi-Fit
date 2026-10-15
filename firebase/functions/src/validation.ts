export interface CoachInput {
  message: string;
  context: string;
  history: CoachTurn[];
}

export interface CoachTurn {
  role: "user" | "assistant";
  content: string;
}

export function validateInput(body: unknown): CoachInput | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const candidate = body as Record<string, unknown>;
  if (Object.keys(candidate).some((key) => !["message", "context", "history"].includes(key))) {
    return null;
  }
  if (typeof candidate.message !== "string" || typeof candidate.context !== "string") {
    return null;
  }
  const message = candidate.message.trim();
  if (!message || message.length > 3000 || candidate.context.length > 24000) {
    return null;
  }
  const turns = candidate.history === undefined ? [] : candidate.history;
  if (!Array.isArray(turns) || turns.length > 12) return null;
  const history: CoachTurn[] = [];
  let totalLength = 0;
  for (const turn of turns) {
    if (!turn || typeof turn !== "object" || Array.isArray(turn) ||
      Object.keys(turn).some((key) => key !== "role" && key !== "content") ||
      (turn.role !== "user" && turn.role !== "assistant") ||
      typeof turn.content !== "string" || !turn.content.trim() ||
      turn.content.length > 3000) return null;
    totalLength += turn.content.length;
    if (totalLength > 18000) return null;
    history.push({role: turn.role, content: turn.content.trim()});
  }
  return {message, context: candidate.context, history};
}

export function extractReply(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const output = (body as Record<string, unknown>).output;
  if (!Array.isArray(output)) return null;
  const texts: string[] = [];
  for (const item of output) {
    if (!item || typeof item !== "object" || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (content?.type === "output_text" && typeof content.text === "string") {
        texts.push(content.text);
      }
    }
  }
  return texts.join("\n").trim() || null;
}

export function checkLimit(
  data: Record<string, unknown>,
  now: number,
): {allowed: boolean; next: Record<string, number>} {
  const minuteStart = typeof data.minuteStart === "number" ? data.minuteStart : 0;
  const dayStart = typeof data.dayStart === "number" ? data.dayStart : 0;
  const minuteCount = now - minuteStart < 60_000 && typeof data.minuteCount === "number"
    ? data.minuteCount : 0;
  const dayCount = now - dayStart < 86_400_000 && typeof data.dayCount === "number"
    ? data.dayCount : 0;
  return {
    allowed: minuteCount < 10 && dayCount < 100,
    next: {
      minuteStart: now - minuteStart < 60_000 ? minuteStart : now,
      dayStart: now - dayStart < 86_400_000 ? dayStart : now,
      minuteCount: minuteCount + 1,
      dayCount: dayCount + 1,
    },
  };
}
