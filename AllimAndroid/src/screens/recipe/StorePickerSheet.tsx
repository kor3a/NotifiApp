import React from 'react';
import {
  View,
  Text,
  Modal,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import StoreLogo from '../../components/StoreLogo';
import {
  Colors,
  Spacing,
  cardStyle,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {UserStoreItem} from '../../models';
import {RecipePalette} from './recipeTheme';

interface Props {
  visible: boolean;
  stores: UserStoreItem[];
  onSelect: (item: UserStoreItem) => void;
  onClose: () => void;
}

// "Choose Store" — where a recipe's ingredients go. The iOS StorePickerView.
export default function StorePickerSheet({visible, stores, onSelect, onClose}: Props) {
  const scheme = useColorScheme();

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
            <Text style={[styles.cancel, {color: RecipePalette.paprika(scheme)}]}>
              Cancel
            </Text>
          </TouchableOpacity>
          <Text style={[styles.title, {color: textPrimary(scheme)}]}>Choose Store</Text>
          <View style={styles.headerSide} />
        </View>

        {stores.length === 0 ? (
          <View style={styles.empty}>
            <Icon name="storefront-outline" size={40} color={textSecondary(scheme)} />
            <Text style={[styles.emptyTitle, {color: textPrimary(scheme)}]}>
              No stores yet
            </Text>
            <Text style={[styles.emptySubtitle, {color: textSecondary(scheme)}]}>
              Add a store first, then you can save recipe ingredients to it.
            </Text>
          </View>
        ) : (
          <FlatList
            data={stores}
            keyExtractor={s => s.id}
            contentContainerStyle={styles.list}
            ListHeaderComponent={
              <Text style={[styles.sectionHeader, {color: textSecondary(scheme)}]}>
                SELECT A STORE TO ADD INGREDIENTS
              </Text>
            }
            renderItem={({item}) => {
              const count = item.store.reminderCount ?? 0;
              return (
                <TouchableOpacity
                  style={[styles.row, cardStyle(scheme)]}
                  onPress={() => onSelect(item)}
                  activeOpacity={0.75}>
                  <StoreLogo storeName={item.store.name} size={40} />
                  <View style={{flex: 1}}>
                    <Text
                      style={[styles.storeName, {color: textPrimary(scheme)}]}
                      numberOfLines={1}>
                      {item.store.name}
                    </Text>
                    {count > 0 && (
                      <Text style={[styles.count, {color: textSecondary(scheme)}]}>
                        {count} item{count === 1 ? '' : 's'}
                      </Text>
                    )}
                  </View>
                  <Icon name="chevron-forward" size={16} color={textSecondary(scheme)} />
                </TouchableOpacity>
              );
            }}
          />
        )}
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
  cancel: {
    fontSize: 17,
  },
  title: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '600',
  },
  list: {
    paddingHorizontal: Spacing.md,
    paddingBottom: 40,
  },
  sectionHeader: {
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.6,
    marginBottom: Spacing.sm,
    marginLeft: 4,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  storeName: {
    fontSize: 16,
    fontWeight: '600',
  },
  count: {
    fontSize: 12,
    marginTop: 2,
  },
  empty: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.xl,
    gap: 12,
  },
  emptyTitle: {
    fontSize: 17,
    fontWeight: '600',
  },
  emptySubtitle: {
    fontSize: 15,
    textAlign: 'center',
  },
});
