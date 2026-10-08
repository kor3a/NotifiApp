import React, {useEffect, useRef, useState} from 'react';
import {
  View,
  Text,
  Modal,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {GestureHandlerRootView, Swipeable} from 'react-native-gesture-handler';
import Icon from '../../components/AppIcon';

import {Colors, Spacing, Radius, textPrimary, textSecondary} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {recipeService} from '../../services/recipeService';
import {Recipe} from '../../models';
import RecipeEditSheet from './RecipeEditSheet';
import {RecipeBackdrop, RecipePalette} from './recipeTheme';

interface Props {
  visible: boolean;
  onClose: () => void;
}

// Ingredients shown as chips before the row spills into a "+n" summary.
const CHIP_LIMIT = 3;

// "My Recipes" — the iOS RecipeView, opened from the Stores + menu's Add
// Recipe. Tap a recipe to edit it, swipe it left to delete, + to add one.
export default function RecipesSheet({visible, onClose}: Props) {
  const scheme = useColorScheme();
  const {currentUser} = useSession();
  const accent = RecipePalette.paprika(scheme);

  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<{recipe: Recipe | null} | null>(null);
  const openRow = useRef<Swipeable | null>(null);

  useEffect(() => {
    if (!visible || !currentUser) {return;}
    setLoading(true);
    return recipeService.subscribeToRecipes(
      currentUser.userId,
      items => {
        setRecipes(items);
        setLoading(false);
      },
      () => setLoading(false),
    );
  }, [visible, currentUser]);

  function handleSave(name: string, ingredients: string[]) {
    if (!currentUser || !editing) {return;}
    const write = editing.recipe
      ? recipeService.updateRecipe(editing.recipe.id, name, ingredients)
      : recipeService.addRecipe(currentUser, name, ingredients);
    write.catch(err => Alert.alert('Error', err?.message ?? 'Failed to save recipe.'));
  }

  function confirmDelete(recipe: Recipe) {
    Alert.alert('Delete Recipe', `Delete "${recipe.name}"? This cannot be undone.`, [
      {text: 'Cancel', style: 'cancel'},
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () =>
          recipeService
            .deleteRecipe(recipe.id)
            .catch(err => Alert.alert('Error', err?.message ?? 'Failed to delete recipe.')),
      },
    ]);
  }

  function renderRecipe({item, index}: {item: Recipe; index: number}) {
    let row: Swipeable | null = null;
    const hidden = Math.max(0, item.ingredients.length - CHIP_LIMIT);

    return (
      <Swipeable
        ref={ref => {
          row = ref;
        }}
        overshootRight={false}
        rightThreshold={40}
        onSwipeableWillOpen={() => {
          if (openRow.current && openRow.current !== row) {
            openRow.current.close();
          }
          openRow.current = row;
        }}
        renderRightActions={() => (
          <TouchableOpacity
            style={styles.deleteAction}
            onPress={() => {
              row?.close();
              confirmDelete(item);
            }}
            activeOpacity={0.8}>
            <Icon name="trash-outline" size={22} color="#fff" />
            <Text style={styles.deleteText}>Delete</Text>
          </TouchableOpacity>
        )}>
        <TouchableOpacity
          activeOpacity={0.7}
          onPress={() => setEditing({recipe: item})}
          style={styles.rowTouch}>
          <View style={styles.row}>
            <View style={[styles.rule, {backgroundColor: accent}]} />
            <View style={{flex: 1}}>
              <View style={styles.rowTitleLine}>
                <Text
                  style={[styles.rowTitle, {color: textPrimary(scheme)}]}
                  numberOfLines={1}>
                  {item.name}
                </Text>
                <Icon name="chevron-forward" size={14} color={textSecondary(scheme)} />
              </View>
              {item.ingredients.length === 0 ? (
                <Text style={[styles.noIngredients, {color: textSecondary(scheme)}]}>
                  No ingredients yet
                </Text>
              ) : (
                <View style={styles.chips}>
                  {item.ingredients.slice(0, CHIP_LIMIT).map((ingredient, i) => (
                    <View
                      key={`${i}-${ingredient}`}
                      style={[
                        styles.chip,
                        {
                          backgroundColor:
                            RecipePalette.apricot(scheme) + (scheme === 'dark' ? '33' : '42'),
                          borderColor: RecipePalette.apricot(scheme) + '6B',
                        },
                      ]}>
                      <Text
                        style={[styles.chipText, {color: textPrimary(scheme)}]}
                        numberOfLines={1}>
                        {ingredient}
                      </Text>
                    </View>
                  ))}
                  {hidden > 0 && (
                    <Text style={[styles.more, {color: textSecondary(scheme)}]}>
                      +{hidden}
                    </Text>
                  )}
                </View>
              )}
            </View>
          </View>
          {index < recipes.length - 1 && (
            <View
              style={[styles.divider, {backgroundColor: RecipePalette.rowDivider(scheme)}]}
            />
          )}
        </TouchableOpacity>
      </Swipeable>
    );
  }

  function renderBody() {
    if (loading) {
      return (
        <View style={styles.center}>
          <ActivityIndicator size="large" color={accent} />
          <Text style={[styles.loadingText, {color: textSecondary(scheme)}]}>
            Loading recipes...
          </Text>
        </View>
      );
    }
    if (recipes.length === 0) {
      return (
        <View style={styles.center}>
          <View
            style={[styles.emptyIcon, {backgroundColor: RecipePalette.apricot(scheme) + '2E'}]}>
            <Icon name="restaurant-outline" size={44} color={accent} />
          </View>
          <Text style={[styles.emptyTitle, {color: textPrimary(scheme)}]}>
            No Recipes Yet
          </Text>
          <Text style={[styles.emptySubtitle, {color: textSecondary(scheme)}]}>
            Tap + to create your first recipe{'\n'}and save your favourite ingredient
            lists.
          </Text>
        </View>
      );
    }
    return (
      <FlatList
        data={recipes}
        keyExtractor={r => r.id}
        renderItem={renderRecipe}
        contentContainerStyle={styles.list}
        ListHeaderComponent={
          <Text style={[styles.listHeader, {color: textSecondary(scheme)}]}>
            {recipes.length} RECIPE{recipes.length === 1 ? '' : 'S'}
          </Text>
        }
      />
    );
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}>
      {/* Gestures inside an Android Modal need their own root. */}
      <GestureHandlerRootView style={{flex: 1}}>
        <RecipeBackdrop scheme={scheme} extraScrim={0.22} />
        <SafeAreaView style={{flex: 1}}>
          <View style={styles.header}>
            <TouchableOpacity onPress={onClose} style={styles.headerSide}>
              <Text style={[styles.headerAction, {color: accent}]}>Done</Text>
            </TouchableOpacity>
            <Text style={[styles.title, {color: textPrimary(scheme)}]}>My Recipes</Text>
            <TouchableOpacity
              onPress={() => setEditing({recipe: null})}
              style={[styles.headerSide, {alignItems: 'flex-end'}]}
              accessibilityLabel="New recipe">
              <Icon name="add" size={28} color={accent} />
            </TouchableOpacity>
          </View>
          <View style={{flex: 1}}>{renderBody()}</View>
        </SafeAreaView>

        <RecipeEditSheet
          visible={!!editing}
          recipe={editing?.recipe ?? null}
          onSave={handleSave}
          onClose={() => setEditing(null)}
        />
      </GestureHandlerRootView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: 12,
  },
  headerSide: {
    width: 70,
  },
  headerAction: {
    fontSize: 17,
    fontWeight: '600',
  },
  title: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '600',
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: Spacing.lg,
  },
  loadingText: {
    marginTop: 12,
    fontSize: 15,
  },
  emptyIcon: {
    width: 100,
    height: 100,
    borderRadius: 50,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.lg,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: '600',
    marginBottom: Spacing.sm,
  },
  emptySubtitle: {
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 21,
  },
  list: {
    paddingBottom: 40,
  },
  listHeader: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 1.1,
    paddingHorizontal: 22,
    paddingTop: 4,
    paddingBottom: 10,
  },
  rowTouch: {
    paddingHorizontal: 22,
  },
  row: {
    flexDirection: 'row',
    gap: 14,
    paddingVertical: 16,
  },
  rule: {
    width: 3,
    borderRadius: 2,
  },
  rowTitleLine: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 10,
  },
  rowTitle: {
    flex: 1,
    fontSize: 20,
    fontWeight: '600',
  },
  noIngredients: {
    fontSize: 12,
  },
  chips: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  chip: {
    flexShrink: 1,
    paddingVertical: 4,
    paddingHorizontal: 9,
    borderRadius: Radius.full,
    borderWidth: 1,
  },
  chipText: {
    fontSize: 11,
  },
  more: {
    fontSize: 11,
    fontWeight: '600',
  },
  divider: {
    height: 1,
    marginLeft: 17,
  },
  deleteAction: {
    width: 84,
    backgroundColor: Colors.red,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },
  deleteText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
});
