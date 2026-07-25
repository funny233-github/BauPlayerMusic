#!/bin/bash
set -e

if [ -f /app/.env.host ]; then
    cp /app/.env.host /app/.env
else
    cp /app/.env.example /app/.env
fi

sed -i 's/^BPMUSIC_HOST=.*/BPMUSIC_HOST=0.0.0.0/' /app/.env

if [ -f /app/myServerconfig.cfg.host ]; then
    cp /app/myServerconfig.cfg.host /app/myServerconfig.cfg
else
    cp /app/myServerconfig.example.cfg /app/myServerconfig.cfg
fi

echo "[entrypoint] 启动管理面板..."
python3 admin_panel.py &
PANEL_PID=$!

echo "[entrypoint] 启动音乐后端..."
exec python3 -c "
import requests.packages.urllib3.util.connection
requests.packages.urllib3.util.connection.HAS_IPV6 = False
import sys
sys.argv = ['mds.py']
__file__ = '/app/mds.py'
exec(open('/app/mds.py').read())
"
