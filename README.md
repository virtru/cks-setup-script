# CKS Setup Script

## Instructions

1. Download the appropriate setup script to the host.

```
curl -s https://api.github.com/repos/virtru-corp/cks-setup-script/releases/latest \
| grep "browser_download_url.*sh" \
| cut -d : -f 2,3 \
| tr -d \" \
| sudo wget -qi -
```

2. Run the script with Bash

`bash ./setup-cks-v3.0.0.sh` (replace with the desired version)
