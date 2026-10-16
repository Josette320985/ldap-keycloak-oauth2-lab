# LDAP + Keycloak + OAuth 2.0 / OIDC Lab

Infraestructura Docker del proyecto **CineLog** — levanta **OpenLDAP**, **Keycloak**, **PostgreSQL** y **phpLDAPadmin**, con un **Nginx reverse proxy + Fail2Ban** delante de Keycloak para proteger HTTP y **LDAP TLS**.

![Keycloak](https://img.shields.io/badge/Keycloak-26.7-4D4D4D?logo=keycloak&logoColor=white)
![OpenLDAP](https://img.shields.io/badge/OpenLDAP-1.5-1A71B8?logo=openldap&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-1.27-009639?logo=nginx&logoColor=white)
![Fail2Ban](https://img.shields.io/badge/Fail2Ban-1.0-EE0000?logo=linux&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)

---

##  Description

Infraestructura completa de autenticación **OAuth 2.0 / OIDC**:

- ✅ **OpenLDAP** como directorio de usuarios (`alice`, `bob`)
- ✅ **Keycloak** como Identity Provider (emite JWT RS256)
- ✅ **PostgreSQL** como base de datos de Keycloak
- ✅ **phpLDAPadmin** para administración web del LDAP
- ✅ **Nginx reverse proxy** delante de Keycloak
- ✅ **Fail2Ban** con 2 jails: `http-flood` (HTTP) + `ldap-tls` (puerto 636)

---

##  Repositorios Relacionados

| # | Repositorio | Descripción |
|---|---|---|
| 1 | **ldap-keycloak-oauth2-lab** (este repo) | Infraestructura (LDAP + Keycloak + Proxy) |
| 2 | [movies-backend](https://github.com/Josette320985/movies-backend) | API FastAPI con validación JWT |
| 3 | [movies-dashboard](https://github.com/Josette320985/movies-dashboard) | Frontend Vue.js |
| 4 | [ddos-script](https://github.com/Josette320985/ddos-script) | Script de load test |

---

##  Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Network: auth-network              │
│                                                                  │
│  ┌─────────────┐    ┌────────────────┐    ┌──────────────┐      │
│  │  openldap   │◀───│  keycloak      │    │  keycloak-db │      │
│  │  :389,:636  │    │  :8080         │───▶│  postgres    │      │
│  └─────────────┘    └────────────────┘    └──────────────┘      │
│        ▲                    ▲                                    │
│        │                    │                                    │
│        │              ┌─────────────┐                            │
│        │              │ keycloak-   │                            │
│        │              │ proxy       │                            │
│        │              │ Nginx+      │                            │
│        │              │ Fail2Ban    │                            │
│        │              │ :80 → :8081 │                            │
│        │              └─────────────┘                            │
│        │                                                         │
│  ┌──────────────┐                                                │
│  │ phpLDAPadmin │                                                │
│  │ :80 → :8080  │                                                │
│  └──────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

**Servicios expuestos:**
- **Keycloak** (via proxy): http://localhost:8081
- **phpLDAPadmin**: http://localhost:8080
- **LDAP (directo)**: `ldap://localhost:389` y `ldaps://localhost:636`

---

##  Cómo levantar el stack

### Requisitos previos

- **Docker Desktop** instalado y corriendo.

### Paso 1: Levantar la infraestructura

```bash
cd ldap-keycloak-oauth2-lab
docker compose up -d --build
```

**Tiempo esperado:** 2-3 minutos (compila el proxy de Keycloak).

**Salida esperada al final:**
```
[+] Running 6/6
 ✔ Container openldap          Started
 ✔ Container keycloak-db       Started
 ✔ Container phpldapadmin      Started
 ✔ Container keycloak          Started
 ✔ Container keycloak-proxy    Started
 ✔ Container ldap-oauth-api    Started
```

### Paso 2: Esperar a que Keycloak arranque

**Espera 30-40 segundos** (Keycloak tarda en levantar).

Verifica que Keycloak esté listo:

```bash
curl http://localhost:8081/realms/cybersecurity
```

Debe devolver un JSON con la info del realm `cybersecurity`.

### Paso 3: Cargar usuarios LDAP (solo la primera vez)

Los usuarios `alice` y `bob` deben existir en OpenLDAP. Si es la primera vez:

**En Linux / Mac / Git Bash:**
```bash
./load-ldap-users.sh
```

**En Windows PowerShell (manual):**
```powershell
docker cp ldap/users.ldif openldap:/tmp/users.ldif
docker exec openldap ldapadd -c -x -H ldap://localhost:389 -D "cn=admin,dc=example,dc=com" -w adminpassword -f /tmp/users.ldif
```

**Verificar que se cargaron:**
```powershell
docker exec openldap ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=example,dc=com" -w adminpassword -b "ou=users,dc=example,dc=com" "(uid=alice)"
```

Debe mostrar el bloque LDIF con los datos de alice.

### Paso 4: Verificar los servicios

| URL | Descripción | Credenciales |
|---|---|---|
| http://localhost:8081 | Keycloak (a través del proxy) | `admin` / `adminpassword` |
| http://localhost:8080 | phpLDAPadmin | `cn=admin,dc=example,dc=com` / `adminpassword` |

### Paso 5: Verificar que Fail2Ban está activo

El proxy tiene **2 jails** (`http-flood` y `ldap-tls`):

```bash
docker exec keycloak-proxy fail2ban-client status
```

**Esperado:**
```
Status
|- Number of jail:      2
`- Jail list:   http-flood, ldap-tls
```

Ver cada jail individualmente:
```bash
docker exec keycloak-proxy fail2ban-client status http-flood
docker exec keycloak-proxy fail2ban-client status ldap-tls
```

---

##  Cómo detener el stack

```bash
cd ldap-keycloak-oauth2-lab
docker compose down
```

> ⚠️ **NO uses `-v`** a menos que quieras borrar los usuarios LDAP y la base de Keycloak.

Si necesitas **resetear TODO** (útil cuando falla la importación del realm):

```bash
docker compose down -v
docker compose up -d --build
# Esperar 40s
./load-ldap-users.sh   # o el método manual de Windows
```

---

##  Estructura del Proyecto

```
ldap-keycloak-oauth2-lab/
├── docker-compose.yml              # Orquestación de los 6 servicios
├── ldap/
│   └── users.ldif                  # Usuarios (alice, bob) y grupos
├── keycloak/
│   └── import/
│       └── cybersecurity-realm.json # Realm, cliente y federación LDAP
├── proxy-keycloak/                 # Nginx + Fail2Ban delante de Keycloak
│   ├── Dockerfile
│   ├── nginx.conf                  # Reverse proxy a keycloak:8080
│   └── fail2ban/
│       ├── jail.local              # 2 jails: http-flood + ldap-tls
│       ├── filter-http-flood.conf
│       ├── filter-ldap-tls.conf
│       └── entrypoint.sh
├── fastapi/                        # API de clase (referencia)
├── load-ldap-users.sh              # Script para cargar usuarios LDAP
├── reset.sh                        # Reset completo del entorno
└── README.md                       # Este archivo
```

---

##  Credenciales

| Servicio | Usuario | Contraseña |
|---|---|---|
| **Keycloak Admin** | `admin` | `adminpassword` |
| **LDAP Admin** | `cn=admin,dc=example,dc=com` | `adminpassword` |
| **Usuario 1** | `alice` | `alice123` |
| **Usuario 2** | `bob` | `bob123` |

---

##  Fail2Ban Configuration

El proxy `keycloak-proxy` tiene **2 jails** activos:

### Jail 1: `http-flood` (HTTP)

Banea IPs que envían **+60 requests en 10 segundos** al proxy.

```ini
[http-flood]
enabled = true
port = http,https
filter = http-flood
logpath = /var/log/nginx/access.log
maxretry = 60
findtime = 10s
bantime = 10m
```

### Jail 2: `ldap-tls` (puerto 636)

Banea IPs que generan **+10 errores TLS** en 60 segundos contra LDAP.

```ini
[ldap-tls]
enabled = true
port = 636,389
filter = ldap-tls
logpath = /var/log/nginx/ldap-tls.log
maxretry = 10
findtime = 60s
bantime = 30m
```

### Filtros

**`filter-http-flood.conf`:**
```ini
[Definition]
failregex = ^<HOST> -.*"(?:GET|POST|HEAD|PUT|DELETE|PATCH|OPTIONS|CONNECT|TRACE) [^"]*" [0-9]{3}
ignoreregex =
```

**`filter-ldap-tls.conf`:**
```ini
[Definition]
failregex = ^.*Connection refused from <HOST>:636.*$
            ^.*Failed to connect.*from <HOST>:636.*$
            ^.*LDAP.*authentication.*failed.*from <HOST>.*$
            ^.*SSL.*handshake.*failed.*from <HOST>.*$
            ^.*tls.*handshake.*error.*from <HOST>.*$
ignoreregex =
```

---

##  Verificar Fail2Ban

### Estado general
```bash
docker exec keycloak-proxy fail2ban-client status
```

### Ver el jail `http-flood`
```bash
docker exec keycloak-proxy fail2ban-client status http-flood
```

### Ver el jail `ldap-tls`
```bash
docker exec keycloak-proxy fail2ban-client status ldap-tls
```

### Ver reglas de iptables
```bash
docker exec keycloak-proxy iptables -S | grep f2b
```

### Desbanear una IP
```bash
docker exec keycloak-proxy fail2ban-client set http-flood unbanip <IP>
docker exec keycloak-proxy fail2ban-client set ldap-tls unbanip <IP>
```

---

##  Load Test Results

**RPS máximo seguro para el proxy de Keycloak desde una IP:** **1 RPS**

| RPS | Total | OK | Failed | % Failed | ¿Baneó? |
|---|---|---|---|---|---|
| **1** | 20 | 20 | 0 | **0%** | ❌ NO |
| 2 | 40 | 20 | 20 | 50% | ✅ SÍ |
| 5 | 99 | 23 | 76 | 76% | ✅ SÍ |

**LDAP TLS:** 12 intentos fallidos → **baneado** (a los 10).

Ver detalles completos en el [repo ddos-script](https://github.com/TU_USUARIO/ddos-script).

### ¿Por qué el proxy banea más rápido?

El endpoint `/` de Keycloak **redirige (HTTP 302)** a `/admin/`:

```
GET /               → 302 Found
GET /admin/         → 200 OK
```

Cada request del script genera **2 entradas en el log** → Fail2Ban cuenta ambas → **duplica el RPS efectivo**.

---

##  Verificar la federación LDAP

Para confirmar que Keycloak puede ver a `alice`:

```bash
curl -X POST http://localhost:8081/realms/cybersecurity/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=fastapi-api" \
  -d "username=alice" \
  -d "password=alice123" \
  -d "scope=openid"
```

**Debe devolver un JSON con `access_token`.**

---

##  Troubleshooting

| Problema | Solución |
|---|---|
| `Client not found` en Keycloak | El realm no se importó. Ejecuta `docker compose down -v && docker compose up -d --build` |
| `invalid_grant` al hacer login | Los usuarios LDAP no están cargados. Ejecuta `./load-ldap-users.sh` |
| `User returned from LDAP has null username` | Faltan los mappers de atributos LDAP. Verifica `cybersecurity-realm.json`. |
| CORS error en el frontend | Agrega `http://localhost:5173` a **Web origins** del cliente `fastapi-api`. |
| Keycloak no arranca | Verifica los logs: `docker logs keycloak` |
| El proxy no arranca | Verifica los logs: `docker logs keycloak-proxy` |

---


