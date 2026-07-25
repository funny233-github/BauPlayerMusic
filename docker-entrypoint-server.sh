#!/bin/bash
set -e

if [ -f /app/myServerconfig.cfg.host ]; then
    cp /app/myServerconfig.cfg.host /app/myServerconfig.cfg
else
    cp /app/myServerconfig.example.cfg /app/myServerconfig.cfg
fi

sed -i 's|sv_music_backend_url ".*"|sv_music_backend_url "http://127.0.0.1:5000"|' /app/myServerconfig.cfg

exec DDNet-Server -f myServerconfig.cfg
