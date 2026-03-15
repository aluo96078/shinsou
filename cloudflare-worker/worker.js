/**
 * Shinsou Proxy Worker — Cloudflare Workers 無伺服器轉發
 *
 * 部署步驟：
 * 1. 前往 https://dash.cloudflare.com → Workers & Pages → Create Application
 * 2. 選擇「Create Worker」→ 貼上此腳本
 * 3. 部署後取得 URL（如 https://shinsou-proxy.your-name.workers.dev）
 * 4. 在 App 設定中填入此 URL
 *
 * 請求格式：
 *   GET  https://your-worker.workers.dev/?url=<encoded_target_url>
 *   POST https://your-worker.workers.dev/?url=<encoded_target_url>  (body 直接轉發)
 *
 * 安全機制：
 *   - 可選 API Key 驗證（設定 PROXY_KEY 環境變數）
 *   - 僅允許 HTTP/HTTPS 目標
 *   - 請求頻率由 Cloudflare 自動管理
 *
 * 環境變數（可選）：
 *   PROXY_KEY — 設定後，請求必須帶 X-Proxy-Key 標頭才能使用
 */

export default {
  async fetch(request, env) {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: corsHeaders(),
      });
    }

    // API Key 驗證（如果設定了 PROXY_KEY）
    if (env.PROXY_KEY) {
      const key = request.headers.get("X-Proxy-Key");
      if (key !== env.PROXY_KEY) {
        return jsonError("Unauthorized", 401);
      }
    }

    // 解析目標 URL
    const reqUrl = new URL(request.url);
    const targetUrl = reqUrl.searchParams.get("url");

    if (!targetUrl) {
      return jsonError("Missing 'url' query parameter. Usage: ?url=<encoded_url>", 400);
    }

    let parsedTarget;
    try {
      parsedTarget = new URL(targetUrl);
    } catch {
      return jsonError("Invalid target URL", 400);
    }

    // 安全檢查：僅允許 http/https
    if (!["http:", "https:"].includes(parsedTarget.protocol)) {
      return jsonError("Only http/https targets allowed", 400);
    }

    // 構建轉發請求
    const forwardHeaders = new Headers();

    // 轉發所有安全的請求標頭
    const skipHeaders = new Set([
      "host", "cf-connecting-ip", "cf-ipcountry", "cf-ray",
      "cf-visitor", "x-forwarded-for", "x-forwarded-proto",
      "x-real-ip", "x-proxy-key", "connection",
    ]);

    for (const [key, value] of request.headers) {
      if (!skipHeaders.has(key.toLowerCase())) {
        forwardHeaders.set(key, value);
      }
    }

    // 設定目標 Host
    forwardHeaders.set("Host", parsedTarget.host);

    // 如果沒有 Referer，用目標網站的 origin
    if (!forwardHeaders.has("Referer")) {
      forwardHeaders.set("Referer", parsedTarget.origin + "/");
    }

    // 構建 fetch options
    const fetchOptions = {
      method: request.method,
      headers: forwardHeaders,
      redirect: "follow",
    };

    // POST/PUT/PATCH 帶 body
    if (["POST", "PUT", "PATCH"].includes(request.method)) {
      fetchOptions.body = await request.arrayBuffer();
    }

    try {
      const response = await fetch(parsedTarget.href, fetchOptions);

      // 構建回應，轉發所有標頭
      const responseHeaders = new Headers(response.headers);

      // 加入 CORS 標頭
      for (const [key, value] of Object.entries(corsHeaders())) {
        responseHeaders.set(key, value);
      }

      // 標記這是代理回應
      responseHeaders.set("X-Proxied-By", "shinsou-worker");
      responseHeaders.set("X-Original-Status", String(response.status));

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    } catch (err) {
      return jsonError(`Fetch failed: ${err.message}`, 502);
    }
  },
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Max-Age": "86400",
  };
}

function jsonError(message, status) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}
