-- Migration: 0001_initial
-- Description: Initial schema for Studio Activity API
-- Created: 2024-12-28

-- Users table: Each plugin installation is a unique user
CREATE TABLE users (
  id TEXT PRIMARY KEY,                    -- UUID v4
  auth_token_hash TEXT NOT NULL UNIQUE,   -- SHA-256 hash of active auth token
  pending_token_hash TEXT,                -- SHA-256 hash of pending token (for rotation)
  pending_token_expires INTEGER,          -- Unix timestamp when pending token expires
  created_at INTEGER NOT NULL,            -- Unix timestamp
  updated_at INTEGER NOT NULL,            -- Unix timestamp
  last_activity_at INTEGER NOT NULL       -- Unix timestamp of last API call
);

-- Index for cleanup job (find inactive accounts)
CREATE INDEX idx_users_last_activity ON users(last_activity_at);

-- Index for pending token cleanup
CREATE INDEX idx_users_pending_expires ON users(pending_token_expires)
  WHERE pending_token_expires IS NOT NULL;


-- Discord accounts table: Linked Discord accounts for each user
CREATE TABLE discord_accounts (
  id TEXT PRIMARY KEY,                    -- UUID v4
  user_id TEXT NOT NULL,                  -- FK → users.id
  discord_user_id_hash TEXT NOT NULL UNIQUE, -- SHA-256(discord_id + salt) for deduplication
  access_token_enc TEXT NOT NULL,         -- AES-GCM encrypted OAuth access token
  refresh_token_enc TEXT NOT NULL,        -- AES-GCM encrypted OAuth refresh token
  token_expires_at INTEGER NOT NULL,      -- Unix timestamp when access token expires
  created_at INTEGER NOT NULL,            -- Unix timestamp
  updated_at INTEGER NOT NULL,            -- Unix timestamp

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Index for finding accounts by user
CREATE INDEX idx_discord_accounts_user ON discord_accounts(user_id);


-- Auth sessions table: Temporary state during OAuth flow
CREATE TABLE auth_sessions (
  code TEXT PRIMARY KEY,                  -- Random code for the auth URL (used by plugin/SSE)
  user_id TEXT,                           -- FK → users.id (NULL for new users)
  state TEXT NOT NULL,                    -- 'pending' | 'started' | 'completed' | 'failed'
  completion_code TEXT,                   -- 5-digit code shown to user for manual entry
  pkce_code_verifier TEXT NOT NULL,       -- PKCE code verifier for OAuth
  result_token TEXT,                      -- Auth token to return (for new users only)
  result_client_key TEXT,                 -- Client encryption key (for new users only)
  error_message TEXT,                     -- Error message if state = 'failed'
  expires_at INTEGER NOT NULL,            -- Unix timestamp when session expires (5 min)
  created_at INTEGER NOT NULL,            -- Unix timestamp

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Index for cleanup job (find expired sessions)
CREATE INDEX idx_auth_sessions_expires ON auth_sessions(expires_at);
