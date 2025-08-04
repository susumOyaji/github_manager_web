export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const clientId = 'Ov23liYD9Ebaw5CEBdj8'; // Your GitHub App Client ID

    // Define CORS headers based on the request origin
    const origin = request.headers.get('Origin');
    const corsHeaders = {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, DELETE', // Add DELETE method
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Credentials': 'true',
    };

    // Handle CORS preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Route 1: /login
    if (url.pathname === '/login') {
      const redirectUri = url.searchParams.get('redirect_uri');
      if (!redirectUri) {
        return new Response('redirect_uri is required', { status: 400 });
      }
      const githubUrl = new URL('https://github.com/login/oauth/authorize');
      githubUrl.searchParams.set('client_id', clientId);
      githubUrl.searchParams.set('scope', 'repo read:user delete_repo');
      githubUrl.searchParams.set('state', redirectUri);
      return Response.redirect(githubUrl.toString(), 302);
    }

    // Route 2: /callback
    if (url.pathname === '/callback') {
      const code = url.searchParams.get('code');
      const state = url.searchParams.get('state');
      if (!code || !state) {
        return new Response('Missing code or state parameter', { status: 400 });
      }

      const response = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ client_id: clientId, client_secret: env.GITHUB_CLIENT_SECRET, code }),
      });

      const result = await response.json();
      if (result.error) {
        return new Response(JSON.stringify(result), { status: 400 });
      }

      const accessToken = result.access_token;
      const headers = {
        'Location': state,
        'Set-Cookie': `github_token=${accessToken}; HttpOnly; Path=/; SameSite=None; Secure`,
      };
      return new Response(null, { status: 302, headers });
    }

    // Route 3: /api/*
    if (url.pathname.startsWith('/api/')) {
      const cookie = request.headers.get('Cookie');
      if (!cookie || !cookie.includes('github_token=')) {
        return new Response('Not authenticated', { status: 401, headers: corsHeaders });
      }

      const accessToken = cookie.match(/github_token=([^;]+)/)[1];
      const githubApiUrl = 'https://api.github.com' + url.pathname.replace('/api', '');

      // Handle DELETE requests for repository deletion
      if (request.method === 'DELETE' && url.pathname.startsWith('/api/repos/')) {
        const githubResponse = await fetch(githubApiUrl, {
          method: 'DELETE',
          headers: {
            'Authorization': `token ${accessToken}`,
            'User-Agent': 'github-manager-web-worker',
            'Accept': 'application/vnd.github.v3+json',
          },
        });

        // Forward the response status from GitHub API
        return new Response(null, {
          status: githubResponse.status,
          statusText: githubResponse.statusText,
          headers: corsHeaders,
        });
      }

      // Handle GET requests
      const githubResponse = await fetch(githubApiUrl + url.search, {
        headers: { 'Authorization': `token ${accessToken}`, 'User-Agent': 'github-manager-web-worker', 'Accept': 'application/vnd.github.v3+json' },
      });

      // Clone the response to add CORS headers
      const responseWithCors = new Response(githubResponse.body, githubResponse);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        responseWithCors.headers.set(key, value);
      });
      responseWithCors.headers.set('Cache-Control', 'no-store'); // Prevent caching

      return responseWithCors;
    }

    return new Response('Not found.', { status: 404, headers: corsHeaders });
  },
};