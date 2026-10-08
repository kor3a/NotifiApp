import React, {useEffect, useRef, useState} from 'react';
import {
  View,
  Text,
  TextInput,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Animated,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import {Spacing, textPrimary, textSecondary, sheetFill} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {openAIService} from '../../services/openAIService';
import {recipeService} from '../../services/recipeService';
import {storeService} from '../../services/storeService';
import {UserStoreItem} from '../../models';
import MarkdownText from './MarkdownText';
import StorePickerSheet from './StorePickerSheet';
import {RecipeBackdrop, RecipePalette} from './recipeTheme';

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  ingredients?: string[];
}

type IconName = React.ComponentProps<typeof Icon>['name'];

const SUGGESTIONS: {text: string; icon: IconName}[] = [
  {text: 'Quick weeknight pasta dinner', icon: 'timer-outline'},
  {text: 'Healthy breakfast smoothie bowl', icon: 'leaf'},
  {text: 'Easy chocolate chip cookies', icon: 'ice-cream'},
];

let nextId = 0;
const newId = () => `m${Date.now()}-${nextId++}`;

// The heading the assistant opened its recipe with, as the saved recipe's name.
function recipeNameFrom(content: string): string {
  for (const line of content.split('\n')) {
    const match = /^#{1,3}\s+(.+)$/.exec(line.trim());
    if (match) {
      return match[1].trim();
    }
  }
  return 'Smart Recipe';
}

// The AI Recipe tab — the iOS SmartRecipeView. A recipe chat that turns any
// answer into a shopping list: send its ingredients to a store, or keep them
// as a saved recipe. A premium feature, as on iOS.
export default function SmartRecipeScreen() {
  const scheme = useColorScheme();
  const {currentUser} = useSession();
  const isPremium = !!(currentUser?.isSubscribed || currentUser?.adminSubscribed);

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [stores, setStores] = useState<UserStoreItem[]>([]);
  const [pickerMessageId, setPickerMessageId] = useState<string | null>(null);

  // Bumped by New Chat, so a reply still in flight from the old one is dropped.
  const chatToken = useRef(0);
  const scrollRef = useRef<ScrollView>(null);

  useEffect(() => {
    if (!currentUser || !isPremium) {return;}
    return storeService.subscribeToUserStores(
      currentUser.userId,
      currentUser.email,
      setStores,
    );
  }, [currentUser, isPremium]);

  async function send(text: string) {
    const trimmed = text.trim();
    if (!trimmed || isLoading) {return;}

    const token = chatToken.current;
    const history = [...messages, {id: newId(), role: 'user' as const, content: trimmed}];
    setMessages(history);
    setInput('');
    setError(null);
    setIsLoading(true);

    try {
      const reply = await openAIService.sendRecipeMessage(
        history.map(m => ({role: m.role, content: m.content})),
      );
      if (chatToken.current !== token) {return;}
      const assistant: ChatMessage = {id: newId(), role: 'assistant', content: reply};
      setMessages(list => [...list, assistant]);
      setIsLoading(false);

      // Ingredients come in a second call; the buttons appear once they land.
      const ingredients = await openAIService.extractIngredients(reply).catch(() => []);
      if (chatToken.current !== token || ingredients.length === 0) {return;}
      setMessages(list =>
        list.map(m => (m.id === assistant.id ? {...m, ingredients} : m)),
      );
    } catch (err: any) {
      if (chatToken.current !== token) {return;}
      setError(err?.message ?? 'Something went wrong.');
      setIsLoading(false);
    }
  }

  function startNewChat() {
    chatToken.current++;
    setMessages([]);
    setInput('');
    setIsLoading(false);
    setIsSaving(false);
    setError(null);
    setNotice(null);
  }

  async function addToStore(item: UserStoreItem) {
    const message = messages.find(m => m.id === pickerMessageId);
    setPickerMessageId(null);
    if (!message?.ingredients || !currentUser) {return;}
    setIsSaving(true);
    setNotice(null);
    try {
      const count = await recipeService.addIngredientsToStore(
        message.ingredients,
        item,
        currentUser,
        {categorize: true},
      );
      if (count === 0) {
        setError('All ingredients already exist in this store');
      } else {
        setNotice(`Added ${count} ingredient${count === 1 ? '' : 's'} to ${item.store.name}`);
      }
    } catch (err: any) {
      setError(`Failed to add ingredients: ${err?.message ?? 'unknown error'}`);
    } finally {
      setIsSaving(false);
    }
  }

  async function addToRecipes(message: ChatMessage) {
    if (!message.ingredients || !currentUser) {return;}
    const name = recipeNameFrom(message.content);
    setIsSaving(true);
    setNotice(null);
    try {
      await recipeService.addRecipe(currentUser, name, message.ingredients);
      setNotice(`"${name}" saved to your recipe list`);
    } catch (err: any) {
      setError(`Failed to save recipe: ${err?.message ?? 'unknown error'}`);
    } finally {
      setIsSaving(false);
    }
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  const accent = RecipePalette.paprika(scheme);

  const header = (
    <View style={[styles.header, {borderBottomColor: RecipePalette.hairline(scheme)}]}>
      <View style={styles.headerSide} />
      <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>Smart Recipe</Text>
      <View style={[styles.headerSide, {alignItems: 'flex-end'}]}>
        {isPremium && messages.length > 0 && (
          <TouchableOpacity onPress={startNewChat} accessibilityLabel="New chat">
            <Icon name="create-outline" size={24} color={accent} />
          </TouchableOpacity>
        )}
      </View>
    </View>
  );

  // ─── Locked ───────────────────────────────────────────────────────────────

  if (!isPremium) {
    return (
      <View style={{flex: 1}}>
        <RecipeBackdrop scheme={scheme} extraScrim={0.2} />
        <SafeAreaView style={{flex: 1}} edges={['top']}>
          {header}
          <View style={styles.locked}>
            <View style={[styles.lockedIcon, {backgroundColor: accent}]}>
              <Icon name="restaurant" size={34} color={RecipePalette.onAccent} />
            </View>
            <Text style={[styles.welcomeTitle, {color: textPrimary(scheme)}]}>
              Smart Recipe
            </Text>
            <Text style={[styles.welcomeText, {color: textSecondary(scheme)}]}>
              Ask for any recipe and Allim turns it into a shopping list — the
              ingredients sorted straight into the store you pick.
            </Text>
            <View style={[styles.premiumBadge, {backgroundColor: accent + '22'}]}>
              <Icon name="star" size={14} color={accent} />
              <Text style={[styles.premiumText, {color: accent}]}>
                Included with Allim Premium
              </Text>
            </View>
          </View>
        </SafeAreaView>
      </View>
    );
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────

  const surface = {
    backgroundColor: RecipePalette.surface(scheme),
    borderColor: RecipePalette.surfaceBorder(scheme),
  };
  const sendDisabled = !input.trim() || isLoading;

  return (
    <View style={{flex: 1}}>
      <RecipeBackdrop scheme={scheme} />
      <SafeAreaView style={{flex: 1}} edges={['top']}>
        {header}
        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            ref={scrollRef}
            contentContainerStyle={styles.conversation}
            keyboardShouldPersistTaps="handled"
            onContentSizeChange={() => scrollRef.current?.scrollToEnd({animated: true})}>
            {messages.length === 0 && (
              <View style={styles.welcome}>
                <View style={[styles.welcomeIcon, {backgroundColor: accent}]}>
                  <Icon name="restaurant" size={36} color={RecipePalette.onAccent} />
                </View>
                <Text style={[styles.welcomeTitle, {color: textPrimary(scheme)}]}>
                  Smart Recipe
                </Text>
                <Text style={[styles.welcomeText, {color: textSecondary(scheme)}]}>
                  Ask for any recipe — meal ideas, step-by-step instructions,
                  ingredient swaps — then send the ingredients straight to a store
                  list.
                </Text>
                <View style={styles.suggestions}>
                  {SUGGESTIONS.map(s => (
                    <TouchableOpacity
                      key={s.text}
                      style={[styles.suggestion, surface]}
                      onPress={() => send(s.text)}
                      activeOpacity={0.8}>
                      <View
                        style={[
                          styles.suggestionIcon,
                          {backgroundColor: RecipePalette.apricot(scheme) + '2E'},
                        ]}>
                        <Icon name={s.icon} size={15} color={accent} />
                      </View>
                      <Text style={[styles.suggestionText, {color: textPrimary(scheme)}]}>
                        {s.text}
                      </Text>
                      <Icon name="arrow-up-outline" size={13} color={textSecondary(scheme)} style={styles.suggestionArrow} />
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            )}

            {messages.map(message =>
              message.role === 'user' ? (
                <View key={message.id} style={styles.userRow}>
                  <View style={[styles.userBubble, {backgroundColor: accent}]}>
                    <Text style={styles.userText}>{message.content}</Text>
                  </View>
                </View>
              ) : (
                <View key={message.id}>
                  <View style={styles.assistantRow}>
                    <AssistantAvatar color={accent} />
                    <View style={[styles.assistantBubble, surface]}>
                      <MarkdownText text={message.content} color={textPrimary(scheme)} />
                    </View>
                  </View>
                  {!!message.ingredients?.length && (
                    <View style={[styles.actions, isSaving && styles.actionsBusy]}>
                      <ActionButton
                        title="Add to Store"
                        icon="cart"
                        color={accent}
                        disabled={isSaving}
                        onPress={() => setPickerMessageId(message.id)}
                      />
                      <ActionButton
                        title="Add to Recipes"
                        icon="list"
                        color={RecipePalette.basil(scheme)}
                        disabled={isSaving}
                        onPress={() => addToRecipes(message)}
                      />
                    </View>
                  )}
                </View>
              ),
            )}

            {isLoading && (
              <View style={styles.assistantRow}>
                <AssistantAvatar color={accent} />
                <View style={[styles.assistantBubble, styles.typingBubble, surface]}>
                  <TypingIndicator color={accent} />
                </View>
              </View>
            )}
          </ScrollView>

          {(error || notice) && (
            <View style={styles.banners}>
              {error && (
                <Banner
                  icon="warning"
                  tint={RecipePalette.apricot(scheme)}
                  text={error}
                  textColor={textPrimary(scheme)}
                  surface={surface}
                  onDismiss={() => setError(null)}
                />
              )}
              {notice && (
                <Banner
                  icon="checkmark-circle"
                  tint={RecipePalette.basil(scheme)}
                  text={notice}
                  textColor={textPrimary(scheme)}
                  surface={surface}
                  onDismiss={() => setNotice(null)}
                />
              )}
            </View>
          )}

          <View
            style={[
              styles.inputBar,
              {
                backgroundColor: RecipePalette.surface(scheme),
                borderTopColor: RecipePalette.hairline(scheme),
              },
            ]}>
            <TextInput
              value={input}
              onChangeText={setInput}
              placeholder="Ask for a recipe..."
              placeholderTextColor={textSecondary(scheme)}
              style={[styles.input, surface, {color: textPrimary(scheme)}]}
              multiline
              maxLength={2000}
            />
            <TouchableOpacity
              onPress={() => send(input)}
              disabled={sendDisabled}
              style={[
                styles.sendBtn,
                {backgroundColor: sendDisabled ? sheetFill(scheme) : accent},
              ]}
              accessibilityLabel="Send">
              <Icon
                name="arrow-up"
                size={20}
                color={sendDisabled ? textSecondary(scheme) : RecipePalette.onAccent}
              />
            </TouchableOpacity>
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>

      <StorePickerSheet
        visible={!!pickerMessageId}
        stores={stores}
        onSelect={addToStore}
        onClose={() => setPickerMessageId(null)}
      />
    </View>
  );
}

// ─── Pieces ──────────────────────────────────────────────────────────────────

function AssistantAvatar({color}: {color: string}) {
  return (
    <View style={[styles.avatar, {backgroundColor: color}]}>
      <Icon name="restaurant" size={12} color={RecipePalette.onAccent} />
    </View>
  );
}

function ActionButton({
  title,
  icon,
  color,
  disabled,
  onPress,
}: {
  title: string;
  icon: IconName;
  color: string;
  disabled: boolean;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity
      style={[styles.actionBtn, {backgroundColor: color}]}
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.85}>
      <Icon name={icon} size={14} color={RecipePalette.onAccent} />
      <Text style={styles.actionText} numberOfLines={1}>
        {title}
      </Text>
    </TouchableOpacity>
  );
}

function Banner({
  icon,
  tint,
  text,
  textColor,
  surface,
  onDismiss,
}: {
  icon: IconName;
  tint: string;
  text: string;
  textColor: string;
  surface: object;
  onDismiss: () => void;
}) {
  return (
    <View style={[styles.banner, surface]}>
      <Icon name={icon} size={16} color={tint} />
      <Text style={[styles.bannerText, {color: textColor}]}>{text}</Text>
      <TouchableOpacity onPress={onDismiss}>
        <Text style={[styles.bannerDismiss, {color: tint}]}>Dismiss</Text>
      </TouchableOpacity>
    </View>
  );
}

function TypingIndicator({color}: {color: string}) {
  const step = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(step, {toValue: 3, duration: 1200, useNativeDriver: true}),
    );
    loop.start();
    return () => loop.stop();
  }, [step]);

  return (
    <View style={styles.typing}>
      {[0, 1, 2].map(i => (
        <Animated.View
          key={i}
          style={[
            styles.typingDot,
            {
              backgroundColor: color,
              opacity: step.interpolate({
                inputRange: [0, i, i + 0.5, i + 1, 3],
                outputRange: [0.3, 0.3, 1, 0.3, 0.3],
                extrapolate: 'clamp',
              }),
            },
          ]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerSide: {
    width: 44,
  },
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '600',
  },
  conversation: {
    paddingVertical: 14,
    gap: 14,
  },
  welcome: {
    alignItems: 'center',
    paddingTop: 36,
    paddingBottom: 24,
  },
  welcomeIcon: {
    width: 84,
    height: 84,
    borderRadius: 42,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 18,
    elevation: 6,
  },
  welcomeTitle: {
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 8,
  },
  welcomeText: {
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
    paddingHorizontal: 32,
  },
  suggestions: {
    alignSelf: 'stretch',
    paddingHorizontal: 20,
    marginTop: 22,
    gap: 10,
  },
  suggestion: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderRadius: 16,
    borderWidth: 1,
  },
  suggestionIcon: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  suggestionText: {
    flex: 1,
    fontSize: 15,
  },
  suggestionArrow: {
    transform: [{rotate: '45deg'}],
  },
  userRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    paddingLeft: 60,
    paddingRight: Spacing.md,
  },
  userBubble: {
    paddingHorizontal: 16,
    paddingVertical: 11,
    borderRadius: 20,
  },
  userText: {
    color: RecipePalette.onAccent,
    fontSize: 16,
    lineHeight: 22,
  },
  assistantRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
    paddingLeft: Spacing.md,
    paddingRight: 40,
  },
  avatar: {
    width: 26,
    height: 26,
    borderRadius: 13,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
  assistantBubble: {
    flexShrink: 1,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 20,
    borderWidth: 1,
  },
  typingBubble: {
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  typing: {
    flexDirection: 'row',
    gap: 4,
  },
  typingDot: {
    width: 7,
    height: 7,
    borderRadius: 4,
  },
  // Lines up with the assistant bubble, which is inset by its avatar.
  actions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    paddingLeft: 50,
    paddingRight: Spacing.md,
    marginTop: 10,
  },
  actionsBusy: {
    opacity: 0.6,
  },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 999,
    elevation: 2,
  },
  actionText: {
    color: RecipePalette.onAccent,
    fontSize: 15,
    fontWeight: '600',
  },
  banners: {
    paddingHorizontal: 14,
    paddingBottom: 8,
    gap: 8,
  },
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 14,
    borderWidth: 1,
  },
  bannerText: {
    flex: 1,
    fontSize: 13,
  },
  bannerDismiss: {
    fontSize: 13,
    fontWeight: '600',
  },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 10,
    paddingHorizontal: 14,
    paddingTop: 10,
    paddingBottom: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  input: {
    flex: 1,
    maxHeight: 120,
    fontSize: 16,
    paddingHorizontal: 16,
    paddingTop: 10,
    paddingBottom: 10,
    borderRadius: 22,
    borderWidth: 1,
  },
  sendBtn: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  locked: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingBottom: 60,
  },
  lockedIcon: {
    width: 84,
    height: 84,
    borderRadius: 42,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 18,
  },
  premiumBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 22,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 999,
  },
  premiumText: {
    fontSize: 14,
    fontWeight: '600',
  },
});
