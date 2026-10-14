# remote-access

Remote desktop for a Mac in the browser, behind Google sign-in.

```
browser → Caddy → gate (oauth2-proxy) → Guacamole → guacd → Mac Screen Sharing (VNC :5900)
```

Only accounts listed in `allowed-emails.txt` get past the gate. Guacamole trusts the email the gate passes along, so there is no second Guacamole password. You still log in to the Mac with its own macOS account when you open the connection.

## Requirements

- Docker (Docker Desktop on the Mac you want to reach)
- A hostname that points at this machine, such as a No-IP hostname kept current by the No-IP DUC app
- A Google Cloud project for the OAuth client

## Setup

1. **Google OAuth client.** In Google Cloud Console → Google Auth Platform → Clients, create a *Web application* client with this authorized redirect URI:
   `https://<PUBLIC_HOST>/remote/oauth2/callback`
   While the app is in Testing mode, add each allowed account as a test user under Audience. A newly created client can take a few minutes to start working.

2. **Settings.**
   ```sh
   cp .env.example .env                              # then fill it in
   cp allowed-emails.example.txt allowed-emails.txt  # one Google account per line
   ```

3. **Caddy.** Choose a mode with `COMPOSE_FILE` in `.env`:
   - **Bundled (the default).** The stack runs its own Caddy, which gets a Let's Encrypt certificate for `PUBLIC_HOST` automatically. You have nothing to configure here, but your router must forward ports **80 and 443** to this machine. Only one machine behind a router can receive them; to reach other computers on the same network, add them as connections instead (see below).
   - **Existing Caddy.** Set `COMPOSE_FILE=compose.yaml:compose.external-caddy.yaml` and `CADDY_NETWORK` to your Caddy's Docker network, then add this to your site block:
     ```
     redir /remote /remote/
     handle /remote/* {
         reverse_proxy remote-access-gate:4180
     }
     ```

4. **Start it.**
   ```sh
   docker compose up -d
   ```
   On first start the database seeds `ADMIN_EMAIL` as the Guacamole admin and adds a "This Mac" connection that points at the Docker host's port 5900. The seed only runs when the database volume is new.

5. **Enable screen sharing on the Mac.** System Settings → General → Sharing → **Screen Sharing**.
   If that toggle is greyed out because **Remote Management** is on, then Remote Management serves port 5900 instead. Under Remote Management → ⓘ → **Options…**, tick at least **Observe** and **Control**. Without them, VNC logins are refused even with the correct password.

## Adding more computers

In Guacamole, open your name → Settings → Connections → New Connection. Use VNC (port 5900) for Macs and RDP (port 3389) for Windows Pro. guacd must be able to reach the machine. A computer at another location can run its own copy of this stack under its own hostname. All your copies can share one Google OAuth client: add each copy's `https://<hostname>/remote/oauth2/callback` as another authorized redirect URI, and reuse the same client ID and secret.

## Notes

- `initdb/01-schema.sql` is the Apache Guacamole PostgreSQL schema (Apache License 2.0).
- Keep `.env` out of version control: it holds the OAuth client secret and the cookie and database secrets.
