# ldap-keycloak-oauth2-lab

## Preparación del servicio

```powershell
cd C:\Users\naher\Documents\PracticaFinal\ldap-keycloak-oauth2-lab
docker compose up -d
```

## Verificación de red del contenedor

```powershell
docker inspect keycloak-proxy --format '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}'
```

Red detectada:

```text
ldap-keycloak-oauth2-lab_auth-network
```

## Primer escaneo con Nuclei

Durante el escaneo, Fail2Ban detectó aproximadamente **108 requests** en pocos segundos y baneó la IP del contenedor de Nuclei (**172.23.0.9**). Esto demuestra que la protección `http-flood` funciona correctamente.

### Desbanear la IP de Nuclei

```powershell
docker exec keycloak-proxy fail2ban-client set http-flood unbanip 172.23.0.9
```

### Ajuste de Fail2Ban para permitir el escaneo

```powershell
docker exec keycloak-proxy fail2ban-client set http-flood maxretry 500
```

### Escaneo 1: Keycloak Proxy

```powershell
docker run --rm --network ldap-keycloak-oauth2-lab_auth-network -v "${PWD}\reports:/reports" projectdiscovery/nuclei:latest -target http://keycloak-proxy:80 -severity info,low,medium -rate-limit 30 -timeout 5 -retries 1 -jsonl-export /reports/nuclei-cinelog-keycloak.jsonl
```

### Escaneo del endpoint directo (sin redirect)

```powershell
docker run --rm --network ldap-keycloak-oauth2-lab_auth-network -v "${PWD}\reports:/reports" projectdiscovery/nuclei:latest -target http://keycloak-proxy:80/realms/master -severity info,low,medium -rate-limit 30 -timeout 10 -retries 1 -jsonl-export /reports/nuclei-cinelog-keycloak.jsonl
```

## Resultados del primer escaneo

- Servicio: **Keycloak Proxy**
- Hallazgos: **14**
- Problemas principales:
  - CORS
  - Headers
  - Nginx obsoleto