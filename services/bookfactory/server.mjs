import { createServer as createHttpsServer } from "https";
import { createServer as createHttpServer } from "http";
import { readFileSync } from "fs";
import { parse } from "url";
import next from "next";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const dev = process.env.NODE_ENV !== "production";
const hostname = "0.0.0.0";
const httpPort = parseInt(process.env.PORT || "3000", 10);
const httpsPort = parseInt(process.env.HTTPS_PORT || "3443", 10);

const app = next({ dev, hostname, port: httpPort });
const handle = app.getRequestHandler();

const httpsOptions = {
  key: readFileSync(resolve(__dirname, "certs/localhost+2-key.pem")),
  cert: readFileSync(resolve(__dirname, "certs/localhost+2.pem")),
};

await app.prepare();

// HTTPS server for iOS (ATS requires HTTPS)
createHttpsServer(httpsOptions, async (req, res) => {
  try {
    const parsedUrl = parse(req.url, true);
    await handle(req, res, parsedUrl);
  } catch (err) {
    console.error("Error handling HTTPS request:", err);
    res.statusCode = 500;
    res.end("Internal Server Error");
  }
}).listen(httpsPort, hostname, () => {
  console.log(`> HTTPS ready on https://localhost:${httpsPort}`);
  console.log(`> HTTPS ready on https://100.89.67.80:${httpsPort}`);
});

// HTTP server for web browser / backward compat
createHttpServer(async (req, res) => {
  try {
    const parsedUrl = parse(req.url, true);
    await handle(req, res, parsedUrl);
  } catch (err) {
    console.error("Error handling HTTP request:", err);
    res.statusCode = 500;
    res.end("Internal Server Error");
  }
}).listen(httpPort, hostname, () => {
  console.log(`> HTTP  ready on http://localhost:${httpPort}`);
});
