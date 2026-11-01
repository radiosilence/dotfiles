// GitHub over fetch with the gh CLI's token. GraphQL wherever GitHub offers it;
// REST only for Actions runs, reruns and dispatches, which GraphQL lacks.

import { exec } from "herdr";
import { GRAPHQL, REST } from "./gh.js";

// fetch takes no timeout, and GitHub ends slow GraphQL requests at about 10 s,
// so anything still open after this is abandoned rather than awaited.
const TIMEOUT = 20000;

let token = null;
let pendingToken = null;

async function auth(force) {
  if (force) token = null;
  if (token) return token;
  pendingToken ??= exec("gh", ["auth", "token"]).then((r) => {
    if (r.code !== 0 || !r.stdout.trim()) throw new Error(`gh auth token: ${(r.stderr || r.stdout).trim() || "no token"}`);
    return r.stdout.trim();
  }).finally(() => { pendingToken = null; });
  token = await pendingToken;
  return token;
}

export class HttpError extends Error {
  constructor(status, message) { super(`${status}: ${message}`); this.status = status; }
}

async function request(cx, url, method, body, retried = false) {
  const t = await auth(false);
  const headers = { Authorization: `Bearer ${t}`, Accept: "application/vnd.github+json", "User-Agent": "herdr-gh-board" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const res = await Promise.race([
    fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) }),
    cx.sleep(TIMEOUT).then(() => { throw new Error("GitHub did not answer in 20 s"); }),
  ]);
  // A token gh has since refreshed or rotated: fetch a new one, once.
  if (res.status === 401 && !retried) { await auth(true); return request(cx, url, method, body, true); }
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = null; }
  if (!res.ok) throw new HttpError(res.status, (json?.message ?? text.slice(0, 200)) || "request failed");
  return json;
}

// The whole answer: GraphQL reports per-field failures beside the data that did resolve.
export const graphql = (cx, query) => request(cx, GRAPHQL, "POST", { query });

// A mutation either applies or throws GitHub's reason.
export async function mutate(cx, query) {
  const json = await graphql(cx, query);
  if (json?.errors?.length) throw new Error(json.errors[0].message);
  return json?.data;
}

export const rest = (cx, method, path, body) => request(cx, `${REST}${path}`, method, body);
