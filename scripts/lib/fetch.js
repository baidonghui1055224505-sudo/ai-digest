// ============================================================================
// HTTP helper — auto-detects corporate proxy and routes traffic through it.
// Node.js fetch (undici) doesn't respect HTTP_PROXY/HTTPS_PROXY env vars,
// so we use https-proxy-agent when a proxy is configured.
// ============================================================================

import https from 'https';
import http from 'http';

let HttpsProxyAgent;
try {
  HttpsProxyAgent = (await import('https-proxy-agent')).HttpsProxyAgent;
} catch {
  // Not installed — direct connections only (fine for GitHub Actions)
}

const proxyUrl = process.env.HTTPS_PROXY || process.env.HTTP_PROXY || '';

function getAgent(url) {
  if (!HttpsProxyAgent || !proxyUrl) return undefined;
  return new HttpsProxyAgent(proxyUrl);
}

/**
 * POST JSON to a URL and return the parsed JSON response.
 * Automatically routes through HTTPS_PROXY if configured.
 */
export async function postJSON(url, body, opts = {}) {
  const u = new URL(url);
  const data = JSON.stringify(body);
  const agent = getAgent(url);

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: u.hostname,
      path: u.pathname + u.search,
      method: 'POST',
      agent,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        ...opts.headers,
      },
      timeout: opts.timeout || 120000,
    }, res => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        if (res.statusCode >= 400) {
          reject(new Error(`HTTP ${res.statusCode}: ${buf.slice(0, 500)}`));
        } else {
          try {
            resolve(JSON.parse(buf));
          } catch (e) {
            reject(new Error(`Invalid JSON: ${buf.slice(0, 200)}`));
          }
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Request timeout')); });
    req.write(data);
    req.end();
  });
}

/**
 * GET a URL and return raw text. Automatically routes through proxy.
 */
export async function getText(url) {
  const u = new URL(url);
  const agent = getAgent(url);
  const mod = u.protocol === 'https:' ? https : http;

  return new Promise((resolve, reject) => {
    const req = mod.request({
      hostname: u.hostname,
      path: u.pathname + u.search,
      method: 'GET',
      agent,
      headers: { 'User-Agent': 'Mozilla/5.0' },
      timeout: 30000,
    }, res => {
      if (res.statusCode >= 400) {
        // Follow redirects for RSS feeds
        if ([301, 302, 307, 308].includes(res.statusCode)) {
          const loc = res.headers.location;
          if (loc) return resolve(getText(loc));
        }
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => resolve(buf));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
    req.end();
  });
}

/**
 * GET JSON from a URL. Automatically routes through proxy.
 */
export async function getJSON(url) {
  const text = await getText(url);
  return JSON.parse(text);
}
