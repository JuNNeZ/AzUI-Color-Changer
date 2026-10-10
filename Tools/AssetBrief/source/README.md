# AzUI Studio source art

The eleven PNG masters are newly generated original fantasy artwork: Warcraft
cartoon proportions with sculpted bronze, stone, timber, and faceted gold inspired
by AzeriteUI's visual feel. The mockup supplies concepts and fitting dimensions,
not drawings to duplicate. No AzeriteUI or Blizzard asset files were used.

The PNGs preserve the high-resolution generated alpha. Each matching SVG is an
editable placement wrapper linking its local PNG, not a vector tracing. Edit the
PNG to change painting details, or the wrapper to arrange it. The build reads PNG
masters directly. `raster-masters.json` lists those local masters. `flat-v1/`
preserves the previous simple vector concept for reference.

The two empty-state assets use compact icon shapes with soft colour gradients:
a health strip and flag for rules, and a paw under a roof outline for pets.
The dead-condition icon is a sober skull silhouette, readable at 20 px.
`painted-v2/` preserves the superseded gate/stable scenes and ghost.

From the addon directory, run `node Tools/AssetBrief/BuildPack.cjs` with the `sharp`
module available to Node.js (or set `NODE_PATH` to its node_modules directory).
The build exports uncompressed 32-bit BGRA TGA files with eight alpha bits and a
top-left origin into `Media/StudioPack/`. Masters are downsampled with Lanczos,
keeping aspect ratio and transparency. Condition icons retain pure white RGB at
every alpha level; the runtime tints them gold. The bronze corner highlights are
limited to #A08A4E, including any resampling overshoot, and its content-facing
interior must remain transparent.

The build also produces `Tools/AssetBrief/preview.png`: original-size art on the
Studio palette, with the four mirrored corner fittings, a sample rule, and both
empty states. This is an offline asset-fitting preview; check final rendering in WoW.
The original mockup remains the reference. `Tools/` is excluded from packaging.
