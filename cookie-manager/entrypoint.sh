#!/bin/bash
# Forward 0.0.0.0:9222 → 127.0.0.1:9222 so Docker port mapping works
socat TCP-LISTEN:9223,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:9222 &

# Start the cookie manager (Chromium CDP listens on 127.0.0.1:9222)
exec node index.js
