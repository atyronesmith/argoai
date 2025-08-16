#!/bin/sh
set -e

# Inject env-config.js script tag into index.html if it doesn't exist
if [ -f /opt/app-root/src/index.html ] && [ -f /opt/app-root/src/env-config.js ]; then
  if ! grep -q "env-config.js" /opt/app-root/src/index.html; then
    echo "Injecting env-config.js into index.html..."
    sed -i 's|</title>|</title><script src="/env-config.js"></script>|' /opt/app-root/src/index.html
  fi
fi

# Start nginx
exec nginx -g 'daemon off;'
