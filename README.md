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
- KAS URI: Same as your CKS URL (derived from SSL certificate)

KAS will automatically bootstrap itself on startup — it registers with the DSP platform, creates the necessary namespace, attributes, and imports keys. No manual provisioning steps or OAuth client credentials are required.

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

4. Apply the changes:
   ```bash
   docker stop Virtru_CKS
   docker rm Virtru_CKS
   bash /path/to/working-dir/run.sh
   ```

**Important:** Migration is safe and preserves your existing CKS keys and configuration. Your CKS data remains accessible after enabling KAS.

### Architecture

Both CKS-only and CKS+KAS deployments use the same Docker image: `containers.virtru.com/cks:v{VERSION}`

KAS is conditionally enabled based on the presence of `KAS_ROOT_KEY` in the environment configuration. If `KAS_ROOT_KEY` is not set, the KAS process remains dormant with no error logs.

#### CKS-Only Deployment
- **Services:** Orchestrated by supervisord:
  - CKS (Node.js application on internal port 3000)
  - Caddy (reverse proxy on external port 9000)
- **Port:** External port 443 → Internal port 9000 (Caddy) → Port 3000 (CKS)
- **Database:** None required

#### CKS+KAS Deployment
- **Services:** Multiple services orchestrated by supervisord:
  - PostgreSQL (internal database on port 5432)
  - CKS (Node.js application on internal port 3000)
  - KAS (Go service on internal port 8080)
  - Caddy (reverse proxy on external port 9000)
- **Port:** External port 443 → Internal port 9000 (Caddy) → Port 3000 (CKS) or 8080 (KAS)
- **Database:** PostgreSQL included in container
- **Bootstrap:** KAS automatically registers with DSP, creates namespace/attributes, and imports keys on startup

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

### Troubleshooting

#### KAS Not Starting

**Symptom:** KAS service shows as "sleeping" in logs

**Solution:**
- Verify `KAS_ROOT_KEY` is set in `env/cks.env`
- Check that all required KAS environment variables are present
- Review logs: `docker logs Virtru_CKS`

#### Bootstrap Failures

**Symptom:** Errors in KAS logs during startup

**Common Causes & Solutions:**
1. **Auth Configuration**
   - Verify `KAS_AUTH_ISSUER` matches your OIDC provider
   - Check that `KAS_AUTH_AUDIENCE` matches the expected audience

2. **Key Files Missing**
   - Verify `KAS_PUBLIC_KEY_FILE` and `KAS_PRIVATE_KEY_FILE` paths point to existing keys
   - Check key file permissions

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

#### Viewing Service Logs

```bash
# All logs
docker logs Virtru_CKS

# Follow logs in real-time
docker logs -f Virtru_CKS

# View supervisor logs
docker exec Virtru_CKS cat /var/log/supervisor/supervisord.log
```

---

## Version Compatibility

Both CKS-only and CKS+KAS deployments use the same Docker image:
- **Image:** `containers.virtru.com/cks:v{VERSION}`
- **Example:** `containers.virtru.com/cks:v1.29.0`

KAS is conditionally enabled within the same image based on environment configuration. When updating, both deployment types use the same VERSION file and Docker image.
