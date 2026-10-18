const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const port = Number(process.env.PORT || 3000);
const staticRoot = process.env.LEADSIGNAL_STATIC_ROOT || __dirname;

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon"
};

function send(res, status, body, contentType = "text/plain; charset=utf-8") {
  res.writeHead(status, { "Content-Type": contentType });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        req.destroy();
        reject(new Error("Request body too large"));
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

function signatureHeaders(secret, body) {
  if (!secret) return {};
  const signature = crypto
    .createHmac("sha256", secret)
    .update(body)
    .digest("hex");

  return {
    "X-Hermes-Signature": signature,
    "X-Hermes-Signature-256": `sha256=${signature}`,
    "X-Webhook-Signature": signature,
    "X-Webhook-Signature-256": `sha256=${signature}`,
    "X-Hub-Signature-256": `sha256=${signature}`,
    "Authorization": `Bearer ${secret}`
  };
}

async function handleHermesProxy(req, res) {
  if (req.method !== "POST") {
    send(res, 405, JSON.stringify({ error: "Method not allowed" }), "application/json; charset=utf-8");
    return;
  }

  const target = process.env.HERMES_WEBHOOK_URL;
  if (!target || !/^https?:\/\//i.test(target)) {
    send(res, 400, JSON.stringify({
      error: "Le service de test Hermes n’est pas encore configuré sur ce serveur."
    }), "application/json; charset=utf-8");
    return;
  }

  try {
    const body = await readBody(req);
    const secret = process.env.HERMES_WEBHOOK_SECRET || "";
    const upstream = await fetch(target, {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(30000),
      headers: {
        "Content-Type": "application/json",
        ...signatureHeaders(secret, body)
      },
      body
    });
    const text = await upstream.text();
    res.writeHead(upstream.status, {
      "Content-Type": upstream.headers.get("content-type") || "application/json; charset=utf-8"
    });
    res.end(text);
  } catch (error) {
    send(res, 502, JSON.stringify({
      status: "failed",
      reason: `Hermes proxy failed: ${error.message}`,
      errors: [error.message]
    }), "application/json; charset=utf-8");
  }
}

// ─── Lusha enrichment proxy ───────────────────────────────────────────────────
// Reads LUSHA_API_KEY from environment variable.
// Call:  POST /api/lusha-enrich  { name, company }
// Returns: { phones: [...] }
async function handleLushaEnrich(req, res) {
  const corsHeaders = {
    "Content-Type": "application/json; charset=utf-8"
  };

  if (req.method === "OPTIONS") {
    res.writeHead(204, { ...corsHeaders, "Access-Control-Allow-Methods": "POST", "Access-Control-Allow-Headers": "Content-Type" });
    res.end();
    return;
  }
  if (req.method !== "POST") {
    res.writeHead(405, corsHeaders);
    res.end(JSON.stringify({ error: "Method not allowed" }));
    return;
  }

  const apiKey = process.env.LUSHA_API_KEY;
  if (!apiKey) {
    res.writeHead(500, corsHeaders);
    res.end(JSON.stringify({ error: "LUSHA_API_KEY not set. Add it as an environment variable before starting the proxy." }));
    return;
  }

  const requestId = crypto.randomUUID();
  const started = Date.now();
  let stage = 'input';
  async function providerJson(response) {
    if (!response.ok) {
      const error = new Error('Provider HTTP failure');
      error.providerStatus = response.status;
      throw error;
    }
    try { return await response.json(); }
    catch { const error = new Error('Invalid provider JSON'); error.code = 'invalid_response'; throw error; }
  }
  try {
    const raw = await readBody(req);
    const { name, company } = JSON.parse(raw);
    if (typeof name !== 'string' || name.length > 250 || (company != null && (typeof company !== 'string' || company.length > 250))) {
      return send(res, 400, JSON.stringify({error:'Nom ou entreprise invalide'}), 'application/json');
    }

    if (!name) {
      res.writeHead(400, corsHeaders);
      res.end(JSON.stringify({ error: "name is required" }));
      return;
    }

    // Split "Prénom Nom" into firstName / lastName
    const nameParts = name.trim().split(/\s+/);
    const firstName = nameParts[0] || "";
    const lastName = nameParts.slice(1).join(" ") || "";

    // Step 1: Search using Lusha v3 contacts array format
    const searchBody = { contacts: [{ firstName, lastName }] };
    if (company) searchBody.contacts[0].companyName = company;

    stage = 'search';
    const searchRes = await fetch("https://api.lusha.com/v3/contacts/search", {
      method: "POST",
      signal: AbortSignal.timeout(30000),
      redirect: "error",
      headers: { "api_key": apiKey, "Content-Type": "application/json" },
      body: JSON.stringify(searchBody)
    });
    const searchData = await providerJson(searchRes);
    const results = searchData?.results || searchData?.data;
    if (!Array.isArray(results)) { const e = new Error('Unknown search shape'); e.code='invalid_response'; throw e; }

    // Lusha v3 returns data in a "results" array
    const contactId = searchData?.results?.[0]?.id || searchData?.data?.[0]?.id;
    if (results.length && !contactId) { const e=new Error('Missing contact ID');e.code='invalid_response';throw e; }
    if (!contactId) {
      res.writeHead(200, corsHeaders);
      res.end(JSON.stringify({ phones: [], message: "Contact non trouvé dans Lusha" }));
      return;
    }

    // Step 2: Enrich using Lusha v3 ids array format
    stage = 'enrich';
    const enrichRes = await fetch("https://api.lusha.com/v3/contacts/enrich", {
      method: "POST",
      signal: AbortSignal.timeout(30000),
      redirect: "error",
      headers: { "api_key": apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ ids: [contactId] })
    });
    const enrichData = await providerJson(enrichRes);

    const contact = enrichData?.results?.[0] || enrichData?.data?.[0] || enrichData;
    if (!contact || typeof contact !== 'object' || contact.error || !['id','phoneNumbers','phones','firstName'].some(k => k in contact)) {
      const e = new Error('Unknown enrich shape'); e.code='invalid_response'; throw e;
    }
    const rawPhones = contact?.phoneNumbers || contact?.phones || [];
    if (!Array.isArray(rawPhones)) { const e=new Error('Unknown phone shape');e.code='invalid_response';throw e; }
    const phones = rawPhones.map(p => ({
      number: p.normalizedNumber || p.localNumber || p.number || (typeof p === "string" ? p : ""),
      type: p.type || ""
    })).filter(p => typeof p.number === "string" && p.number.trim());

    res.writeHead(200, corsHeaders);
    res.end(JSON.stringify({ phones }));
  } catch (err) {
    const upstream = err.providerStatus || null;
    const code = upstream === 401 ? 'provider_auth' : upstream === 402 ? 'provider_credits'
      : upstream === 403 ? 'provider_access' : upstream === 429 ? 'provider_quota'
      : err.name === 'TimeoutError' || err.name === 'AbortError' ? 'provider_timeout'
      : err.code === 'invalid_response' ? 'invalid_response' : 'provider_unavailable';
    const messages = {provider_auth:'Configuration Lusha à vérifier.',provider_credits:'Crédits Lusha insuffisants.',
      provider_access:'Accès Lusha refusé.',provider_quota:'Limite Lusha atteinte. Réessayez plus tard.',
      provider_timeout:'Délai Lusha dépassé. Résultat incertain ; évitez les clics répétés.',
      invalid_response:'Réponse Lusha inattendue. Vérification technique nécessaire.',
      provider_unavailable:'Lusha temporairement indisponible.'};
    console.error(JSON.stringify({event:'lusha_failure',requestId,stage,code,upstreamStatus:upstream,durationMs:Date.now()-started}));
    res.writeHead(code==='provider_timeout'?504:502,corsHeaders);
    res.end(JSON.stringify({error:messages[code],code,requestId}));
  }
}

function serveStatic(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  let requestedPath;
  try { requestedPath = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname); }
  catch { return send(res, 400, 'Invalid path'); }
  const publicFiles = new Set(['/index.html', '/app.js', '/styles.css', '/source-trace.css', '/auth.js', '/auth.css', '/supabase-client.js', '/kaino-logo.png']);
  if (!publicFiles.has(requestedPath)) return send(res, 404, 'Not found');
  const resolved = path.resolve(staticRoot, `.${requestedPath}`);
  const root = path.resolve(staticRoot);

  if (!resolved.startsWith(root)) {
    send(res, 403, "Forbidden");
    return;
  }

  fs.readFile(resolved, (error, data) => {
    if (error) {
      send(res, 404, "Not found");
      return;
    }
    const ext = path.extname(resolved).toLowerCase();
    res.writeHead(200, {
      "Content-Type": contentTypes[ext] || "application/octet-stream",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Pragma": "no-cache",
      "Expires": "0"
    });
    res.end(data);
  });
}

// Load only the public project settings; never evaluate browser code on the server.
const clientSettings = fs.readFileSync(path.join(__dirname, 'supabase-client.js'), 'utf8');
const authUrl = clientSettings.match(/const SUPABASE_URL = "([^"]+)"/)[1];
const publicKey = clientSettings.match(/const SUPABASE_ANON_KEY = "([^"]+)"/)[1];
const allowedOrigin = process.env.APP_ORIGIN;
if (!allowedOrigin || !/^https?:$/.test(new URL(allowedOrigin).protocol)) throw new Error('APP_ORIGIN required');
const quotas = new Map();
async function authenticate(req) {
  const token = req.headers.authorization;
  if (!token || !/^Bearer [A-Za-z0-9_.-]+$/.test(token)) return false;
  const headers = { apikey: publicKey, Authorization: token };
  const user = await fetch(`${authUrl}/auth/v1/user`, { headers, signal: AbortSignal.timeout(10000) });
  if (!user.ok) return false;
  const identity = await user.json();
  if (!identity.id) return false;
  const membership = await fetch(`${authUrl}/rest/v1/rpc/is_platform_member`, { method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: '{}', signal: AbortSignal.timeout(10000) });
  if (!membership.ok || await membership.json() !== true) return false;
  return identity.id;
}
const server = http.createServer(async (req, res) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Security-Policy', "frame-ancestors 'none'; object-src 'none'; base-uri 'self'; form-action 'self'");
  if (req.headers.host !== new URL(allowedOrigin).host) return send(res, 403, 'Invalid host');
  if (req.headers.origin && req.headers.origin !== allowedOrigin) return send(res, 403, 'Invalid origin');

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const route = new URL(req.url, allowedOrigin).pathname;
  if (route === '/healthz' && req.method === 'GET') return send(res, 200, 'OK');
  if (route.startsWith('/api/')) {
    if (req.method !== 'POST') return send(res, 405, 'Method not allowed');
    let userId;
    try { userId = await authenticate(req); } catch { return send(res, 503, 'Authentication unavailable'); }
    if (!userId) return send(res, 401, 'Authentication and approved membership required');
    const now = Date.now();
    for (const [key, item] of quotas) if (item.until < now) quotas.delete(key);
    const quota = quotas.get(userId) || { count: 0, until: now + 60000 };
    if (++quota.count > 10) return send(res, 429, 'Too many requests');
    quotas.set(userId, quota);
  }
  if (route === "/api/hermes-signal-test") {
    handleHermesProxy(req, res);
    return;
  }
  if (route === "/api/lusha-enrich") {
    handleLushaEnrich(req, res);
    return;
  }
  serveStatic(req, res);
});

server.listen(port, process.env.BIND_HOST || "0.0.0.0", () => {
  console.log(`Kaino platform listening on port ${port}`);
});
