#!/usr/bin/env python3
"""Read-only account quotas. stdout contains normalized usage, never credentials."""
import argparse
import base64
import ctypes
from decimal import Decimal, InvalidOperation
import hashlib
import json
import math
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request


class Unavailable(Exception):
    def __init__(self, message, code="unavailable", action=None):
        super().__init__(message)
        self.code = code
        self.action = action


def number(value):
    return (float(value) if isinstance(value, (int, float))
            and not isinstance(value, bool) and math.isfinite(value) and value >= 0 else None)


def window(label, percent, reset=None):
    n = number(percent)
    return {"label": label, "used": n, "reset": reset} if n is not None else None


def load_json(path):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        raise Unavailable("Cannot read sign-in data; sign in again in the provider app.")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward a bearer token/cookie to a redirected destination.
        raise Unavailable("Usage endpoint redirected; provider integration needs an update.")


def request(url, headers, body=None):
    payload = None
    sent = {"User-Agent": "HerdrUsageBar/1.0", **headers}
    if body is not None:
        payload = json.dumps(body).encode()
        sent.setdefault("Content-Type", "application/json")
    req = urllib.request.Request(url, data=payload, headers=sent)
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=10) as response:
            result = json.loads(response.read(1024 * 1024))
            if not isinstance(result, dict):
                raise Unavailable("Unexpected usage response; provider integration needs an update.")
            return result
    except urllib.error.HTTPError as e:
        if e.code == 401:
            raise Unavailable("Your sign-in was rejected or has expired (HTTP 401).", "expired",
                              "Sign in again in this provider's app, then refresh.")
        if e.code == 403:
            raise Unavailable("The provider refused access to usage (HTTP 403).", "forbidden",
                              "Check the account's subscription and usage permissions. This response alone does not confirm an inactive subscription.")
        if e.code == 429:
            raise Unavailable("The provider is rate limiting usage requests (HTTP 429).", "rate_limited", "Wait a few minutes, then refresh.")
        raise Unavailable("Provider returned HTTP " + str(e.code) + ".")
    except (urllib.error.URLError, TimeoutError, socket.timeout, OSError):
        raise Unavailable("The usage service could not be reached.", "offline", "Check your connection, then refresh.")
    except (ValueError, UnicodeError):
        raise Unavailable("Unexpected usage response; provider integration needs an update.")


def keychain(service, account=None, allow_prompt=False):
    """Read one exact macOS generic-password item. No browser/keychain scanning."""
    if sys.platform != "darwin":
        return None
    sec = ctypes.CDLL("/System/Library/Frameworks/Security.framework/Security")
    sec.SecKeychainSetUserInteractionAllowed.argtypes = [ctypes.c_bool]
    sec.SecKeychainSetUserInteractionAllowed(allow_prompt)
    sec.SecKeychainFindGenericPassword.argtypes = [ctypes.c_void_p, ctypes.c_uint32,
        ctypes.c_char_p, ctypes.c_uint32, ctypes.c_char_p,
        ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p]
    sec.SecKeychainItemFreeContent.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    service_b = service.encode()
    account_b = account.encode() if account else None
    size, data = ctypes.c_uint32(), ctypes.c_void_p()
    status = sec.SecKeychainFindGenericPassword(None, len(service_b), service_b,
        len(account_b) if account_b else 0, account_b, ctypes.byref(size), ctypes.byref(data), None)
    if status != 0:
        messages = {
            -25300: (f'macOS Keychain has no "{service}" item readable by this process.', "keychain_missing"),
            -25308: ("macOS Keychain requires interaction or is locked.", "keychain_locked"),
            -25293: ("macOS denied access to the saved sign-in item.", "keychain_denied"),
            -128: ("The Keychain request was cancelled.", "cancelled"),
        }
        message, code = messages.get(status, (f"macOS could not read the sign-in item (OSStatus {status}).", "keychain_error"))
        raise Unavailable(message, code, "Use the provider's own sign-in or a browser session instead. Granting Keychain access does not create a login.")
    try:
        return ctypes.string_at(data, size.value).decode("utf-8")
    finally:
        sec.SecKeychainItemFreeContent(None, data)


def decrypt_cursor(value, allow_prompt=False):
    if not value.startswith("cursor-safe-storage:"):
        return value
    if not value.startswith("cursor-safe-storage:v1:"):
        raise Unavailable("Unsupported Cursor credential format.")
    secret = keychain("Cursor Safe Storage", "Cursor", allow_prompt)
    if not secret:
        if allow_prompt:
            raise Unavailable("macOS did not provide Cursor's sign-in key. Unlock your login keychain and retry, or sign in again in Cursor.")
        raise Unavailable("Keychain access needed. Click Cursor, then Allow Keychain access.")
    payload = base64.b64decode(value.split(":", 2)[2], validate=True)
    if payload[:3] != b"v10" or not payload[3:] or len(payload[3:]) % 16:
        raise Unavailable("Unsupported Cursor encrypted credential.")
    key = hashlib.pbkdf2_hmac("sha1", secret.encode(), b"saltysalt", 1003, 16)
    crypto = ctypes.CDLL("/usr/lib/system/libcommonCrypto.dylib")
    crypto.CCCrypt.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_void_p,
        ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
    output = ctypes.create_string_buffer(len(payload))
    count = ctypes.c_size_t()
    status = crypto.CCCrypt(1, 0, 1, key, len(key), b" " * 16,
        payload[3:], len(payload) - 3, output, len(output), ctypes.byref(count))
    if status:
        raise Unavailable("Could not unlock Cursor sign-in data; sign in again in Cursor.")
    return output.raw[:count.value].decode("utf-8")


def parse_codex(data):
    rate = data.get("rate_limit") or {}
    windows = []
    for key, fallback in (("primary_window", "Current"), ("secondary_window", "7d")):
        item = rate.get(key) or {}
        seconds = number(item.get("limit_window_seconds"))
        label = ("7d" if seconds == 604800 else "5h" if seconds == 18000 else
                 str(int(seconds / 3600)) + "h" if seconds and seconds < 86400 else
                 str(int(seconds / 86400)) + "d" if seconds else fallback)
        w = window(label, item.get("used_percent"), item.get("reset_at"))
        if w:
            windows.append(w)
    return windows


def parse_codex_credits(data):
    credits = data.get("credits")
    if not isinstance(credits, dict):
        return None
    balance = credits.get("balance")
    # Display up to two decimals; never forward arbitrary backend text to the UI.
    normalized = None
    if isinstance(balance, (str, int, float)) and not isinstance(balance, bool) and len(str(balance)) <= 64:
        try:
            value = Decimal(str(balance))
            if value.is_finite() and 0 <= value <= Decimal("1e18"):
                normalized = format(value, ".2f").rstrip("0").rstrip(".")
        except InvalidOperation:
            pass
    has_credits = credits.get("has_credits")
    return {"balance": normalized, "has_credits": has_credits if isinstance(has_credits, bool) else None,
            "unlimited": credits.get("unlimited") is True}


def codex(allow_prompt=False):
    root = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    tokens = load_json(root / "auth.json").get("tokens") or {}
    token = tokens.get("access_token")
    if not token:
        raise Unavailable("Sign in with codex login. API-key accounts have no subscription quota here.")
    headers = {"Authorization": "Bearer " + token}
    if tokens.get("account_id"):
        headers["ChatGPT-Account-Id"] = tokens["account_id"]
    data = request("https://chatgpt.com/backend-api/wham/usage", headers)
    return {"windows": parse_codex(data), "credits": parse_codex_credits(data)}


def parse_claude(data):
    result = []
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        item = data.get(key) or {}
        w = window(label, item.get("utilization"), item.get("resets_at"))
        if w:
            result.append(w)
    return result


def claude(allow_prompt=False):
    root = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude"))
    credentials = load_json(root / ".credentials.json")
    if not credentials.get("claudeAiOauth"):
        service = "Claude Code-credentials"
        if "CLAUDE_CONFIG_DIR" in os.environ:
            # Claude Code suffixes the item with a hash of a non-default config dir.
            service += "-" + hashlib.sha256(os.environ["CLAUDE_CONFIG_DIR"].encode()).hexdigest()[:8]
        try:
            raw = keychain(service, allow_prompt=allow_prompt)
        except Unavailable as error:
            if error.code == "keychain_missing":
                raise Unavailable("No Claude Code subscription sign-in was found on this Mac.", "not_signed_in",
                                  "Run claude and sign in. Keychain permission does not activate a subscription or create a login.")
            raise Unavailable(error.args[0], error.code,
                              "Unlock your login keychain and retry, or sign in again through Claude Code. This does not establish whether the subscription is active.")
        if raw:
            credentials = json.loads(raw)
    token = (credentials.get("claudeAiOauth") or {}).get("accessToken")
    if not token:
        raise Unavailable("No Claude subscription sign-in token is saved.", "not_signed_in",
                          "Run claude and sign in to an account with Claude Code access. Keychain permission alone is not a login.")
    oauth = credentials.get("claudeAiOauth") or {}
    expires = number(oauth.get("expiresAt"))
    if expires and expires / 1000 <= time.time():
        raise Unavailable("Claude's saved sign-in has expired.", "expired", "Open Claude Code and sign in again; this mod does not renew credentials.")
    scopes = oauth.get("scopes")
    if isinstance(scopes, list) and "user:profile" not in scopes:
        raise Unavailable("This Claude token does not have permission to read subscription usage.", "missing_scope",
                          "Sign in through Claude Code. An API key or setup-token token cannot provide this usage view.")
    return parse_claude(request("https://api.anthropic.com/api/oauth/usage",
        {"Authorization": "Bearer " + token, "anthropic-beta": "oauth-2025-04-20"}))


def cursor_token(allow_prompt=False):
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    # Cursor CLI has an independent login; prefer its file over desktop decryption.
    cli_path = Path.home() / ".cursor/auth.json" if sys.platform == "darwin" else config / "cursor/auth.json"
    cli = load_json(cli_path).get("accessToken")
    if cli:
        return cursor_cookie(cli)
    # The macOS CLI normally uses these exact item names (verified in its source).
    cli_failure = None
    if sys.platform == "darwin":
        try:
            cli = keychain("cursor-access-token", "cursor-user", allow_prompt)
            if cli:
                return cursor_cookie(cli)
        except Unavailable as error:
            cli_failure = error
    db = (Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
          if sys.platform == "darwin" else config / "Cursor/User/globalStorage/state.vscdb")
    token = None
    if db.exists():
        # Read the live WAL when present; immutable only for a quiescent database.
        suffix = "?mode=ro" if Path(str(db) + "-wal").exists() else "?mode=ro&immutable=1"
        with sqlite3.connect(db.as_uri() + suffix, uri=True, timeout=1) as connection:
            row = connection.execute("SELECT value FROM ItemTable WHERE key=? LIMIT 1",
                                     ("cursorAuth/accessToken",)).fetchone()
        if row:
            token = row[0]
            if isinstance(token, bytes):
                token = token.decode("utf-16-le" if b"\x00" in token else "utf-8")
    if not token:
        raise cli_failure or Unavailable("No Cursor app or CLI sign-in was found.", "not_signed_in",
                                        "Run cursor-agent login, or connect using a copied browser session below.")
    try:
        token = decrypt_cursor(token, allow_prompt)
    except Unavailable as error:
        raise Unavailable(error.args[0], error.code,
                          "Try cursor-agent login, or use a copied browser session below. Desktop Keychain access is optional.")
    return cursor_cookie(token)


def cursor_cookie(token):
    # Accept an explicit cookie value as well as a CLI/app JWT.
    token = token.split("%3A%3A")[-1].split("::")[-1]
    try:
        part = token.split(".")[1]
        claims = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))
        if float(claims.get("exp", 0)) <= time.time() + 60:
            raise Unavailable("Cursor's saved sign-in has expired.", "expired", "Sign in again in Cursor or replace the saved browser session.")
        user = claims["sub"].split("|")[-1]
        if not user or any(not (c.isascii() and (c.isalnum() or c in "._-")) for c in user):
            raise ValueError()
    except (KeyError, IndexError, ValueError, TypeError):
        raise Unavailable("Invalid Cursor sign-in data; sign in again in Cursor.")
    return user + "%3A%3A" + token


def session_path():
    root = Path(os.environ.get("HERDR_APP_HOME", Path.home() / ".config/herdr-app"))
    return root / "data/usage-bar/cursor-session.json"


def save_copied_session():
    """Only called by the explicit Use copied browser session action; never log clipboard."""
    if sys.platform != "darwin":
        raise Unavailable("Clipboard connection is currently supported on macOS only.", "unsupported")
    result = subprocess.run(["/usr/bin/pbpaste"], capture_output=True, timeout=3)
    value = result.stdout.decode("utf-8").strip()
    if result.returncode or len(value) > 16384 or not value:
        raise Unavailable("The clipboard does not contain a usable session value.", "invalid_session",
                          "Copy only the WorkosCursorSessionToken cookie value from cursor.com, then try again.")
    if value.startswith("WorkosCursorSessionToken="):
        value = value.split("=", 1)[1].split(";", 1)[0]
    try:
        cookie = cursor_cookie(value)
    except (Unavailable, ValueError, UnicodeError):
        raise Unavailable("The copied value is not a current Cursor session.", "invalid_session",
                          "In your signed-in cursor.com tab, open DevTools → Application → Cookies and copy WorkosCursorSessionToken's value.")
    # Check the session with its provider before saving it, so a rejected cookie isn't retained.
    data = request("https://cursor.com/api/usage-summary", {"Cookie": "WorkosCursorSessionToken=" + cookie})
    path = session_path()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_name(".cursor-session-" + str(os.getpid()))
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w") as file:
            json.dump({"cookie": cookie}, file)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
    return data


def cycle_end(value):
    """Normalize a billing-cycle end to unix seconds, or leave an ISO timestamp."""
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        if text.isdigit():
            value = int(text)
        else:
            return text
    n = number(value)
    if n is None:
        return None
    return n / 1000 if n >= 1_000_000_000_000 else n


def pool_percent(primary, fallback, key):
    if isinstance(primary, dict) and key in primary and number(primary.get(key)) is not None:
        return primary.get(key)
    if isinstance(fallback, dict) and key in fallback and number(fallback.get(key)) is not None:
        return fallback.get(key)
    return None


def parse_cursor(data, current=None):
    summary = data if isinstance(data, dict) else {}
    current = current if isinstance(current, dict) else {}
    plan_usage = current.get("planUsage") if isinstance(current.get("planUsage"), dict) else {}
    plan = (summary.get("individualUsage") or {}).get("plan") or {}
    if not isinstance(plan, dict):
        plan = {}
    if plan.get("enabled") is False and not plan_usage:
        return []
    reset = cycle_end(current.get("billingCycleEnd")) or cycle_end(summary.get("billingCycleEnd"))
    windows = []
    for label, key in (("Auto", "autoPercentUsed"), ("Other", "apiPercentUsed")):
        w = window(label, pool_percent(plan_usage, plan, key), reset)
        if w:
            windows.append(w)
    if windows:
        return windows
    if plan.get("enabled") is False:
        return []
    percent = number(plan_usage.get("totalPercentUsed"))
    if percent is None:
        percent = number(plan.get("totalPercentUsed"))
    if percent is None:
        used, limit = number(plan.get("used")), number(plan.get("limit"))
        if used is not None and limit is not None and limit > 0:
            percent = used / limit * 100
    w = window("Total", percent, reset)
    return [w] if w else []


def cursor_usage(cookie):
    headers = {"Cookie": "WorkosCursorSessionToken=" + cookie}
    summary = request("https://cursor.com/api/usage-summary", headers)
    # The dashboard's current period is the live Auto / other-model split.
    # usage-summary can report a stale combined total for the same account.
    current = None
    try:
        current = request("https://cursor.com/api/dashboard/get-current-period-usage",
                          {**headers, "Origin": "https://cursor.com"}, {})
    except Unavailable:
        current = None
    return parse_cursor(summary, current)


def cursor(allow_prompt=False):
    saved = load_json(session_path()).get("cookie")
    if saved:
        return cursor_usage(cursor_cookie(saved))
    return cursor_usage(cursor_token(allow_prompt))


def collect(provider, allow_prompt=False, copied_session=False):
    try:
        if copied_session and provider == "cursor":
            save_copied_session()
        reading = {"codex": codex, "claude": claude, "cursor": cursor}[provider](allow_prompt)
        windows = reading.get("windows", []) if isinstance(reading, dict) else reading
        credits = reading.get("credits") if isinstance(reading, dict) else None
        if not windows and credits is None:
            raise Unavailable("The account responded, but did not report a supported subscription quota.", "no_quota",
                              "Check your plan on the provider's usage page. An inactive, API-only, unlimited or unsupported plan may have no percentage here.")
        result = {"provider": provider, "windows": windows, "updated": int(time.time()), "error": None}
        if provider == "codex":
            result["credits"] = credits
        return result
    except Unavailable as e:
        return {"provider": provider, "windows": [], "updated": None, "error": str(e),
                "code": e.code, "action": e.action}
    except Exception:
        # Never echo exceptions containing request URLs, headers or credential values.
        return {"provider": provider, "windows": [], "updated": None,
                "error": "The local usage reader could not complete the request.", "code": "reader_error",
                "action": "Check local file permissions and provider sign-in. No credential values are included in diagnostics."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provider", choices=["codex", "claude", "cursor"])
    parser.add_argument("--allow-keychain-prompt", action="store_true")
    parser.add_argument("--cursor-session-from-clipboard", action="store_true")
    args = parser.parse_args()
    print(json.dumps(collect(args.provider, args.allow_keychain_prompt, args.cursor_session_from_clipboard), allow_nan=False))
