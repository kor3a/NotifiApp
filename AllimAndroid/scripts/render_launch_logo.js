/**
 * Renders the launch logo's animated layers for the Android app.
 *
 * The launch animation (src/components/LaunchScreen.tsx) moves parts of the
 * logo independently, which a single flat icon.png can't do. These are that
 * artwork redrawn as vectors in icon.png's own 1024 space, so with every layer
 * at rest they land on the same pixels as the icon. Android ships them as
 * bundled PNGs, which saves pulling in an SVG library for one screen.
 *
 * Run it again whenever the icon changes (sharp comes from the website's deps):
 *
 *     npm --prefix ../website install
 *     node scripts/render_launch_logo.js
 *
 * Writes assets/launch/{store,scallop,badge,check}.png, plus
 * assets/splash-logo.png: the store with no badge on the teal, which is what
 * the native splash shows so the badge has somewhere to land.
 */
const fs = require('fs');
const path = require('path');
const sharp = require(path.join(__dirname, '../../website/node_modules/sharp'));

const TEAL = '#0B7285';
const WASH = '#E0F1F4';
const ACCENT = '#D94F16';

// 4x of the 200dp the logo is drawn at, so xxxhdpi screens get real pixels.
const CANVAS_PX = 800;
const CANVAS = 1024;

const STROKE = 34;
const stroke = (d, color = WASH, width = STROKE) =>
  `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round"/>`;

// Roof, awning band, the awning's two outer edges, and the walls. Everything
// that holds still while the scallops ripple.
const STORE = [
  stroke('M190 392 L270 245.5 A68 68 0 0 1 323 215 H701 A68 68 0 0 1 754 245.5 L834 392'),
  stroke('M190 392 H834'),
  stroke('M190 392 V460'),
  stroke('M834 392 V460'),
  stroke('M258 525 V746 C258 781 273 796 308 796 H714 C749 796 764 781 764 746 V525'),
].join('');

// One awning scallop, reused five times along the band. Its box is the arc plus
// the stroke around it, and LaunchScreen places it with the same numbers.
const SCALLOP_BOX = {x: 173, y: 442, width: 163, height: 100};
const SCALLOP_PITCH = 128.8;
const scallop = (x = 190) =>
  stroke(`M${x} 460 A64.4 64.5 0 0 0 ${x + SCALLOP_PITCH} 460`);
const SCALLOPS = [0, 1, 2, 3, 4]
  .map(i => scallop(190 + i * SCALLOP_PITCH))
  .join('');

const BADGE = `<circle cx="740" cy="756" r="112" fill="${ACCENT}"/>`;
const BADGE_BOX = {x: 628, y: 644, width: 224, height: 224};

const CHECK = stroke('M693 757 L730 794 L792 716', '#FFFFFF', 32);
const CHECK_BOX = {x: 675, y: 698, width: 135, height: 114};

const svg = (body, background = '') =>
  Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CANVAS} ${CANVAS}" width="${CANVAS_PX}" height="${CANVAS_PX}">${
      background ? `<rect width="${CANVAS}" height="${CANVAS}" fill="${background}"/>` : ''
    }${body}</svg>`,
  );

// A layer cropped to its box in the 1024 space, so it costs only the pixels it
// needs — the scallop is drawn five times over.
async function cropped(body, box, out) {
  const scale = CANVAS_PX / CANVAS;
  await sharp(svg(body))
    .extract({
      left: Math.round(box.x * scale),
      top: Math.round(box.y * scale),
      width: Math.round(box.width * scale),
      height: Math.round(box.height * scale),
    })
    .png()
    .toFile(out);
}

async function main() {
  const assets = path.join(__dirname, '../assets');
  const launch = path.join(assets, 'launch');
  fs.mkdirSync(launch, {recursive: true});

  await sharp(svg(STORE)).png().toFile(path.join(launch, 'store.png'));
  await cropped(scallop(), SCALLOP_BOX, path.join(launch, 'scallop.png'));
  await cropped(BADGE, BADGE_BOX, path.join(launch, 'badge.png'));
  await cropped(CHECK, CHECK_BOX, path.join(launch, 'check.png'));

  // Same canvas as icon.png, so expo-splash-screen's imageWidth keeps it the
  // same size and the swap to the icon's artwork doesn't move anything.
  await sharp(svg(STORE + SCALLOPS, TEAL))
    .resize(1024, 1024)
    .flatten({background: TEAL})
    .png()
    .toFile(path.join(assets, 'splash-logo.png'));

  // Everything at rest, for comparing against icon.png.
  if (process.argv[2]) {
    await sharp(svg(STORE + SCALLOPS + BADGE + CHECK, TEAL))
      .resize(1024, 1024)
      .flatten({background: TEAL})
      .png()
      .toFile(process.argv[2]);
  }
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
