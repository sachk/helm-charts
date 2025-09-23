#!/usr/bin/env bash
# Minimal JWT generator for Supabase
# - Applies a Kubernetes Secret with those values
# Usage:
#   NAMESPACE=supabase SECRET_NAME=supabase-jwt ./generate-jwt.sh

set -euo pipefail

NAMESPACE="${NAMESPACE:-supabase}"
SECRET_NAME="${SECRET_NAME:-supabase-jwt}"

# Helpers
b64url() {
  openssl base64 -A | tr -d '=' | tr '+/' '-_'
}

jwt_for_role() {
  local role="$1"
  local iat exp header payload header_b64 payload_b64 signing_input sig
  iat=$(date +%s)
  exp=$((iat + 315360000)) # ~10 years
  header='{"alg":"HS256","typ":"JWT"}'
  payload="{\"role\":\"${role}\",\"iss\":\"supabase\",\"iat\":${iat},\"exp\":${exp}}"
  header_b64=$(printf '%s' "${header}" | b64url)
  payload_b64=$(printf '%s' "${payload}" | b64url)
  signing_input="${header_b64}.${payload_b64}"
  sig=$(printf '%s' "${signing_input}" | openssl dgst -binary -sha256 -hmac "${JWT_SECRET}" | b64url)
  printf '%s.%s\n' "${signing_input}" "${sig}"
}

JWT_SECRET="$(openssl rand -base64 64 | tr -d '\n')"
ANON_KEY="$(jwt_for_role anon)"
SERVICE_KEY="$(jwt_for_role service_role)"


kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-literal=secret="${JWT_SECRET}" \
  --from-literal=anonKey="${ANON_KEY}" \
  --from-literal=serviceKey="${SERVICE_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Applied Secret ${SECRET_NAME} in namespace ${NAMESPACE}"
