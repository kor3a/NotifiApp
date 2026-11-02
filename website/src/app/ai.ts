import { httpsCallable } from "firebase/functions";
import { functions } from "./firebase";

/**
 * Every AI call goes through the `openAIChat` Cloud Function, which holds the
 * OpenAI key server-side and requires a signed-in user — the same proxy
 * OpenAIService.swift uses. The prompts below are copied from that file so the
 * web and the apps behave alike.
 */
export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

const openAIChat = httpsCallable<
  { messages: ChatMessage[]; temperature: number; maxTokens: number },
  { content: string }
>(functions, "openAIChat");

async function chat(messages: ChatMessage[], temperature: number, maxTokens: number) {
  const { data } = await openAIChat({ messages, temperature, maxTokens });
  return data.content;
}

/** Models often wrap JSON in a code fence despite being told not to. */
function stripCodeFences(content: string) {
  let s = content.trim();
  if (!s.startsWith("```")) return s;
  s = s.slice(s.indexOf("\n") + 1);
  if (s.endsWith("```")) s = s.slice(0, -3);
  return s.trim();
}

export function recipeChat(history: ChatMessage[]) {
  return chat(
    [
      {
        role: "system",
        content:
          "You are a helpful recipe assistant. When users ask for recipes, provide clear, " +
          "well-formatted recipes with ingredients and step-by-step instructions. " +
          "Keep responses concise but complete. Use simple formatting with numbered steps " +
          "and bullet points for ingredients.",
      },
      ...history,
    ],
    0.7,
    1024,
  );
}

export async function extractIngredients(recipeText: string): Promise<string[]> {
  const content = await chat(
    [
      {
        role: "system",
        content:
          "Extract only the ingredient names from the recipe below. " +
          "Return a JSON array of short ingredient names suitable for a shopping list. " +
          'Simplify each ingredient to its core item (e.g. "2 cups all-purpose flour" becomes "All-purpose flour", ' +
          '"1/2 cup unsalted butter, melted" becomes "Unsalted butter"). ' +
          "Do not include quantities or preparation notes. " +
          "Return ONLY the JSON array, no other text.",
      },
      { role: "user", content: recipeText },
    ],
    0,
    512,
  );
  const parsed = JSON.parse(stripCodeFences(content));
  return Array.isArray(parsed) ? parsed.filter((x): x is string => typeof x === "string") : [];
}

export async function categorizeItems(items: string[]): Promise<Record<string, string>> {
  if (items.length === 0) return {};
  const content = await chat(
    [
      {
        role: "system",
        content:
          "You categorize shopping/reminder items into store aisle categories. " +
          "Given a JSON array of item names, return a JSON object mapping each item to exactly one category. " +
          "Use these categories when they fit: Produce, Dairy, Meat & Seafood, Bakery, Beverages, " +
          "Snacks, Frozen, Canned Goods, Condiments & Sauces, Grains & Pasta, Household, " +
          "Personal Care, Baby, Pet, Health, Electronics, Clothing, " +
          "Office & Stationery, Furniture, Hardware & Tools, Home & Kitchen, " +
          "Toys & Games, Sports & Outdoors, Automotive, Garden & Outdoor, Books & Media, Craft & Hobby. " +
          "These items are not limited to groceries — categorize everyday non-food items too " +
          '(e.g. "pencil" and "paper" are Office & Stationery, "desk" is Furniture, "screwdriver" is Hardware & Tools). ' +
          'Only map an item to "Uncategorized" as a last resort when it genuinely fits none of the categories above. ' +
          "Return ONLY the JSON object, no other text.",
      },
      { role: "user", content: JSON.stringify(items) },
    ],
    0,
    512,
  );
  const parsed = JSON.parse(stripCodeFences(content));
  return parsed && typeof parsed === "object" ? parsed : {};
}

/** The recipe's title: its first markdown heading, as SmartRecipeViewModel.extractRecipeName does. */
export function recipeNameFrom(content: string) {
  for (const line of content.split("\n")) {
    const m = line.trim().match(/^#{1,3}\s+(.+)$/);
    if (m) return m[1].replace(/\*\*/g, "").trim();
  }
  return "Smart Recipe";
}
