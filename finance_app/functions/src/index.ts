import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

// ── Secret declaration ───────────────────────────────────────────────────────
// Declaring the secret here causes Firebase to inject it at runtime.
// The value is NEVER hardcoded or stored in source control.

const geminiApiKey = defineSecret("GEMINI_API_KEY");

// ── Constants ────────────────────────────────────────────────────────────────

const BLOCKED_KEYWORDS = [
  "stock", "stocks", "share", "shares", "invest", "investment",
  "crypto", "bitcoin", "tax", "legal", "medical", "gambling",
  "loan application", "insurance advice",
];

const DEFAULT_SUGGESTIONS = [
  "How much did I spend this month?",
  "Am I over budget?",
  "Any subscriptions I should review?",
];

const SYSTEM_INSTRUCTION =
  "You are an AI assistant inside a personal finance tracking app. " +
  "You may only answer using the provided financial context. " +
  "You can help with budgeting, spending, savings goals, debts/PTPTN, " +
  "subscriptions, invisible expenses, and monthly summaries. " +
  "Do not give investment, stock, crypto, tax, legal, medical, or insurance advice. " +
  "Keep answers simple, practical, and based on the user's app data. " +
  "If data is missing, say what information is missing. " +
  "Always prefix monetary amounts with the currency code supplied in the context. " +
  "Format monetary values to two decimal places. Example: MYR 399.00. " +
  "Never return a bare amount such as 399. " +
  "Return plain text only. " +
  "Do not use Markdown. " +
  "Do not use bold, headings, tables, or code blocks. " +
  "Every answer must end with the disclaimer: " +
  '"This is general financial guidance only, not professional financial advice."';

// ── financialAssistant endpoint ──────────────────────────────────────────────

export const financialAssistant = onRequest(
  { secrets: [geminiApiKey] },
  async (req, res) => {
    // CORS — allow local Flutter web testing and deployed origins
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    // Retrieve secret value — available because of { secrets: [geminiApiKey] }
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      res.status(500).json({
        reply: "AI service is not configured yet.",
        suggestions: DEFAULT_SUGGESTIONS,
      });
      return;
    }

    const { message, context } = req.body as {
      message?: string;
      context?: Record<string, unknown>;
      safetyRules?: string[];
    };

    const userMessage = (message ?? "").trim();

    // Server-side guardrails — block before calling Gemini
    const lower = userMessage.toLowerCase();
    const isBlocked = BLOCKED_KEYWORDS.some((kw) => lower.includes(kw));
    if (isBlocked) {
      res.status(200).json({
        reply:
          "I can only help with your personal finance tracking data in this app, " +
          "such as budgeting, spending, savings, debts, and subscriptions.\n\n" +
          "This is general financial guidance only, not professional financial advice.",
        suggestions: DEFAULT_SUGGESTIONS,
      });
      return;
    }

    const contextStr = context
      ? JSON.stringify(context, null, 2)
      : "No financial context provided.";

    const userPrompt =
      `Financial Context:\n${contextStr}\n\n` +
      `User Question: ${userMessage}\n\n` +
      "Answer the question directly using 1 or 2 short paragraphs. " +
      "Include actual values from the financial context when available. " +
      "Do not repeat the question. " +
      "Do not begin with phrases such as \"Based on your financial data\". " +
      "End with exactly: " +
      "This is general financial guidance only, not professional financial advice.";

    try {
      const geminiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/" +
        `gemini-3.5-flash:generateContent?key=${apiKey}`;

      const geminiRes = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          system_instruction: {
            parts: [{ text: SYSTEM_INSTRUCTION }],
          },
          contents: [
            {
              role: "user",
              parts: [{ text: userPrompt }],
            },
          ],
          generationConfig: {
            maxOutputTokens: 1024,
            temperature: 0.4,
          },
        }),
      });

      if (!geminiRes.ok) {
        const errorBody = await geminiRes.text();
        console.error(
          `Gemini API error ${geminiRes.status}: ${errorBody}`,
        );
        throw new Error(
          `Gemini API responded with status ${geminiRes.status}`,
        );
      }

      const geminiData = (await geminiRes.json()) as {
        candidates?: Array<{
          content?: { parts?: Array<{ text?: string }> };
          finishReason?: string;
        }>;
        usageMetadata?: {
          promptTokenCount?: number;
          candidatesTokenCount?: number;
          totalTokenCount?: number;
        };
      };

      const candidate = geminiData?.candidates?.[0];

      // Diagnostic logging — never logs API key or financial values
      const finishReason = candidate?.finishReason ?? "UNKNOWN";
      if (finishReason === "MAX_TOKENS") {
        console.error("Gemini response ended because of output token limit.");
      } else {
        console.log(`Gemini finishReason: ${finishReason}`);
      }
      const usage = geminiData?.usageMetadata;
      if (usage) {
        console.log(
          `Gemini token usage: prompt=${usage.promptTokenCount ?? 0}` +
          ` output=${usage.candidatesTokenCount ?? 0}` +
          ` total=${usage.totalTokenCount ?? 0}`,
        );
      }

      // Collect all text parts from the first candidate and join them
      const allParts = candidate?.content?.parts ?? [];
      const combinedText = allParts
        .map((p) => p.text ?? "")
        .join("")
        .trim();

      const DISCLAIMER =
        "This is general financial guidance only, not professional financial advice.";

      let reply: string;
      if (combinedText.length === 0) {
        // All parts were empty — use safe fallback
        reply = "Sorry, I could not generate an AI response right now. Please try again later.";
      } else if (combinedText.includes(DISCLAIMER)) {
        // Gemini already included the disclaimer — do not append again
        reply = combinedText;
      } else {
        // Disclaimer missing (e.g. truncated) — append it once
        reply = `${combinedText}\n\n${DISCLAIMER}`;
      }

      res.status(200).json({ reply, suggestions: DEFAULT_SUGGESTIONS });
    } catch (err) {
      console.error("Gemini call failed:", err);
      res.status(200).json({
        reply:
          "Sorry, I could not generate an AI response right now. " +
          "Please try again later.",
        suggestions: DEFAULT_SUGGESTIONS,
      });
    }
  }
);
