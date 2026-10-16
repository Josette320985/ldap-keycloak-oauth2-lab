# Reporte de Correcciones de Seguridad — Keycloak Proxy (ldap-keycloak-oauth2-lab)

Este documento detalla las correcciones aplicadas y los hallazgos restantes en el servicio **`keycloak-proxy`** de CineLog, perteneciente al proyecto `ldap-keycloak-oauth2-lab`.

---

## Resumen

| Métrica | Antes | Después |
|---|---:|---:|
| Hallazgos totales | 14 | 6 |
| Reducción | — | **57 %** |

---

## Correcciones aplicadas

### 1. Headers de seguridad en `proxy-keycloak/nginx.conf`

Se reescribió el archivo `nginx.conf` para incorporar encabezados de seguridad y mejorar la configuración del proxy inverso encargado de comunicar las solicitudes con Keycloak.

```nginx
server {
    listen 80 default_server;
    server_name localhost;

    server_tokens off;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;

    access_log /var/log/nginx/access.log combined;
    error_log /var/log/nginx/error.log warn;

    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;
    large_client_header_buffers 4 16k;

    client_max_body_size 20M;

    location / {
        proxy_pass http://keycloak:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

Los principales ajustes realizados fueron los siguientes:

- Se configuró `server_tokens off` para ocultar la versión exacta de Nginx.
- Se incorporaron encabezados para controlar la carga de contenido, restringir permisos del navegador y reducir riesgos asociados con la inclusión de páginas en marcos.
- Se ajustaron los búferes del proxy para gestionar encabezados y respuestas de mayor tamaño.
- Se estableció un límite de 20 MB para el tamaño de las solicitudes mediante `client_max_body_size`.
- Se configuraron tiempos de espera para las conexiones y la lectura de respuestas de Keycloak.

**Nota:** Inicialmente se incluyó el encabezado `X-XSS-Protection "1; mode=block"`, pero posteriormente se eliminó por estar obsoleto y no constituir un mecanismo de protección recomendado para navegadores modernos.

### 2. Restricción de CORS en el proxy

Se modificó la configuración de `nginx.conf` para ocultar los encabezados CORS enviados por Keycloak y establecer una política más restrictiva, orientada a permitir las solicitudes del frontend de CineLog.

La configuración aplicada dentro del bloque `location /` es la siguiente:

```nginx
location / {
    proxy_pass http://keycloak:8080;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Port $server_port;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;

    # Encabezados de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;

    # Ocultar encabezados CORS enviados por Keycloak
    proxy_hide_header Access-Control-Allow-Origin;
    proxy_hide_header Access-Control-Allow-Credentials;
    proxy_hide_header Access-Control-Allow-Methods;
    proxy_hide_header Access-Control-Allow-Headers;
    proxy_hide_header Access-Control-Expose-Headers;

    # Política CORS restringida al frontend
    add_header Access-Control-Allow-Origin "http://localhost:5173" always;
    add_header Access-Control-Allow-Credentials "true" always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
    add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
    add_header Access-Control-Max-Age "3600" always;
}
```

**Efecto:** Se reportó la eliminación del hallazgo `cors-misconfig:arbitrary-origin`, al sustituir la configuración anterior por una política que permite solicitudes desde el origen especificado.

La configuración autoriza únicamente `http://localhost:5173`, permite credenciales y limita los métodos y encabezados aceptados.

**Consideración:** Esta política está orientada al entorno local de desarrollo. Para producción, debe sustituirse el origen local por el dominio real del frontend. Además, las solicitudes `OPTIONS` deben procesarse correctamente y la política debe probarse con los flujos de autenticación utilizados por Keycloak.

### 3. Nota sobre HSTS

El encabezado `Strict-Transport-Security` ya estaba presente en las respuestas verificadas del proxy, enviado por Keycloak. Por este motivo, no fue necesario añadirlo nuevamente a la configuración de Nginx.

HSTS permite indicar a los navegadores que deben utilizar HTTPS durante el periodo establecido por el servidor.

**Consideración:** Para que HSTS proporcione la protección esperada, debe enviarse mediante HTTPS. La presencia del encabezado debe verificarse en la respuesta que recibe el navegador, especialmente si existe un proxy inverso entre el cliente y Keycloak.

### 4. Reconstrucción y verificación

Después de aplicar los cambios, se reconstruyó y levantó el servicio `keycloak-proxy` mediante el siguiente comando de PowerShell:

```powershell
docker compose up -d --build keycloak-proxy
```

Se realizaron las siguientes verificaciones:

- El endpoint `/realms/master` responde correctamente con contenido JSON.
- El inicio de sesión en la consola de administración de Keycloak funciona.
- El servicio continúa operativo después de la reconstrucción.

---

## Hallazgos restantes

Se reportaron seis hallazgos restantes, todos clasificados como informativos (`info`).

| # | Hallazgo | Justificación |
|---:|---|---|
| 1 | `waf-detect:nginxgeneric` | El mecanismo de filtrado basado en Nginx bloquea las peticiones identificadas como maliciosas. Este comportamiento es consistente con un mecanismo de seguridad funcionando y no constituye, por sí mismo, una vulnerabilidad. |
| 2 | `tech-detect:nginx` | Se identificó Nginx mediante los encabezados HTTP. La directiva `server_tokens off` oculta la versión exacta, pero no necesariamente elimina el encabezado `Server`. Se intentó eliminarlo mediante el módulo `headers-more`, pero se presentaron incompatibilidades binarias con Nginx 1.27 en Alpine. Por ello, el hallazgo se mantiene como informativo. |
| 3 | `oidc-detect` | Se detectó el uso de OpenID Connect (OIDC). Esta detección corresponde a la función de Keycloak como proveedor de identidad y no representa, por sí misma, una vulnerabilidad. |
| 4 | `keycloak-openid-config` | Se identificó el endpoint estándar `.well-known/openid-configuration`, utilizado para publicar los metadatos de configuración de OpenID Connect. Su exposición es parte del funcionamiento esperado del protocolo. |
| 5 | `oauth-authorization-server-exposure` | Se detectó el endpoint estándar `.well-known/oauth-authorization-server`, que publica metadatos del servidor de autorización OAuth 2.0. Su disponibilidad puede ser necesaria para el funcionamiento del protocolo y no constituye automáticamente una vulnerabilidad. |
| 6 | `content-security-policy` | Se intentó aplicar una política CSP al proxy, pero la configuración probada afectaba el funcionamiento de la consola de administración de Keycloak 26.x, debido a sus necesidades de scripts y recursos. Se decidió no mantener esa política y aceptar el hallazgo como informativo. |

### Consideración sobre la política CSP

La política CSP inicialmente evaluada no era compatible con el funcionamiento esperado de la consola de administración de Keycloak 26.x. Durante las pruebas se observó que la consola requería determinadas capacidades de ejecución de scripts y carga de recursos.

Por ello, se decidió no aplicar esa política restrictiva en el proxy para evitar afectar el inicio de sesión y la administración del servicio.

---

## Conclusión

El servicio `keycloak-proxy` pasó de 14 a 6 hallazgos, lo que representa una reducción aproximada del **57 %**. Las correcciones se centraron en fortalecer los encabezados de seguridad, restringir la política CORS y verificar el funcionamiento del proxy y de los mecanismos de autenticación de Keycloak.

Los seis hallazgos restantes corresponden a la detección de tecnologías, mecanismos de filtrado y endpoints utilizados por los protocolos OIDC y OAuth 2.0, además de la ausencia de una política CSP compatible con la consola de administración.

Con base en los resultados obtenidos, no se identificaron vulnerabilidades explotables entre los hallazgos restantes clasificados como informativos. El servicio continúa funcionando correctamente después de las modificaciones.

