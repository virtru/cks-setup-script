# CKS Setup Script

## Initial setup

```bash
curl -s https://raw.githubusercontent.com/virtru-corp/cks-setup-script/main/download.sh -o download.sh
bash ./download.sh
bash ./cks-setup-scripts/setup-cks-latest.sh
```

## Updates

```bash
bash ./cks-setup-scripts/update.sh
```

CKS runs as a single Node.js process on container port 9000. The generated
`run.sh` publishes it as HTTPS port 443 and mounts the configured keys and
certificates. Ensure those mounted files are readable by the non-root `cks`
container user.

The customer image does not include KAS, PostgreSQL, Caddy, or supervisor.
