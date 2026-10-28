// Serves the web export (../build/web) for the Playwright tests.
// Port from PORT (default 8137). The export is single-threaded, so no
// cross-origin isolation headers are needed; the wasm file must be served as
// application/wasm for streaming compilation.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("../build/web", import.meta.url)));
const port = Number(process.env.PORT ?? 8137);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".json": "application/json",
  ".webmanifest": "application/manifest+json",
};

createServer(async (request, response) => {
  const path = decodeURIComponent(new URL(request.url ?? "/", "http://localhost").pathname);
  const file = normalize(join(root, path.endsWith("/") ? path + "index.html" : path));
  if (file !== root && !file.startsWith(root + sep)) {
    response.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    response.writeHead(200, {
      "Content-Type": types[extname(file).toLowerCase()] ?? "application/octet-stream",
      "Cache-Control": "no-store",
    });
    response.end(body);
  } catch {
    response.writeHead(404).end("Not found");
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`Serving ${root} on http://127.0.0.1:${port}`);
});
