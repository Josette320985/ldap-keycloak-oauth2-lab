FROM nginx:1.27-alpine

RUN apk add --no-cache \
    fail2ban \
    bash \
    iptables \
    iproute2 \
    curl

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY fail2ban/jail.local /etc/fail2ban/jail.local
COPY fail2ban/filter-http-flood.conf /etc/fail2ban/filter.d/http-flood.conf
COPY fail2ban/filter-ldap-tls.conf /etc/fail2ban/filter.d/ldap-tls.conf
COPY fail2ban/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]