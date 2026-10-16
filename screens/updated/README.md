# Updated screenshots

Real screen captures for the landing page go in this folder. The page requests
them at `/screens/updated/<file>`, and `apps/trigo-landing/vite.config.js` serves
this folder in development and copies it into `apps/trigo-landing/dist/` on
build, so nothing else needs to change when files are added or replaced.

## Expected files

| File | Where it appears | Suggested content |
|------|------------------|-------------------|
| `landing-page.png` | Hero phone mock | The app's first screen (Passenger / Driver role selection) |
| `driver-earnings.png` | "Drive with TriGo" phone mock | Driver earnings dashboard |

Filenames are referenced directly in `apps/trigo-landing/index.html` — edit those
two `src` attributes if the uploaded files use different names.

Until a file exists the page renders a "Real screenshot coming soon" placeholder
inside the phone frame instead of a broken image, so missing uploads are harmless.

## Guidelines

- **Aspect ratio:** roughly `9:17` (portrait phone capture). The phone frame uses
  a fixed aspect ratio and `object-fit: cover` with `object-position: top`, so
  taller captures are cropped from the bottom and narrower ones from the sides.
- **Preferred format/size:** PNG or WebP, width ~900–1200 px. Files are copied
  as-is, so keep them reasonably small (a few hundred KB each).
- **Anonymity:** use demo accounts and blur or avoid real personal data,
  plate numbers, phone numbers and addresses.
- **Update the alt text** in `index.html` if a capture no longer matches its
  description — it is what screen-reader users get.
