#!/bin/bash

#!/bin/zsh
# SEEK Lite wrapper for Jamf → Python (no external deps)


# A small but mighty script that will fetch user details based on username / machine name and return them via swift dialog in Self Service.
# Very useful if other departments like finance keep bugging you about who has which machine, but also helpful for it support to troubleshoot machine issues
# as it displays macOS Version, last reboot, battery, ssd storage, etc 


# Add as a script in JAMF, create a policy and add 

# Parameter 4 = JAMF_URL
# Parameter 5 = API Client
# Parameter 6 = API Secret
# Parameter 7 = Optional, a webhook slack to send this info if required

# Copyright Gustavo Sanchez 2025


set -euo pipefail

PY="/usr/bin/python3"
DIALOG="/usr/local/bin/dialog"
SCRIPT="/private/tmp/seek_lite.py"

# Basic checks
[[ -x "$PY" ]] || { echo "[ERROR] python3 not found at $PY"; exit 1; }
[[ -x "$DIALOG" ]] || { echo "[ERROR] swiftDialog not found at $DIALOG"; exit 1; }

# Drop the Python to disk (overwrite each run)
cat > "$SCRIPT" <<'PYEOF'
#!/usr/bin/env python3
import sys, os, json, subprocess, socket
from urllib.request import Request, urlopen
from urllib.parse import urlencode, urlparse
from urllib.error import URLError, HTTPError

DIALOG = "/usr/local/bin/dialog"
DEBUG = os.getenv("SEEK_DEBUG", "0").lower() in ("1","true","yes")
REQ_TIMEOUT = 20

# -------- utilities
def console_user():
	try:
		p = subprocess.run(["/usr/bin/stat","-f%Su","/dev/console"],
							capture_output=True, text=True, timeout=3)
		return (p.stdout or "").strip()
	except Exception:
		return ""
def has_gui():
	cu = console_user()
	return bool(cu and cu != "root")

def normalize_url(u: str) -> str:
	raw = (u or "").strip().strip('"').strip("'")
	if not raw or raw in ("/", "https:", "http:"):
		raise ValueError("JAMF_URL invalid")
	t = raw if "://" in raw else f"https://{raw}"
	p = urlparse(t)
	if not p.hostname:
		raise ValueError("JAMF_URL missing host")
	return f"https://{p.hostname}"

def http_post_form(url, form, headers=None, timeout=REQ_TIMEOUT):
	body = urlencode(form).encode("utf-8")
	hdrs = {"Content-Type":"application/x-www-form-urlencoded"}
	if headers: hdrs.update(headers)
	req = Request(url, data=body, headers=hdrs, method="POST")
	try:
		with urlopen(req, timeout=timeout) as r:
			enc = r.headers.get_content_charset() or "utf-8"
			return json.loads(r.read().decode(enc)), r.status
	except HTTPError as e:
		if DEBUG:
			try: txt = e.read().decode("utf-8", "ignore")
			except Exception: txt = ""
			print(f"[ERROR] POST {url} -> HTTP {e.code}: {txt[:300]}")
		return None, e.code
	except URLError as e:
		if DEBUG: print(f"[ERROR] POST {url} -> URLError: {getattr(e,'reason',e)}")
		return None, None

def http_get_json(url, headers=None, timeout=REQ_TIMEOUT):
	req = Request(url, headers=headers or {}, method="GET")
	try:
		with urlopen(req, timeout=timeout) as r:
			enc = r.headers.get_content_charset() or "utf-8"
			return json.loads(r.read().decode(enc)), r.status
	except HTTPError as e:
		if DEBUG:
			try: txt = e.read().decode("utf-8", "ignore")
			except Exception: txt = ""
			print(f"[ERROR] GET {url} -> HTTP {e.code}: {txt[:300]}")
		return None, e.code
	except URLError as e:
		if DEBUG: print(f"[ERROR] GET {url} -> URLError: {getattr(e,'reason',e)}")
		return None, None

# -------- dialog helpers (with hard timeouts)
def dialog_json(args_list, timeout=180):
    try:
        p = subprocess.run(
            [DIALOG, *args_list, "--json"],
            capture_output=True, text=True, timeout=timeout
        )
        out = (p.stdout or "").strip()
        err = (p.stderr or "").strip()
        if DEBUG:
            if out:
                print("[DEBUG] dialog stdout:", out[:800])
            if err:
                print("[DEBUG] dialog stderr:", err[:800])
            print(f"[DEBUG] dialog returncode: {p.returncode}")
        # Always return a dict *and* the return code
        data = {}
        try:
            if out:
                data = json.loads(out)
        except Exception:
            pass
        data["_code"] = p.returncode
        return data
    except subprocess.TimeoutExpired:
        if DEBUG: print("[DEBUG] dialog timeout")
        return {"_code": 124}
    except Exception as e:
        if DEBUG: print(f"[DEBUG] dialog error: {e}")
        return {"_code": -1}

def get_search_term():
	if not has_gui():
		return ""
	j = dialog_json([
		"--title","SEEK – Lookup",
		"--icon","SF=person.crop.badge.magnifyingglass",
		"--ontop",
		"--message","Search by username (firstname.lastname), computer name, asset tag, or serial",
		"--textfield","Search term",
		"--button1text","Search","--button2text","Cancel",
	], timeout=180)
	return (j.get("textfield") or j.get("Search term") or "").strip()

def show_no_match():
	if not has_gui(): return
	subprocess.run([DIALOG,"--title","SEEK – No Match","--icon","SF=questionmark.circle",
					"--message","No device found for that search term.","--button1text","OK"],
					capture_output=True, text=True, timeout=30)

def show_results_and_decide(md_text: str) -> bool:
    if not has_gui():
        return False
    j = dialog_json([
        "--title","SEEK – Result",
        "--icon","SF=person.crop.badge.magnifyingglass",
        "--ontop",
        "--markdown","--message", md_text,
        "--width","600","--height","720",
        "--button1text","Close","--button2text","Send to Slack",
    ], timeout=300)

    if DEBUG:
        print("[DEBUG] dialog result:", json.dumps(j, indent=2))

    # Prefer exit code (reliable across versions)
    code = j.get("_code")
    if code == 2:
        return True           # button2 = Send to Slack
    if code in (0, 10, None):
        return False          # 0 = Close, 10 = window closed

    # Fallback to JSON key if present
    btn = (j.get("buttonPressed") or j.get("button") or "").strip().lower()
    return btn in ("send to slack", "2", "button2")

    # Dump what swiftDialog actually returned
    if DEBUG:
        print("[DEBUG] dialog result:", json.dumps(j, indent=2))

    # swiftDialog may return button index or label depending on version/flags
    btn = (j.get("buttonPressed") or j.get("button") or j.get("exitCode") or "").strip()

    # Accept multiple possible encodings of the second button
    # - "Send to Slack" (label)
    # - "2" or 2 (second button index)
    # - "button2"
    if isinstance(btn, int):
        return btn == 2
    btn_lower = str(btn).lower()
    return btn_lower in ("send to slack", "2", "button2")


# -------- Jamf API
def get_token(base, cid, secret):
	if DEBUG:
		print(f"[DEBUG] Jamf URL: {base}")
		print(f"[DEBUG] Client ID len: {len(cid)}  Secret len: {len(secret)}")
	url = f"{base}/api/oauth/token"
	data, status = http_post_form(url, {
		"grant_type":"client_credentials",
		"client_id": cid,
		"client_secret": secret
	})
	if data and status == 200:
		tok = data.get("access_token","")
		if DEBUG: print("[DEBUG] token len:", len(tok))
		return tok
	# retry once
	if DEBUG: print("[DEBUG] token request retrying once…")
	data, status = http_post_form(url, {
		"grant_type":"client_credentials",
		"client_id": cid,
		"client_secret": secret
	})
	if data and status == 200:
		return data.get("access_token","")
	raise RuntimeError(f"Jamf token request failed (status={status})")

def jamf_get(base, path, headers, params=None):
	from urllib.parse import urlencode
	if params:
		url = f"{base}{path}?{urlencode(params, doseq=True)}"
	else:
		url = f"{base}{path}"
	data, status = http_get_json(url, headers=headers)
	if DEBUG: print(f"[DEBUG] GET {path} -> {status}")
	if status != 200: return None
	return data

def computers_inventory_search(base, token, term):
	headers = {"Authorization": f"Bearer {token}"}
	sections = ["GENERAL","HARDWARE","OPERATING_SYSTEM","USER_AND_LOCATION",
				"STORAGE","EXTENSION_ATTRIBUTES","LOCAL_USER_ACCOUNTS"]
	def params_with(filter_expr, page_size=1):
		ps = [("page",0),("page-size",page_size),("filter",filter_expr)]
		for s in sections: ps.append(("section", s))
		return ps
	safe = term.replace('\\','\\\\').replace('"','\\"')
	exact = [
		f'userAndLocation.username=="{safe}"',
		f'userAndLocation.realname=="{safe}"',
		f'localUserAccounts.username=="{safe}"',
		f'general.name=="{safe}"',
		f'general.assetTag=="{safe}"',
		f'hardware.serialNumber=="{safe}"',
	]
	like = [
		f'userAndLocation.username=like="*{safe}*"',
		f'userAndLocation.realname=like="*{safe}*"',
		f'localUserAccounts.username=like="*{safe}*"',
		f'general.name=like="*{safe}*"',
		f'general.assetTag=like="*{safe}*"',
		f'hardware.serialNumber=like="*{safe}*"',
	]
	for f in exact:
		if DEBUG: print("[DEBUG] Trying exact:", f)
		data = jamf_get(base, "/api/v1/computers-inventory", headers, params_with(f))
		if data and data.get("results"): return data["results"][0]
	for f in like:
		if DEBUG: print("[DEBUG] Trying like:", f)
		data = jamf_get(base, "/api/v1/computers-inventory", headers, params_with(f, page_size=10))
		if data and data.get("results"): return data["results"][0]
	return None

def fetch_detail(base, token, comp_id):
	headers = {"Authorization": f"Bearer {token}"}
	return jamf_get(base, f"/api/v1/computers-inventory-detail/{comp_id}", headers)

def fetch_sections(base, token, comp_id, sects):
	headers = {"Authorization": f"Bearer {token}"}
	params = [("page",0),("page-size",1),("filter", f'id=="{comp_id}"')]
	for s in sects: params.append(("section", s))
	data = jamf_get(base, "/api/v1/computers-inventory", headers, params)
	if data and data.get("results"): return data["results"][0]
	return {}

# -------- parsing helpers
def ea_lookup(detail, name_contains):
	needle = (name_contains or "").lower()
	buckets = [
		(detail.get("general") or {}).get("extensionAttributes", []),
		(detail.get("userAndLocation") or {}).get("extensionAttributes", []),
		(detail.get("purchasing") or {}).get("extensionAttributes", []),
		detail.get("extensionAttributes", []) or [],
	]
	for arr in buckets:
		for e in arr or []:
			nm = str(e.get("name",""))
			if needle in nm.lower():
				vals = e.get("values")
				if isinstance(vals, list) and vals:
					for v in vals:
						s = str(v).strip()
						if s: return s
				v = e.get("value")
				if isinstance(v, str) and v.strip():
					return v.strip()
	return "Unknown"

def fmt_gb(mb):
	try: return f"{int(round(float(mb)/1024)):d} GB"
	except Exception: return "Unknown"

def encrypted_status(detail, sections):
	try:
		de = detail.get("diskEncryption",{}) or {}
		boot = (de.get("bootPartitionEncryptionDetails") or {}).get("partitionFileVault2State")
		if boot and str(boot).upper() == "ENCRYPTED": return "Yes"
		storage = detail.get("storage",{}) or {}
		for d in storage.get("disks",[]) or []:
			for p in d.get("partitions",[]) or []:
				if str(p.get("fileVault2State","")).upper() == "ENCRYPTED": return "Yes"
	except Exception: pass
	try:
		fv = ((sections.get("operatingSystem") or {}).get("fileVault") or {}).get("enabled")
		if isinstance(fv,bool): return "Yes" if fv else "No"
	except Exception: pass
	return "Unknown"

def parse_fields(primer, detail, sect):
	g  = (detail.get("general") or {})
	ul = (detail.get("userAndLocation") or {})
	h  = (sect.get("hardware") or {})

	os_version = ((detail.get("operatingSystem") or {}).get("version") or
			( (sect.get("operatingSystem") or {}).get("version") ) or
			"Unknown")

	username = ul.get("username") or g.get("lastLoggedInUsernameBinary") or \
				((primer.get("userAndLocation") or {}).get("username")) or "Unknown"
	serial = h.get("serialNumber") or ((primer.get("hardware") or {}).get("serialNumber")) or "Unknown"
	# disk
	disk = "Unknown"
	st = detail.get("storage") or {}
	if st.get("bootDriveAvailableSpaceMegabytes") is not None:
		disk = fmt_gb(st.get("bootDriveAvailableSpaceMegabytes"))
	else:
		try:
			for d in st.get("disks",[]) or []:
				for p in d.get("partitions",[]) or []:
					if p.get("partitionType") == "BOOT" and p.get("availableMegabytes") is not None:
						disk = fmt_gb(p.get("availableMegabytes")); raise StopIteration
		except StopIteration:
			pass
	fields = {
		"Username": username,
		"Machine Name": g.get("name") or ((primer.get("general") or {}).get("name")) or "Unknown",
		"Asset Tag": g.get("assetTag", "—"),
		"Serial": serial,
		"macOS Version": os_version,
		"Last Reboot": ea_lookup(detail, "last reboot"),
		"Battery Health Status": ea_lookup(detail, "battery health status"),
		"Disk Free": disk,
		"Encrypted": encrypted_status(detail, sect),
		"Last Patchomator Run": ea_lookup(detail, "patchomator"),
		"Device Lifecycle": ea_lookup(detail, "lifecycle"),
		"Automatic Updates": ea_lookup(detail, "automatic update"),
		"Jamf URL": f"{BASE}/computers.html?id={(detail.get('id') or primer.get('id'))}&o=r",
	}
	if DEBUG: print("[DEBUG] parsed fields:", json.dumps(fields, indent=2))
	return fields

def build_md(fields: dict) -> str:
	def fmt(v): 
		if v is None: return "—"
		s = str(v).strip()
		return "—" if (not s or s.lower()=="unknown") else s
	parts = [
		"### SEEK Result",
		"### Identity",
		f"- **Username:** {fmt(fields.get('Username'))}",
		f"- **Machine Name:** {fmt(fields.get('Machine Name'))}",
		f"- **Asset Tag:** {fmt(fields.get('Asset Tag'))}",
		f"- **Serial:** {fmt(fields.get('Serial'))}",
		"### Status",
		f"- **macOS Version:** {fmt(fields.get('macOS Version'))}",
		f"- **Last Reboot:** {fmt(fields.get('Last Reboot'))}",
		f"- **Battery Health Status:** {fmt(fields.get('Battery Health Status'))}",
		f"- **Disk Free:** {fmt(fields.get('Disk Free'))}",
		f"- **Encrypted:** {fmt(fields.get('Encrypted'))}",
		"### Extension Attributes",
		f"- **Last Patchomator Run:** {fmt(fields.get('Last Patchomator Run'))}",
		f"- **Device Lifecycle:** {fmt(fields.get('Device Lifecycle'))}",
		f"- **Automatic Updates:** {fmt(fields.get('Automatic Updates'))}",
	]
	if fields.get("Jamf URL"):
		parts.append(f"[Open in Jamf]({fields['Jamf URL']})")
	return "\n".join(parts)




# -------- post toslack
def post_slack(webhook, team, fields):
    # Validate webhook
    w = (webhook or "").strip()
    if not w.startswith("https://hooks.slack.com/services/"):
        print(f"[ERROR] Invalid Slack webhook URL: {w!r}")
        return

    # Quick reachability check (helps catch firewall/proxy issues)
    try:
        socket.create_connection(("hooks.slack.com", 443), timeout=5).close()
    except Exception as e:
        print(f"[ERROR] Cannot reach hooks.slack.com:443 -> {e}")
        return

    # Build Block Kit + fallback text
    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": f"SEEK Result — {team}", "emoji": True}
        },
        {"type": "divider"}
    ]
    for k, v in fields.items():
        if k == "Jamf URL":
            continue
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*{k}:* {v if v not in (None,'') else '—'}"}
        })
    if fields.get("Jamf URL"):
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"<{fields['Jamf URL']}|Open in Jamf>"}
        })

    payload = {
        "text": f"SEEK Result — {team}",  # fallback for notifications/search
        "blocks": blocks
    }

    if DEBUG:
        print("[DEBUG] Slack webhook:", w)
        print("[DEBUG] Slack payload:\n", json.dumps(payload, indent=2))

    req = Request(w, data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=REQ_TIMEOUT) as r:
            status = getattr(r, "status", None)
            body = r.read().decode("utf-8", "ignore")
            # Slack webhooks usually return "ok"
            print(f"[DEBUG] Slack HTTP status: {status}  body: {body}")
    except HTTPError as e:
        err = e.read().decode("utf-8", "ignore")
        print(f"[ERROR] Slack HTTP {e.code}: {err}")
    except URLError as e:
        print(f"[ERROR] Slack URL error: {getattr(e, 'reason', e)}")
    except Exception as e:
        print(f"[ERROR] Slack post error: {e}")


# -------- main
def main():
	# args come from wrapper: argv[1..5] = URL, ID, SECRET, WEBHOOK, TEAM
	if len(sys.argv) < 6:
		print("[ERROR] Missing parameters from wrapper.")
		sys.exit(2)
	global BASE
	BASE = normalize_url(sys.argv[1])
	cid, secret, webhook, team = sys.argv[2:6]

	# GUI prompt (no input() fallback)
	term = get_search_term()
	if not term:
		show_no_match(); return

	token = get_token(BASE, cid, secret)
	primer = computers_inventory_search(BASE, token, term)
	if not primer:
		show_no_match(); return

	comp_id = primer.get("id") or ((primer.get("general") or {}).get("id"))
	if DEBUG: print("[DEBUG] matched id:", comp_id)

	detail = fetch_detail(BASE, token, comp_id) or {}
	sections = fetch_sections(BASE, token, comp_id, ["HARDWARE","OPERATING_SYSTEM"]) or {}

	fields = parse_fields(primer, detail, sections)
	md = build_md(fields)
	if show_results_and_decide(md) and webhook:
		post_slack(webhook, team, fields)

if __name__ == "__main__":
	try:
		main()
	except Exception as e:
		print(f"[ERROR] {e}")
		sys.exit(1)
PYEOF
chmod 755 "$SCRIPT"

# Forward Jamf params $4..$8 to Python argv[1..5]
# Optional: export SEEK_DEBUG=1 for one run to see verbose logs
export SEEK_DEBUG="${SEEK_DEBUG:-1}"
exec "$PY" -u "$SCRIPT" "$4" "$5" "$6" "$7" "$8"
