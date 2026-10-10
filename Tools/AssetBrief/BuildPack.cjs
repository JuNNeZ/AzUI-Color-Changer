// Run with Node.js and sharp available (NODE_PATH can point to its node_modules).
// PNGs are original raster masters; SVGs provide editable placement wrappers.
// No generated Studio primitives are changed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../..');
const out = path.join(root, 'Media/StudioPack');
const keys = ['combat', 'mounted', 'resting', 'stealth', 'dead', 'spec', 'instance'];
const specs = [['logo', 64, 64], ['corner', 64, 64],
  ...keys.map(key => ['condition-' + key, 64, 64]),
  ['empty-rules', 256, 128], ['empty-pets', 256, 128]];
const pngs = {};
const escape = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
function label(x, y, text, size = 13, colour = '#9C95A8') {
  return `<text x="${x}" y="${y}" fill="${colour}" font-family="sans-serif" font-size="${size}">${escape(text)}</text>`;
}
function image(name, x, y, w, h, transform = '') {
  return `<image x="${x}" y="${y}" width="${w}" height="${h}" ${transform ? `transform="${transform}"` : ''} href="data:image/png;base64,${pngs[name].toString('base64')}"/>`;
}
async function build() {
  fs.mkdirSync(out, { recursive: true });
  for (const [name, width, height] of specs) {
    const source = fs.readFileSync(path.join(__dirname, 'source', name + '.png'));
    const { data, info } = await sharp(source).resize(width, height, { fit: 'contain', background: '#00000000' }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    assert.equal(info.channels, 4);
    if (name.startsWith('condition-')) {
      // Keep white RGB even on antialiased/transparent texels for clean tinting.
      for (let i = 0; i < data.length; i += 4) data[i] = data[i + 1] = data[i + 2] = 255;
    }
    if (name === 'corner') {
      // Lanczos can overshoot at edges; enforce the brief's highlight ceiling.
      for (let i = 0; i < data.length; i += 4) {
        data[i] = Math.min(data[i], 160); data[i + 1] = Math.min(data[i + 1], 138); data[i + 2] = Math.min(data[i + 2], 78);
      }
    }
    const header = Buffer.alloc(18);
    header[2] = 2; // Uncompressed true colour, BGRA, top-left origin, 8 alpha bits.
    header.writeUInt16LE(width, 12); header.writeUInt16LE(height, 14);
    header[16] = 32; header[17] = 0x28;
    const bgra = Buffer.alloc(data.length);
    let visible = 0, transparent = 0;
    for (let i = 0; i < data.length; i += 4) {
      bgra[i] = data[i + 2]; bgra[i + 1] = data[i + 1]; bgra[i + 2] = data[i]; bgra[i + 3] = data[i + 3];
      if (data[i + 3]) visible++; else transparent++;
      if (name === 'corner' && i / 4 % width >= 22 && Math.floor(i / 4 / width) >= 22) assert.equal(data[i + 3], 0, 'corner content area must stay clear');
    }
    assert(visible > 0 && transparent > 0, name + ' must have art and transparency');
    fs.writeFileSync(path.join(out, name + '.tga'), Buffer.concat([header, bgra]));
    pngs[name] = await sharp(data, { raw: { width, height, channels: 4 } }).png().toBuffer();
    if (name.startsWith('condition-')) {
      const tinted = Buffer.from(data);
      for (let i = 0; i < tinted.length; i += 4) { tinted[i] = 255; tinted[i + 1] = 209; tinted[i + 2] = 0; }
      pngs[name] = await sharp(tinted, { raw: { width, height, channels: 4 } }).png().toBuffer();
    }
    console.log(`${name}: ${width}x${height}, 32-bit TGA, alpha verified`);
  }
  let art = `<svg xmlns="http://www.w3.org/2000/svg" width="860" height="800"><rect width="860" height="800" fill="#15141B"/>`;
  art += label(28, 35, 'AzUI Studio — finished pack at its display sizes', 21, '#FFD100');
  // Window fitting preview: the art itself is at 28 and 40 px, four mirrored corners.
  art += '<rect x="70" y="70" width="660" height="200" rx="10" fill="#15141B" stroke="#6E5B2A" stroke-width="2"/>';
  art += image('logo', 88, 83, 28, 28) + label(126, 105, 'AzUI Studio', 20, '#FFD100');
  art += image('corner', 67, 67, 40, 40);
  art += image('corner', 0, 0, 40, 40, 'translate(733 67) scale(-1 1)');
  art += image('corner', 0, 0, 40, 40, 'translate(67 273) scale(1 -1)');
  art += image('corner', 0, 0, 40, 40, 'translate(733 273) scale(-1 -1)');
  art += '<rect x="84" y="128" width="180" height="120" rx="8" fill="#1A1921" stroke="#2E2B36"/><rect x="92" y="137" width="164" height="28" rx="6" fill="#2B2733"/>';
  art += label(104, 156, 'Health Bar', 13, '#FFD100') + label(104, 190, 'Rules') + label(104, 219, 'Hunter Pets');
  art += label(282, 150, 'Health Bar', 20, '#FFD100') + label(282, 180, 'Your own health bar: its colour, effects and presets.');
  art += label(28, 312, 'Conditions: 64 px masters and 20 px gold-tinted display', 16, '#E8E2D0');
  keys.forEach((key, i) => {
    const x = 28 + i * 118;
    art += image('condition-' + key, x + 10, 335, 64, 64) + image('condition-' + key, x + 80, 379, 20, 20);
    art += label(x + 10, 422, key, 12);
  });
  art += '<rect x="28" y="452" width="804" height="46" rx="6" fill="#1D1C24" stroke="#2E2B36"/>';
  art += '<rect x="46" y="466" width="34" height="18" rx="9" fill="#5A4513" stroke="#FFD100"/><circle cx="70" cy="475" r="6" fill="#FFD100"/>';
  art += image('condition-combat', 94, 465, 20, 20) + label(125, 479, 'When    In combat      show', 13, '#E8E2D0');
  art += '<rect x="310" y="463" width="40" height="24" rx="3" fill="#D12E2E"/>' + label(366, 479, 'Pulse      on      Health bar', 13, '#E8E2D0');
  art += label(28, 535, 'Empty states: 256 x 128 px', 16, '#E8E2D0');
  art += '<rect x="28" y="551" width="386" height="217" rx="8" fill="#1D1C24" stroke="#2E2B36"/><rect x="446" y="551" width="386" height="217" rx="8" fill="#1D1C24" stroke="#2E2B36"/>';
  art += image('empty-rules', 93, 565, 256, 128) + image('empty-pets', 511, 565, 256, 128);
  art += label(175, 714, 'No rules yet', 14, '#E8E2D0') + label(582, 714, 'No pets known yet', 14, '#E8E2D0');
  art += label(95, 740, 'A health bar changes colour at the banner.', 12) + label(504, 740, 'A paw beneath a simple stable roof.', 12) + '</svg>';
  await sharp(Buffer.from(art)).png().toFile(path.join(__dirname, 'preview.png'));
}
build().catch(error => { console.error(error); process.exitCode = 1; });
