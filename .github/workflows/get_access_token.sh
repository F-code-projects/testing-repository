#!/bin/bash
 
set -o pipefail
 
# Variables necesarias
APP_ID=$APP_ID
PRIVATE_KEY=$PRIVATE_KEY
ORGANIZATION=$ORGANIZATION
 
# Verificar si la clave privada está presente
if [ -z "$PRIVATE_KEY" ]; then
  echo "Private key is missing."
  exit 1
fi
 
# Generar JWT
now=$(date +%s)
iat=$((${now} - 60)) # Emitido hace 60 segundos
exp=$((${now} + 600)) # Expira en 10 minutos
 
b64enc() { openssl base64 -e -A | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }
 
header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
# Codificar el encabezado
header=$(echo -n "${header_json}" | b64enc)
 
payload_json="{
    \"iat\":${iat},
    \"exp\":${exp},
    \"iss\":\"${APP_ID}\"
}"
# Codificar el payload
payload=$(echo -n "${payload_json}" | b64enc)
 
# Firmar el JWT
header_payload="${header}.${payload}"
signature=$(echo -n "${header_payload}" | openssl dgst -sha256 -sign <(echo -n "${PRIVATE_KEY}") | b64enc)
 
# Crear el JWT
jwt_token="${header_payload}.${signature}"
 
# Obtener instalaciones
installations=$(curl -s -H "Authorization: Bearer $jwt_token" -H "Accept: application/vnd.github.v3+json" https://api.github.com/app/installations)
 
echo "DEBUG installations: $installations"
echo "DEBUG jwt_token: $jwt_token"
 
# Encontrar ID de instalación
installation_id=$(echo "$installations" | jq -r --arg org "$ORGANIZATION" '.[] | select(.account.login == $org) | .id')
 
if [ -z "$installation_id" ]; then
  echo "No matching account found for the provided organization."
  exit 1
fi
 
echo "ID de instalación seleccionado: $installation_id"
 
# Obtener token de acceso
access_token=$(curl -s -X POST -H "Authorization: Bearer $jwt_token" -H "Accept: application/vnd.github.v3+json" https://api.github.com/app/installations/$installation_id/access_tokens | jq -r '.token')
 
if [ -z "$access_token" ]; then
  echo "Failed to obtain access token."
  exit 1
fi
 
# Exportar el token de acceso como variable de entorno
echo "ACCESS_TOKEN=$access_token" >> $GITHUB_ENV