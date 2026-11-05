import React, {useCallback, useEffect, useRef, useState} from 'react';
import {View, Text, Image, StyleSheet} from 'react-native';
import {Colors} from '../theme/AppTheme';
import {storeLogoService} from '../services/storeLogoService';

interface Props {
  storeName: string;
  size?: number;
  // Fires when what's on show changes: an image has loaded, or the initial has
  // taken over. A map marker draws from a bitmap of its view, so it must redo
  // that each time.
  onDisplayChange?: () => void;
}

// The store's logo, or its initial on a tinted circle when none can be found.
// Resolution follows the iOS StoreLogoProvider (see storeLogoService): when it
// has no URL, or the image fails to load, a Brand Search gets one more try
// before falling back to the initial. Stands in for the iOS CachedLogoImage;
// React Native's image cache covers the disk caching.
export default function StoreLogo({
  storeName,
  size = 48,
  onDisplayChange,
}: Props) {
  const [url, setUrl] = useState<string | undefined>(() =>
    storeLogoService.logoURL(storeName),
  );
  const [failed, setFailed] = useState(false);
  const searched = useRef(false);

  // Asks Brand Search for a logo, at most once per store name per mount.
  const search = useCallback(
    (isCancelled: () => boolean = () => false) => {
      if (searched.current) {
        setFailed(true);
        return;
      }
      searched.current = true;
      storeLogoService.searchLogoURL(storeName).then(found => {
        if (isCancelled()) {
          return;
        }
        if (found) {
          setUrl(found);
          setFailed(false);
        } else {
          setFailed(true);
        }
      });
    },
    [storeName],
  );

  useEffect(() => {
    let cancelled = false;
    searched.current = false;
    setFailed(false);
    storeLogoService.load().then(() => {
      if (cancelled) {
        return;
      }
      const resolvedUrl = storeLogoService.logoURL(storeName);
      setUrl(resolvedUrl);
      if (!resolvedUrl) {
        search(() => cancelled);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [storeName, search]);

  const showsImage = Boolean(url && !failed);
  useEffect(() => {
    if (!showsImage) {
      onDisplayChange?.();
    }
  }, [showsImage, onDisplayChange]);

  const circle = {width: size, height: size, borderRadius: size / 2};

  if (url && !failed) {
    return (
      <Image
        source={{uri: url}}
        style={[styles.image, circle]}
        onLoad={onDisplayChange}
        // Android fades images in, and a bitmap taken mid-fade stays washed out.
        fadeDuration={onDisplayChange ? 0 : undefined}
        onError={() => search()}
      />
    );
  }

  return (
    <View style={[styles.fallback, circle]}>
      <Text style={[styles.letter, {fontSize: size * 0.42}]}>
        {storeName.trim().charAt(0).toUpperCase() || '?'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  image: {
    backgroundColor: Colors.white,
  },
  fallback: {
    backgroundColor: Colors.blue + '26',
    alignItems: 'center',
    justifyContent: 'center',
  },
  letter: {
    color: Colors.blue,
    fontWeight: '700',
  },
});
