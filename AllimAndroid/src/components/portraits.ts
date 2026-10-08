import {ImageSourcePropType} from 'react-native';
import {FEMALE_NAMES, MALE_NAMES} from './genderedNames';

// The illustrated portraits shown for anyone who hasn't set a profile photo,
// in place of a letter avatar. They are the iOS PortraitAvatar faces, rendered
// to PNG by scripts/render_portraits.py — same order as the iOS recipes.
const PORTRAITS: ImageSourcePropType[] = [
  require('../../assets/images/portraits/portrait-0.png'), // buzz
  require('../../assets/images/portraits/portrait-1.png'), // short
  require('../../assets/images/portraits/portrait-2.png'), // curls
  require('../../assets/images/portraits/portrait-3.png'), // afro
  require('../../assets/images/portraits/portrait-4.png'), // bob
  require('../../assets/images/portraits/portrait-5.png'), // wavy
  require('../../assets/images/portraits/portrait-6.png'), // long
  require('../../assets/images/portraits/portrait-7.png'), // bun
];

const MALE_PORTRAITS = [0, 1, 2, 3];
const FEMALE_PORTRAITS = [4, 5, 6, 7];

type Gender = 'male' | 'female';

/// A best guess from the first name, or null when the name isn't one we know
/// to lean one way — those draw from the whole set instead.
export function guessGender(name: string): Gender | null {
  const first = name.trim().split(/\s+/)[0] ?? '';
  const word = stripAccents(first).toLowerCase();

  // "Min-jun" is listed as "minjun"; "Mary-Jane" falls back to "mary".
  const candidates = [word.replace(/[^a-z]/g, ''), word.split(/[^a-z]/)[0]];
  for (const candidate of candidates) {
    if (MALE_NAMES.has(candidate)) {
      return 'male';
    }
    if (FEMALE_NAMES.has(candidate)) {
      return 'female';
    }
  }
  return null;
}

/// The portrait for a name, or null for an empty one — a row with no name to
/// draw from keeps the plain circle.
///
/// Which face within the set is derived from the whole name, so it is the
/// same on every screen and across launches, and two people with the same
/// first name don't all share one face.
export function portraitFor(name?: string | null): ImageSourcePropType | null {
  const trimmed = name?.trim() ?? '';
  if (!trimmed) {
    return null;
  }

  const hash = djb2(trimmed);
  const gender = guessGender(trimmed);
  if (!gender) {
    // Same pick as iOS makes for everyone.
    return PORTRAITS[Number(hash % BigInt(PORTRAITS.length))];
  }

  const pool = gender === 'male' ? MALE_PORTRAITS : FEMALE_PORTRAITS;
  return PORTRAITS[pool[Number(hash % BigInt(pool.length))]];
}

/// djb2 over the code points with 64-bit wraparound, matching
/// PortraitAvatar.variant(for:) on iOS.
function djb2(text: string): bigint {
  const mask = (BigInt(1) << BigInt(64)) - BigInt(1);
  let hash = BigInt(5381);
  for (const char of text) {
    hash = (hash * BigInt(33) + BigInt(char.codePointAt(0) ?? 0)) & mask;
  }
  return hash;
}

function stripAccents(text: string): string {
  // "José" → "Jose". normalize() is missing on Hermes builds without Intl.
  return typeof text.normalize === 'function'
    ? text.normalize('NFD').replace(/[̀-ͯ]/g, '')
    : text;
}
