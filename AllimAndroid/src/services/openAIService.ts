import functions from '@react-native-firebase/functions';

// Every completion goes through the authenticated `openAIChat` Cloud Function,
// which holds the OpenAI key server-side — the same proxy, prompts and limits
// the iOS OpenAIService uses. No key ships inside the APK.

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

const RECIPE_SYSTEM_PROMPT =
  'You are a helpful recipe assistant. When users ask for recipes, provide clear, ' +
  'well-formatted recipes with ingredients and step-by-step instructions. ' +
  'Keep responses concise but complete. Use simple formatting with numbered steps ' +
  'and bullet points for ingredients.';

const EXTRACT_PROMPT =
  'Extract only the ingredient names from the recipe below. ' +
  'Return a JSON array of short ingredient names suitable for a shopping list. ' +
  'Simplify each ingredient to its core item (e.g. "2 cups all-purpose flour" becomes "All-purpose flour", ' +
  '"1/2 cup unsalted butter, melted" becomes "Unsalted butter"). ' +
  'Do not include quantities or preparation notes. ' +
  'Return ONLY the JSON array, no other text.';

const CATEGORIZE_PROMPT =
  'You categorize shopping/reminder items into store aisle categories. ' +
  'Given a JSON array of item names, return a JSON object mapping each item to exactly one category. ' +
  'Use these categories when they fit: Produce, Dairy, Meat & Seafood, Bakery, Beverages, ' +
  'Snacks, Frozen, Canned Goods, Condiments & Sauces, Grains & Pasta, Household, ' +
  'Personal Care, Baby, Pet, Health, Electronics, Clothing, ' +
  'Office & Stationery, Furniture, Hardware & Tools, Home & Kitchen, ' +
  'Toys & Games, Sports & Outdoors, Automotive, Garden & Outdoor, Books & Media, Craft & Hobby. ' +
  'These items are not limited to groceries — categorize everyday non-food items too ' +
  '(e.g. "pencil" and "paper" are Office & Stationery, "desk" is Furniture, "screwdriver" is Hardware & Tools). ' +
  'Only map an item to "Uncategorized" as a last resort when it genuinely fits none of the categories above. ' +
  'Return ONLY the JSON object, no other text.';

async function chat(
  messages: ChatMessage[],
  temperature: number,
  maxTokens: number,
): Promise<string> {
  let data: any;
  try {
    const result = await functions().httpsCallable('openAIChat')({
      messages,
      temperature,
      maxTokens,
    });
    data = result.data;
  } catch {
    throw new Error('Network error occurred');
  }
  if (!data || typeof data.content !== 'string') {
    throw new Error('Invalid response from OpenAI');
  }
  return data.content;
}

// Models often wrap JSON replies in a markdown code fence despite being told
// not to. Strip it so the payload parses.
function stripCodeFences(content: string): string {
  let cleaned = content.trim();
  if (!cleaned.startsWith('```')) {
    return cleaned;
  }
  const firstNewline = cleaned.indexOf('\n');
  if (firstNewline >= 0) {
    cleaned = cleaned.slice(firstNewline + 1);
  }
  if (cleaned.endsWith('```')) {
    cleaned = cleaned.slice(0, -3);
  }
  return cleaned.trim();
}

export const openAIService = {
  // One turn of the Smart Recipe conversation.
  async sendRecipeMessage(messages: ChatMessage[]): Promise<string> {
    return chat(
      [{role: 'system', content: RECIPE_SYSTEM_PROMPT}, ...messages],
      0.7,
      1024,
    );
  },

  async extractIngredients(recipeText: string): Promise<string[]> {
    const content = await chat(
      [
        {role: 'system', content: EXTRACT_PROMPT},
        {role: 'user', content: recipeText},
      ],
      0,
      512,
    );
    const parsed = JSON.parse(stripCodeFences(content));
    if (!Array.isArray(parsed)) {
      throw new Error('Invalid response from OpenAI');
    }
    return parsed.filter((i): i is string => typeof i === 'string');
  },

  // Maps each item title to an aisle category; "Uncategorized" when the model
  // could not place it.
  async categorizeItems(items: string[]): Promise<Record<string, string>> {
    if (items.length === 0) {
      return {};
    }
    const content = await chat(
      [
        {role: 'system', content: CATEGORIZE_PROMPT},
        {role: 'user', content: JSON.stringify(items)},
      ],
      0,
      512,
    );
    const parsed = JSON.parse(stripCodeFences(content));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('Invalid response from OpenAI');
    }
    return parsed;
  },
};
