// Proxies the KMA (기상청) 단기예보 API so the real data.go.kr service key
// lives only in this Worker's secret store, never inside the shipped iOS
// app — anyone can decompile an app binary and read out an embedded key,
// but they can't read a secret bound to someone else's Worker.
//
// Deploy:
//   wrangler secret put KMA_SERVICE_KEY   (paste the real key when prompted)
//   wrangler deploy

const KMA_BASE_URL = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0";

// Only these three endpoints are ever forwarded — anything else is rejected
// so this can't be used as an open relay to arbitrary data.go.kr paths.
const ALLOWED_PATHS = new Set(["getUltraSrtNcst", "getVilageFcst", "getUltraSrtFcst"]);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/^\/+/, "");

    if (path === "") {
      return new Response("Manana KMA proxy is running.", { status: 200 });
    }
    if (!ALLOWED_PATHS.has(path)) {
      return new Response("Not found", { status: 404 });
    }

    const upstream = new URL(`${KMA_BASE_URL}/${path}`);
    for (const [key, value] of url.searchParams) {
      if (key === "serviceKey") continue; // never trust a client-supplied key
      upstream.searchParams.set(key, value);
    }
    upstream.searchParams.set("serviceKey", env.KMA_SERVICE_KEY);

    const response = await fetch(upstream.toString());
    return new Response(response.body, {
      status: response.status,
      headers: { "content-type": response.headers.get("content-type") ?? "application/json" },
    });
  },
};
