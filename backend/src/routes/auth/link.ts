/**
 * GET /auth/link/:code
 *
 * User visits this URL to start the Discord OAuth flow.
 * Redirects to Discord OAuth with PKCE.
 */

import { Hono } from 'hono';
import type { Env } from '../../env';
import {
  getAuthSession,
  updateAuthSessionState,
} from '../../services/authSession';
import { generatePkceCodeChallenge } from '../../crypto';
import { renderErrorPage } from './utils';

const linkRoute = new Hono<{ Bindings: Env }>();

/**
 * GET /link/:code
 *
 * User visits this URL to start the Discord OAuth flow.
 * Redirects to Discord OAuth with PKCE.
 */
linkRoute.get('/:code', async (c) => {
  const code = c.req.param('code');

  // Get the session
  const session = await getAuthSession(c.env.DB, code);
  if (!session) {
    return c.html(renderErrorPage('Link not found'), 404);
  }

  // Check expiration
  if (session.expiresAt < Date.now()) {
    return c.html(renderErrorPage('This link has expired. Please start over.'), 410);
  }

  // Check state is pending (prevent reuse)
  if (session.state !== 'pending') {
    return c.html(renderErrorPage('This link has already been used.'), 400);
  }

  // Update state to 'started' in DB
  await updateAuthSessionState(c.env.DB, code, 'started');

  // Generate PKCE code challenge from verifier
  const codeChallenge = await generatePkceCodeChallenge(session.codeVerifier);

  // Build Discord OAuth URL
  const params = new URLSearchParams({
    client_id: c.env.DISCORD_CLIENT_ID,
    redirect_uri: c.env.DISCORD_REDIRECT_URI,
    response_type: 'code',
    scope: 'identify sdk.social_layer_presence',
    state: code,  // Our session code links callback back to session
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });

  return c.redirect(`https://discord.com/oauth2/authorize?${params}`);
});

export { linkRoute };
