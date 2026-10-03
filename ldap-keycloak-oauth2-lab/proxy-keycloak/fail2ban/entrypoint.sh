#!/bin/bash
set -e

echo "[proxy-keycloak] Starting entrypoint..."

mkdir -p /var/log/nginx /var/run/fail2ban

rm -f /var/log/nginx/access.log /var/log/nginx/error.log
touch /var/log/nginx/access.log /var/log/nginx/error.log
touch /var/log/nginx/ldap-tls.log
touch /var/log/fail2ban.log

rm -f /var/run/fail2ban/fail2ban.sock /var/run/fail2ban/fail2ban.pid

echo "[proxy-keycloak] Starting nginx..."
nginx -g 'daemon off;' &

sleep 2

echo "[proxy-keycloak] Starting fail2ban..."
fail2ban-client -x start

echo "[proxy-keycloak] nginx + fail2ban running."

exec tail -F /var/log/fail2ban.log