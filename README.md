# remote-access

Remote desktop for a Mac in the browser, behind Google sign-in.

```
browser → Caddy → gate (oauth2-proxy) → Guacamole → guacd → Mac Screen Sharing (VNC :5900)
```

Only accounts listed in `allowed-emails.txt` get past the gate. Guacamole trusts the email the gate passes along, so there is no second Guacamole password. You still log in to the Mac with its own macOS account when you open the connection.

## Requirements

- Docker (Docker Desktop on the Mac you want to reach)
- A Caddy container already serving your domain over HTTPS, on a Docker network this stack can join
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

3. **Caddy.** Route `/remote` to the gate:
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

In Guacamole, open your name → Settings → Connections → New Connection. Use VNC (port 5900) for Macs and RDP (port 3389) for Windows Pro. guacd must be able to reach the machine. For computers on other networks, a private network such as Tailscale on both ends works well.

## Notes

- `initdb/01-schema.sql` is the Apache Guacamole PostgreSQL schema (Apache License 2.0).
- Keep `.env` out of version control: it holds the OAuth client secret and the cookie and database secrets.
