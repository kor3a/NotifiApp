import React, {useEffect, useRef, useState} from 'react';
import {
  View,
  Text,
  Modal,
  TextInput,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import {
  Colors,
  Spacing,
  Radius,
  cardStyle,
  textPrimary,
  textSecondary,
  inputStyle,
} from '../../theme/AppTheme';
import {Recipe} from '../../models';
import {RecipePalette} from './recipeTheme';

interface Props {
  visible: boolean;
  // null creates a new recipe.
  recipe: Recipe | null;
  onSave: (name: string, ingredients: string[]) => void;
  onClose: () => void;
}

// Create or edit one recipe: a name and a list of ingredients — the iOS
// RecipeEditView.
export default function RecipeEditSheet({visible, recipe, onSave, onClose}: Props) {
  const scheme = useColorScheme();
  const accent = RecipePalette.paprika(scheme);
  const [name, setName] = useState('');
  const [ingredients, setIngredients] = useState<string[]>([]);
  const [draft, setDraft] = useState('');
  const ingredientInput = useRef<TextInput>(null);

  // Each opening starts from the recipe being edited (or blank). Keyed on the
  // id rather than the object: the recipes listener hands over a fresh object
  // on every snapshot, which would otherwise wipe the edit in progress.
  const recipeId = recipe?.id;
  useEffect(() => {
    if (visible) {
      setName(recipe?.name ?? '');
      setIngredients(recipe?.ingredients ?? []);
      setDraft('');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, recipeId]);

  const pending = draft.trim();
  const isValid = name.trim().length > 0 && (ingredients.length > 0 || pending.length > 0);

  function addIngredient() {
    if (!pending) {return;}
    setIngredients(list => [...list, pending]);
    setDraft('');
    ingredientInput.current?.focus();
  }

  function save() {
    if (!isValid) {return;}
    // Text still sitting in the field counts — it's what the user typed last.
    onSave(name.trim(), pending ? [...ingredients, pending] : ingredients);
    onClose();
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}>
      <SafeAreaView
        style={[
          styles.container,
          {backgroundColor: scheme === 'dark' ? Colors.backgroundTopDark : Colors.backgroundTopLight},
        ]}>
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose} style={styles.headerSide}>
            <Text style={[styles.headerAction, {color: accent}]}>Cancel</Text>
          </TouchableOpacity>
          <View style={{flex: 1}} />
          <TouchableOpacity
            onPress={save}
            disabled={!isValid}
            style={[styles.headerSide, {alignItems: 'flex-end'}]}>
            <Text
              style={[
                styles.headerAction,
                styles.bold,
                {color: accent, opacity: isValid ? 1 : 0.4},
              ]}>
              Save
            </Text>
          </TouchableOpacity>
        </View>

        <KeyboardAvoidingView
          style={{flex: 1}}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
          <ScrollView
            contentContainerStyle={styles.scroll}
            keyboardShouldPersistTaps="handled">
            <Text style={[styles.title, {color: textPrimary(scheme)}]}>
              {recipe ? 'Edit recipe' : 'New recipe'}
            </Text>

            <Text style={[styles.sectionLabel, {color: textSecondary(scheme)}]}>
              RECIPE NAME
            </Text>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder="e.g. Pasta Carbonara"
              placeholderTextColor={textSecondary(scheme)}
              style={inputStyle(scheme)}
              returnKeyType="next"
              onSubmitEditing={() => ingredientInput.current?.focus()}
              blurOnSubmit={false}
              autoCapitalize="words"
            />

            <Text
              style={[
                styles.sectionLabel,
                {color: textSecondary(scheme), marginTop: Spacing.lg},
              ]}>
              INGREDIENTS
            </Text>
            {ingredients.length === 0 ? (
              <Text style={[styles.emptyText, {color: textSecondary(scheme)}]}>
                Nothing here yet. Add the ingredients you shop for.
              </Text>
            ) : (
              ingredients.map((ingredient, index) => (
                <View
                  key={`${index}-${ingredient}`}
                  style={[styles.ingredientRow, cardStyle(scheme)]}>
                  <View style={[styles.dot, {backgroundColor: accent}]} />
                  <Text style={[styles.ingredientText, {color: textPrimary(scheme)}]}>
                    {ingredient}
                  </Text>
                  <TouchableOpacity
                    onPress={() =>
                      setIngredients(list => list.filter((_, i) => i !== index))
                    }
                    style={[styles.removeBtn, {backgroundColor: Colors.red + '1A'}]}
                    accessibilityLabel={`Remove ${ingredient}`}>
                    <Icon name="close" size={14} color={Colors.red} />
                  </TouchableOpacity>
                </View>
              ))
            )}

            <View style={styles.addRow}>
              <TextInput
                ref={ingredientInput}
                value={draft}
                onChangeText={setDraft}
                placeholder="Add ingredient…"
                placeholderTextColor={textSecondary(scheme)}
                style={[inputStyle(scheme), {flex: 1}]}
                returnKeyType="done"
                onSubmitEditing={addIngredient}
                blurOnSubmit={false}
              />
              <TouchableOpacity
                onPress={addIngredient}
                disabled={!pending}
                style={[styles.addBtn, {backgroundColor: accent, opacity: pending ? 1 : 0.4}]}
                accessibilityLabel="Add ingredient">
                <Icon name="add" size={24} color={RecipePalette.onAccent} />
              </TouchableOpacity>
            </View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: 14,
  },
  headerSide: {
    width: 70,
  },
  headerAction: {
    fontSize: 17,
  },
  bold: {
    fontWeight: '600',
  },
  scroll: {
    paddingHorizontal: 20,
    paddingBottom: 40,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    marginTop: Spacing.sm,
    marginBottom: Spacing.lg,
  },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.8,
    marginBottom: 10,
  },
  emptyText: {
    fontSize: 14,
    marginBottom: Spacing.sm,
  },
  ingredientRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingHorizontal: Spacing.md,
    paddingVertical: 10,
  },
  dot: {
    width: 7,
    height: 7,
    borderRadius: 4,
    marginLeft: 4,
  },
  ingredientText: {
    flex: 1,
    fontSize: 16,
  },
  removeBtn: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginTop: Spacing.sm,
  },
  addBtn: {
    width: 54,
    height: 54,
    borderRadius: Radius.full,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
