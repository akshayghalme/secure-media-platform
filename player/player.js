// Minimal test harness for the secure media platform.
// Flow: POST /license → receive hex AES key → feed it to hls.js via a
// custom key loader → hls.js fetches the CloudFront signed manifest and
// decrypts segments with the key we supplied.

const $ = (id) => document.getElementById(id);
const statusEl = $("status");

function setStatus(msg, cls = "") {
  statusEl.textContent = msg;
  statusEl.className = cls;
}

function hexToBytes(hex) {
  // WHY: hls.js expects key material as an ArrayBuffer of raw bytes.
  // Our license server returns it as a hex string (see license.py).
  const clean = hex.replace(/\s+/g, "");
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.substr(i * 2, 2), 16);
  }
  return out.buffer;
}

async function fetchLicense(licenseUrl, contentId, userId, tier) {
  const res = await fetch(licenseUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      content_id: contentId,
      user_id: userId,
      subscription_tier: tier,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`license ${res.status}: ${body}`);
  }
  return res.json();
}

// Custom key loader: hls.js normally fetches the URI in EXT-X-KEY. We
// intercept and return the license-server-issued key instead. This is
// the integration point that makes the license server *the* source of
// truth for decryption, independent of whatever URI the manifest ships.
function makeKeyLoader(keyBytes) {
  return class CustomKeyLoader {
    constructor(config) { this.config = config; }
    destroy() {}
    abort() {}
    load(context, config, callbacks) {
      callbacks.onSuccess(
        { url: context.url, data: keyBytes },
        { trequest: 0, tfirst: 0, tload: 0, loaded: keyBytes.byteLength },
        context,
        null,
      );
    }
  };
}

async function play() {
  const licenseUrl = $("license-url").value.trim();
  const manifestUrl = $("manifest-url").value.trim();
  const contentId = $("content-id").value.trim();
  const userId = $("user-id").value.trim();
  const tier = $("tier").value.trim();

  if (!manifestUrl) {
    setStatus("Paste a signed CloudFront manifest URL first.", "err");
    return;
  }

  setStatus("Requesting license...");
  let license;
  try {
    license = await fetchLicense(licenseUrl, contentId, userId, tier);
  } catch (e) {
    setStatus(`License fetch failed: ${e.message}`, "err");
    return;
  }

  setStatus(
    `License issued.\n  license_id: ${license.license_id}\n  expires_at: ${license.expires_at}\nLoading manifest...`,
    "ok",
  );

  const video = $("video");
  if (!Hls.isSupported()) {
    // WHY fall back to native: Safari plays HLS directly but we can't
    // inject the key, so segments must be fetchable via the EXT-X-KEY
    // URI on their own. For the test harness, warn loudly.
    setStatus("hls.js not supported in this browser; native HLS will fetch the key via the manifest URI.", "err");
    video.src = manifestUrl;
    return;
  }

  const keyBytes = hexToBytes(license.decryption_key);

  const hls = new Hls({
    loader: Hls.DefaultConfig.loader,
    keyLoader: makeKeyLoader(keyBytes),
    // WHY withCredentials off: CloudFront signed URLs carry auth in the
    // query string, not cookies. Sending credentials would trip CORS.
    xhrSetup: (xhr) => { xhr.withCredentials = false; },
  });

  hls.on(Hls.Events.ERROR, (_, data) => {
    if (data.fatal) {
      setStatus(`hls.js fatal error: ${data.type} / ${data.details}`, "err");
    }
  });

  hls.loadSource(manifestUrl);
  hls.attachMedia(video);
  hls.on(Hls.Events.MANIFEST_PARSED, () => {
    setStatus(`Playing.\n  license_id: ${license.license_id}`, "ok");
    video.play().catch(() => {});
  });
}

document.getElementById("play").addEventListener("click", play);
