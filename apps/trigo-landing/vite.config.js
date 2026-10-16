import { defineConfig } from 'vite';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = path.dirname(fileURLToPath(import.meta.url));

/**
 * Screen captures are not stored in this app: they are uploaded to the repo-root
 * `screens/updated/` folder and referenced as `/screens/updated/<file>.png`.
 * This plugin serves that folder during development and copies it into the build
 * output, so dropping a file in is all it takes. A copy kept in the app's own
 * `public/screens/updated/` also works and is used as a fallback location.
 */
const updatedScreensRoot = path.resolve(projectRoot, '..', '..', 'screens', 'updated');
const updatedScreensPublic = path.resolve(projectRoot, 'public', 'screens', 'updated');
const lookupOrder = [updatedScreensRoot, updatedScreensPublic];
const copyOrder = [updatedScreensPublic, updatedScreensRoot];

const MIME_TYPES = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
};

const isImageFile = (file) => Boolean(MIME_TYPES[path.extname(file).toLowerCase()]);

async function listRelativeFiles(dir, base = dir) {
  let entries;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch {
    return [];
  }

  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listRelativeFiles(full, base)));
    } else if (isImageFile(entry.name)) {
      // Only images are screenshots; a README or notes file in the folder must
      // not count as an upload or end up in the build output.
      files.push(path.relative(base, full));
    }
  }
  return files;
}

function updatedScreenshots() {
  let outDir = path.resolve(projectRoot, 'dist');
  let warned = false;

  return {
    name: 'trigo-updated-screenshots',

    configResolved(config) {
      outDir = path.resolve(config.root, config.build.outDir);
    },

    async buildStart() {
      const available = (
        await Promise.all(lookupOrder.map((dir) => listRelativeFiles(dir)))
      ).flat();
      if (available.length === 0 && !warned) {
        warned = true;
        this.warn(
          `no screen captures found in ${updatedScreensRoot} — the page will show ` +
            'placeholders until screenshots are uploaded there',
        );
      }
    },

    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        if (req.method !== 'GET' || !req.url || !req.url.startsWith('/screens/updated/')) {
          return next();
        }

        const relative = decodeURIComponent(req.url.slice('/screens/updated/'.length).split('?')[0]);

        for (const dir of lookupOrder) {
          const file = path.resolve(dir, relative);
          if (file !== dir && !file.startsWith(dir + path.sep)) {
            res.statusCode = 403;
            res.end('Forbidden');
            return;
          }
          if (!isImageFile(file)) break;
          try {
            const body = await fs.readFile(file);
            res.setHeader(
              'Content-Type',
              MIME_TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream',
            );
            res.setHeader('Cache-Control', 'no-cache');
            res.end(body);
            return;
          } catch {
            // Not in this location; try the next one.
          }
        }

        res.statusCode = 404;
        res.setHeader('Content-Type', 'text/plain; charset=utf-8');
        res.end('Screenshot not uploaded yet');
      });
    },

    async closeBundle() {
      // Copied in reverse priority order so the repo-root folder wins.
      for (const dir of copyOrder) {
        for (const relative of await listRelativeFiles(dir)) {
          const target = path.join(outDir, 'screens', 'updated', relative);
          await fs.mkdir(path.dirname(target), { recursive: true });
          await fs.copyFile(path.join(dir, relative), target);
        }
      }
    },
  };
}

// Relative base keeps the built page portable: it works from a sub-path host,
// from a plain static file server, and from the local preview command.
export default defineConfig({
  base: './',
  plugins: [updatedScreenshots()],
  server: {
    port: 3001,
  },
  preview: {
    port: 3001,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // Screenshots are copied as files rather than inlined so browsers can cache
    // them; there is nothing in the bundle worth inlining either.
    assetsInlineLimit: 0,
  },
});
