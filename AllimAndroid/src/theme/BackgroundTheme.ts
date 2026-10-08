import {ColorSchemeName} from 'react-native';
import {backgroundGradient} from './AppTheme';

// Per-screen background colors — the palette, names and shade behaviour of the
// iOS BackgroundTheme (AppBackgroundColor and Color.shaded(by:)).

export type BackgroundColorId =
  | 'system'
  | 'graphite'
  | 'slate'
  | 'midnight'
  | 'ocean'
  | 'teal'
  | 'forest'
  | 'sage'
  | 'sand'
  | 'apricot'
  | 'rose'
  | 'plum'
  | 'lavender';

type RGB = [number, number, number];

interface BackgroundColorOption {
  id: BackgroundColorId;
  name: string;
  // Channels 0…1, copied from the iOS palette.
  light: RGB;
  dark: RGB;
}

export const BACKGROUND_COLORS: BackgroundColorOption[] = [
  {id: 'graphite', name: 'Graphite', light: [0.93, 0.93, 0.95], dark: [0.11, 0.11, 0.12]},
  {id: 'slate', name: 'Slate', light: [0.9, 0.92, 0.95], dark: [0.12, 0.14, 0.18]},
  {id: 'midnight', name: 'Midnight', light: [0.85, 0.87, 0.94], dark: [0.05, 0.06, 0.11]},
  {id: 'ocean', name: 'Ocean', light: [0.86, 0.92, 0.98], dark: [0.06, 0.13, 0.21]},
  {id: 'teal', name: 'Teal', light: [0.85, 0.94, 0.93], dark: [0.05, 0.16, 0.16]},
  {id: 'forest', name: 'Forest', light: [0.87, 0.94, 0.88], dark: [0.06, 0.14, 0.1]},
  {id: 'sage', name: 'Sage', light: [0.91, 0.93, 0.86], dark: [0.11, 0.14, 0.11]},
  {id: 'sand', name: 'Sand', light: [0.96, 0.93, 0.86], dark: [0.15, 0.13, 0.09]},
  {id: 'apricot', name: 'Apricot', light: [0.99, 0.91, 0.84], dark: [0.18, 0.12, 0.08]},
  {id: 'rose', name: 'Rose', light: [0.98, 0.9, 0.91], dark: [0.17, 0.1, 0.12]},
  {id: 'plum', name: 'Plum', light: [0.94, 0.88, 0.95], dark: [0.16, 0.1, 0.17]},
  {id: 'lavender', name: 'Lavender', light: [0.93, 0.91, 0.98], dark: [0.13, 0.11, 0.2]},
];

export function isBackgroundColorId(value: unknown): value is BackgroundColorId {
  return (
    value === 'system' || BACKGROUND_COLORS.some(c => c.id === value)
  );
}

export function backgroundColorName(id: BackgroundColorId): string {
  return BACKGROUND_COLORS.find(c => c.id === id)?.name ?? 'Default';
}

// ─── Shading ──────────────────────────────────────────────────────────────────

// How dark a color gets at full shade — deeper than any palette entry's dark
// variant, so all the way right reads as genuinely dark rather than dim.
const MAX_SHADE_BRIGHTNESS = 0.06;

function hexToRgb(hex: string): RGB {
  const n = parseInt(hex.replace('#', ''), 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

function rgbToHex([r, g, b]: RGB): string {
  const to = (v: number) =>
    Math.round(Math.min(Math.max(v, 0), 1) * 255)
      .toString(16)
      .padStart(2, '0');
  return `#${to(r)}${to(g)}${to(b)}`;
}

function rgbToHsb([r, g, b]: RGB): RGB {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === r) {
      h = ((g - b) / d) % 6;
    } else if (max === g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6;
    if (h < 0) {
      h += 1;
    }
  }
  return [h, max === 0 ? 0 : d / max, max];
}

function hsbToRgb([h, s, v]: RGB): RGB {
  const i = Math.floor(h * 6);
  const f = h * 6 - i;
  const p = v * (1 - s);
  const q = v * (1 - f * s);
  const t = v * (1 - (1 - f) * s);
  switch (((i % 6) + 6) % 6) {
    case 0:
      return [v, t, p];
    case 1:
      return [q, v, p];
    case 2:
      return [p, v, t];
    case 3:
      return [p, q, v];
    case 4:
      return [t, p, v];
    default:
      return [v, p, q];
  }
}

// Deepens (shade > 0) or lifts (shade < 0) a color, moving in HSB so the hue
// survives. Darkening raises saturation multiplicatively so pale colors don't
// slide to grey while neutrals stay neutral; lifting washes toward white.
function shadeRgb(rgb: RGB, shade: number): RGB {
  const amount = Math.min(Math.max(shade, -1), 1);
  if (amount === 0) {
    return rgb;
  }
  const [h, s, b] = rgbToHsb(rgb);
  const distance = Math.abs(amount);
  const targetB = amount > 0 ? MAX_SHADE_BRIGHTNESS : 1;
  const targetS = amount > 0 ? Math.min(s * 2.2, 0.6) : s * 0.25;
  return hsbToRgb([h, s + (targetS - s) * distance, b + (targetB - b) * distance]);
}

// ─── Rendering ────────────────────────────────────────────────────────────────

// The gradient stops to paint behind a screen. Default keeps the app gradient;
// every palette color is a flat fill (both stops the same). Both carry shade.
export function backgroundStops(
  id: BackgroundColorId,
  scheme: ColorSchemeName,
  shade: number,
): string[] {
  if (id === 'system') {
    return backgroundGradient(scheme).map(hex =>
      rgbToHex(shadeRgb(hexToRgb(hex), shade)),
    );
  }
  const option = BACKGROUND_COLORS.find(c => c.id === id);
  if (!option) {
    return backgroundGradient(scheme);
  }
  const fill = rgbToHex(
    shadeRgb(scheme === 'dark' ? option.dark : option.light, shade),
  );
  return [fill, fill];
}
