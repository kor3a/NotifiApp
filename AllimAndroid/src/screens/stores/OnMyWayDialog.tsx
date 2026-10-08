import React from 'react';
import {
  Modal,
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  useColorScheme,
} from 'react-native';
import Icon from '../../components/AppIcon';
import {
  Colors,
  Radius,
  Spacing,
  sheetBackground,
  sheetFill,
  textPrimary,
  textSecondary,
} from '../../theme/AppTheme';
import {TravelEstimate, formattedTravelTime} from '../../services/onMyWayService';

interface Props {
  storeName: string | null;
  estimate: TravelEstimate | null;
  isCalculating: boolean;
  isUnavailable: boolean;
  onSend: () => void;
  onCancel: () => void;
}

// The iOS "On My Way" confirmation: who is about to be told, and how far away
// the user is — worked out while the card is open, so the user sees the number
// their contacts will be sent before committing.
export default function OnMyWayDialog({
  storeName,
  estimate,
  isCalculating,
  isUnavailable,
  onSend,
  onCancel,
}: Props) {
  const scheme = useColorScheme();
  const settled = !!estimate;

  const label = estimate
    ? `About ${formattedTravelTime(estimate.travelTimeMinutes)} away`
    : isUnavailable
    ? 'Travel time unavailable'
    : 'Checking travel time…';
  const ink = settled ? Colors.green : textSecondary(scheme);

  return (
    <Modal
      visible={!!storeName}
      transparent
      animationType="fade"
      onRequestClose={onCancel}>
      <View style={styles.overlay}>
        <View style={[styles.card, {backgroundColor: sheetBackground(scheme)}]}>
          <View style={[styles.iconCircle, {backgroundColor: Colors.green + '26'}]}>
            <Icon name="car" size={26} color={Colors.green} />
          </View>
          <Text style={[styles.title, {color: textPrimary(scheme)}]}>
            On My Way
          </Text>
          <Text style={[styles.message, {color: textSecondary(scheme)}]}>
            Notify people you share {storeName} with that you're on your way?
          </Text>

          {/* Fixed height whatever its state, so the buttons don't shift
              under the user's thumb when the estimate lands. */}
          <View
            style={[
              styles.estimate,
              {backgroundColor: settled ? Colors.green + '26' : sheetFill(scheme)},
            ]}
            accessible
            accessibilityLabel={label}>
            {isCalculating ? (
              <ActivityIndicator size="small" color={textSecondary(scheme)} />
            ) : (
              <Icon
                name={isUnavailable ? 'help-circle-outline' : 'time'}
                size={15}
                color={ink}
              />
            )}
            <Text style={[styles.estimateText, {color: ink}]} numberOfLines={1}>
              {label}
            </Text>
          </View>

          <TouchableOpacity
            style={[styles.button, {backgroundColor: Colors.blue}]}
            onPress={onSend}
            activeOpacity={0.85}>
            <Text style={[styles.buttonText, {color: Colors.white}]}>Send</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.button, {backgroundColor: sheetFill(scheme)}]}
            onPress={onCancel}
            activeOpacity={0.85}>
            <Text style={[styles.buttonText, {color: textPrimary(scheme)}]}>
              Cancel
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: Spacing.lg,
  },
  card: {
    width: '100%',
    maxWidth: 360,
    borderRadius: Radius.xl,
    padding: Spacing.lg,
    alignItems: 'center',
  },
  iconCircle: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: Spacing.md,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: Spacing.sm,
  },
  message: {
    fontSize: 15,
    textAlign: 'center',
    lineHeight: 21,
    marginBottom: Spacing.md,
  },
  estimate: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    height: 42,
    paddingHorizontal: 18,
    borderRadius: 21,
    marginBottom: Spacing.lg,
  },
  estimateText: {
    fontSize: 15,
    fontWeight: '600',
  },
  button: {
    width: '100%',
    height: 50,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Spacing.sm,
  },
  buttonText: {
    fontSize: 17,
    fontWeight: '600',
  },
});
