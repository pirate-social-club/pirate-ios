#!/usr/bin/env bash
set -euo pipefail

case "${PLATFORM_NAME:-}" in
  iphoneos|iphonesimulator) ;;
  *) exit 0 ;;
esac

sdk_key="${VERY_SDK_KEY:-}"
if [[ -z "${sdk_key}" && "${PIRATE_IOS_SKIP_INFISICAL:-}" != "1" ]]; then
  infisical_bin=""
  if command -v infisical >/dev/null 2>&1; then
    infisical_bin="$(command -v infisical)"
  else
    for candidate in /opt/homebrew/bin/infisical /usr/local/bin/infisical "$HOME/.local/bin/infisical"; do
      if [[ -x "${candidate}" ]]; then
        infisical_bin="${candidate}"
        break
      fi
    done
  fi

  if [[ -n "${infisical_bin}" ]]; then
    infisical_env="${PIRATE_IOS_INFISICAL_ENV:-${INFISICAL_ENV:-dev}}"
    infisical_path="${PIRATE_IOS_INFISICAL_PATH:-${INFISICAL_PATH:-/services/api}}"
    config_dir="${PIRATE_IOS_INFISICAL_PROJECT_CONFIG_DIR:-${INFISICAL_PROJECT_CONFIG_DIR:-${SRCROOT}/../core}}"
    infisical_args=("${infisical_bin}" run --silent --env="${infisical_env}" --path="${infisical_path}")
    project_id="${PIRATE_IOS_INFISICAL_PROJECT_ID:-${INFISICAL_PROJECT_ID:-}}"
    if [[ -n "${project_id}" ]]; then
      infisical_args+=(--projectId "${project_id}")
    fi
    if [[ -d "${config_dir}" ]]; then
      infisical_args+=(--project-config-dir "${config_dir}")
    fi
    if ! sdk_key="$("${infisical_args[@]}" -- /usr/bin/env printenv VERY_SDK_KEY)"; then
      sdk_key=""
    fi
  fi
fi

output="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/VerySecrets.plist"
if [[ -z "${sdk_key}" ]]; then
  rm -f "${output}"
  if [[ "${PIRATE_IOS_ALLOW_MISSING_VERY_SDK_KEY:-}" != "1" || "${PIRATE_IOS_REQUIRE_VERY_SDK_KEY:-}" == "1" ]]; then
    echo "error: VERY_SDK_KEY is missing. Set it in Infisical path ${PIRATE_IOS_INFISICAL_PATH:-${INFISICAL_PATH:-/services/api}}." >&2
    echo "error: If this is an intentional build without native Very, set PIRATE_IOS_ALLOW_MISSING_VERY_SDK_KEY=1." >&2
    exit 1
  fi
  echo "warning: VERY_SDK_KEY is missing; native Very verification will be unavailable in this build." >&2
  exit 0
fi

mkdir -p "$(dirname "${output}")"
/usr/bin/plutil -create xml1 "${output}"
/usr/bin/plutil -insert VERY_SDK_KEY -string "${sdk_key}" "${output}"
