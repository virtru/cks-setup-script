# CKS Setup Script

## Instructions

1. Download the script to the host.

```
curl -s https://raw.githubusercontent.com/virtru-corp/cks-setup-script/main/download.sh -o download.sh
```

2. Run the download script with Bash

```
bash ./download.sh
```

### Initial Setup

1. Run the setup script with Bash

```
bash ./cks-setup-scripts/setup-cks-latest.sh
```

### Updates

1. Run the update script with Bash

```
bash ./cks-setup-scripts/update.sh
```

---

## KAS Support

The setup scripts support deploying CKS with integrated Key Access Service (KAS) for Data Security Platform (DSP) integration. KAS enables advanced features like attribute-based access control and integration with Virtru's Data Security Platform.

### Enabling KAS During Initial Setup

When running `setup-cks-latest.sh`, you'll be prompted:

```
Do you want to enable KAS [yes/no]?
```

Answer **yes** to enable KAS. The setup will automatically configure KAS with standard settings:
- OAuth Issuer: `https://login.virtru.com/oauth2/default`
- OAuth Audience: `https://api.virtru.com`
- Platform Endpoint: `http://localhost:8080` (internal)
- KAS Registry Name: `customer-kas`
- KAS URI: Same as your CKS URL (derived from SSL certificate)

**Optional Configuration (for automatic provisioning):**
- **OAuth Client ID** - OAuth2 client ID with DSP admin permissions
- **OAuth Client Secret** - OAuth2 client secret

If you skip the OAuth credentials during setup, you can add them later to enable automatic provisioning.

### Adding KAS to Existing CKS Deployment

To add KAS to an existing CKS-only deployment:

1. Run the update script:
   ```bash
   bash ./cks-setup-scripts/update.sh
   ```

2. When prompted, answer **yes** to enable KAS

3. The script will automatically:
   - Create a backup of your existing configuration
   - Configure KAS with standard settings (no manual input needed)
   - Add KAS environment variables to `env/cks.env`
   - Update `run.sh` with KAS-enabled configuration
   - Preserve all existing CKS keys and configuration

4. Optionally provide OAuth credentials for automatic provisioning

5. Apply the changes manually:
   ```bash
   docker stop Virtru_CKS
   docker rm Virtru_CKS
   bash /path/to/working-dir/run.sh
   ```

**Important:** Migration is safe and preserves your existing CKS keys and configuration. Your CKS data remains accessible after enabling KAS.

### Architecture Differences

Both CKS-only and CKS+KAS deployments use the same Docker image: `containers.virtru.com/cks:v{VERSION}`

KAS is conditionally enabled based on the presence of `KAS_ROOT_KEY` in the environment configuration.

#### CKS-Only Deployment
- **Docker Image:** `containers.virtru.com/cks:v{VERSION}`
- **Services:** Orchestrated by supervisord:
  - CKS (Node.js application on internal port 3000)
  - Caddy (reverse proxy on external port 9000)
- **Port:** External port 443 → Internal port 9000 (Caddy) → Port 3000 (CKS)
- **Database:** None required
- **Routing:** Caddy routes all traffic to CKS

#### CKS+KAS Deployment
- **Docker Image:** `containers.virtru.com/cks:v{VERSION}` (same image, KAS enabled via env vars)
- **Services:** Multiple services orchestrated by supervisord:
  - PostgreSQL (internal database on port 5432)
  - CKS (Node.js application on internal port 3000)
  - KAS (Go service on internal port 8080)
  - Caddy (reverse proxy on external port 9000)
  - kas-provisioning (automatic DSP registration)
- **Port:** External port 443 → Internal port 9000 (Caddy) → Port 3000 (CKS) or 8080 (KAS)
- **Database:** PostgreSQL included in container
- **Trigger:** KAS, PostgreSQL, and provisioning only run when `KAS_ROOT_KEY` is set in environment

#### Traffic Routing

Caddy reverse proxy routes incoming traffic:
- **CKS Endpoints** → Port 3000 (CKS service)
  - `/rewrap`
  - `/bulk-rewrap`
  - `/public-keys`
  - `/key-pairs`
  - `/status`
  - `/healthz`
  - `/docs`
- **All Other Traffic** → Port 8080 (KAS service)

### Provisioning Workflow

When KAS is enabled, the kas-provisioning service automatically registers KAS with the DSP platform on container startup.

#### Automatic Provisioning Steps

The provisioning script performs 6 steps:

1. **OAuth2 Token Acquisition** - Obtains access token from configured OIDC issuer
2. **KAS Health Check** - Waits for KAS service to be ready (with retry logic)
3. **Namespace Creation** - Creates DSP namespace: `{ORG_ID}.kas.virtru.com`
4. **Attribute Creation** - Creates attributes with `allow_traversal` flag
5. **KAS Registry Entry** - Registers KAS in platform registry with name and URI
6. **Key Import** - Imports and wraps cryptographic keys, sets as base key

#### Manual Provisioning

If OAuth credentials were not provided during setup, you can provision KAS manually:

1. **Edit the environment file:**
   ```bash
   vi /path/to/working-dir/env/cks.env
   ```

2. **Set OAuth credentials:**
   ```bash
   CLIENT_ID=your-client-id
   CLIENT_SECRET=your-client-secret
   ```

3. **Restart the container:**
   ```bash
   docker restart Virtru_CKS
   ```

4. **Monitor provisioning:**
   ```bash
   docker logs -f Virtru_CKS
   ```

The provisioning service runs automatically on startup when credentials are configured.

### Troubleshooting

#### KAS Not Starting

**Symptom:** KAS service shows as "sleeping" in logs

**Solution:**
- Verify `KAS_ROOT_KEY` is set in `env/cks.env`
- Check that all required KAS environment variables are present
- Review logs: `docker logs Virtru_CKS`

#### Provisioning Failures

**Symptom:** Errors in logs during provisioning steps

**Common Causes & Solutions:**
1. **Invalid OAuth Credentials**
   - Verify `CLIENT_ID` and `CLIENT_SECRET` are correct
   - Ensure the OAuth client has DSP admin permissions
   - Check that the client has `dsp_role` group claim

2. **Platform Endpoint Unreachable**
   - Verify `PLATFORM_ENDPOINT` URL is correct
   - Check network connectivity to platform
   - Ensure firewall allows outbound HTTPS traffic

3. **OAuth Token Issues**
   - Verify `KAS_AUTH_ISSUER` matches your OIDC provider
   - Check that `KAS_AUTH_AUDIENCE` matches the expected audience

#### CKS Endpoints Not Working

**Symptom:** CKS endpoints return errors or timeout

**Solution:**
- Verify Caddy reverse proxy is running:
  ```bash
  docker exec Virtru_CKS supervisorctl status caddy
  ```
- Check CKS service status:
  ```bash
  docker exec Virtru_CKS supervisorctl status cks
  ```
- Review Caddy logs for routing errors

#### Checking Service Status

To check the status of individual services within the kas-bundle:

```bash
docker exec Virtru_CKS supervisorctl status
```

This shows the status of all services:
- `postgres` - Database
- `cks` - CKS application
- `kas` - KAS service
- `caddy` - Reverse proxy
- `kas-provisioning` - Provisioning script (runs once)

#### Viewing Service Logs

To view logs for a specific service:

```bash
# All logs
docker logs Virtru_CKS

# Follow logs in real-time
docker logs -f Virtru_CKS

# View supervisor logs
docker exec Virtru_CKS cat /var/log/supervisor/supervisord.log
```

#### Retry Configuration

Provisioning includes retry logic with exponential backoff. These are configurable via environment variables:

- `KAS_PROVISIONING_DELAY` - Initial delay before provisioning starts (default: 10s)
- `KAS_RETRY_ATTEMPTS` - Number of retry attempts (default: 8)
- `KAS_RETRY_BACKOFF` - Initial backoff between retries (default: 2s)
- `KAS_RETRY_BACKOFF_MAX` - Maximum backoff between retries (default: 30s)

Edit these in `env/cks.env` and restart the container to apply changes.

---

## Version Compatibility

Both CKS-only and CKS+KAS deployments use the same Docker image:
- **Image:** `containers.virtru.com/cks:v{VERSION}`
- **Example:** `containers.virtru.com/cks:v1.29.0`

KAS is conditionally enabled within the same image based on environment configuration. When updating, both deployment types use the same VERSION file and Docker image.
