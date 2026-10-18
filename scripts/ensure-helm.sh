#!/usr/bin/env bash
set -euo pipefail

HELM_VERSION="v3.18.6"
HELM_BUILD="v3.18.6+gb76a950"
HELM_ARCHIVE_SHA256_AMD64="3f43c0aa57243852dd542493a0f54f1396c0bc8ec7296bbb2c01e802010819ce"
HELM_ARCHIVE_SHA256_ARM64="5b8e00b6709caab466cbbb0bc29ee09059b8dc9417991dd04b497530e49b1737"

case "$(uname -m)" in
  x86_64)  HELM_ARCH="amd64"; HELM_ARCHIVE_SHA256="${HELM_ARCHIVE_SHA256_AMD64}" ;;
  aarch64) HELM_ARCH="arm64"; HELM_ARCHIVE_SHA256="${HELM_ARCHIVE_SHA256_ARM64}" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELM_DIRECTORY="${REPOSITORY_ROOT}/.cache/tools/helm-${HELM_VERSION}"
HELM_BINARY="${HELM_DIRECTORY}/helm"

if [[ -x "${HELM_BINARY}" ]] && [[ "$("${HELM_BINARY}" version --short 2>/dev/null)" == "${HELM_BUILD}" ]]; then
  printf '%s\n' "${HELM_BINARY}"
  exit 0
fi

for command in curl install sha256sum tar; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "${command} is required to install the pinned Helm CLI." >&2
    exit 1
  fi
done

HELM_TEMPORARY_DIRECTORY="$(mktemp -d)"
cleanup() {
  if [[ "${HELM_TEMPORARY_DIRECTORY}" == /tmp/* && -d "${HELM_TEMPORARY_DIRECTORY}" ]]; then
    rm -rf -- "${HELM_TEMPORARY_DIRECTORY}"
  fi
}
trap cleanup EXIT

HELM_ARCHIVE="${HELM_TEMPORARY_DIRECTORY}/helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz"
curl --fail --silent --show-error --location \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" \
  --output "${HELM_ARCHIVE}"
printf '%s  %s\n' "${HELM_ARCHIVE_SHA256}" "${HELM_ARCHIVE}" | sha256sum --check --status
tar -xzf "${HELM_ARCHIVE}" -C "${HELM_TEMPORARY_DIRECTORY}"

install -d -m 0755 "${HELM_DIRECTORY}"
install -m 0755 "${HELM_TEMPORARY_DIRECTORY}/linux-${HELM_ARCH}/helm" "${HELM_BINARY}"
if [[ "$("${HELM_BINARY}" version --short)" != "${HELM_BUILD}" ]]; then
  echo "The installed Helm binary does not match ${HELM_BUILD}." >&2
  exit 1
fi
printf '%s\n' "${HELM_BINARY}"
