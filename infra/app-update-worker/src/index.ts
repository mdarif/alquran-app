export interface Env {
  APP_UPDATE_BUCKET: R2Bucket;
}

const OBJECT_KEY = 'app-update.json';
const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'public, max-age=300',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname !== '/app-update.json') {
      return new Response('Not Found', { status: 404 });
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: { allow: 'GET, HEAD' },
      });
    }

    const object = await env.APP_UPDATE_BUCKET.get(OBJECT_KEY);
    if (object === null) {
      return new Response('app-update.json not found', { status: 404 });
    }

    const headers = new Headers(JSON_HEADERS);
    headers.set('etag', object.httpEtag);

    if (request.method === 'HEAD') {
      return new Response(null, { headers });
    }
    return new Response(object.body, { headers });
  },
};
