#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${IOS_DIR}/.." && pwd)"

if [[ "${PIRATE_IOS_SKIP_INFISICAL:-}" != "1" && "${PIRATE_IOS_INFISICAL_BOOTSTRAPPED:-}" != "1" && -z "${VERY_SDK_KEY:-}" ]]; then
  if command -v infisical >/dev/null 2>&1; then
    INFISICAL_ENV_NAME="${PIRATE_IOS_INFISICAL_ENV:-${INFISICAL_ENV:-dev}}"
    INFISICAL_SECRET_PATH="${PIRATE_IOS_INFISICAL_PATH:-${INFISICAL_PATH:-/services/api}}"
    INFISICAL_CONFIG_DIR="${PIRATE_IOS_INFISICAL_PROJECT_CONFIG_DIR:-${INFISICAL_PROJECT_CONFIG_DIR:-${WORKSPACE_DIR}/core}}"
    INFISICAL_ARGS=(infisical run --env="${INFISICAL_ENV_NAME}" --path="${INFISICAL_SECRET_PATH}")
    INFISICAL_PROJECT_ID="${PIRATE_IOS_INFISICAL_PROJECT_ID:-${INFISICAL_PROJECT_ID:-}}"
    if [[ -n "${INFISICAL_PROJECT_ID}" ]]; then
      INFISICAL_ARGS+=(--projectId "${INFISICAL_PROJECT_ID}")
    fi
    if [[ -d "${INFISICAL_CONFIG_DIR}" ]]; then
      INFISICAL_ARGS+=(--project-config-dir "${INFISICAL_CONFIG_DIR}")
    fi
    exec env PIRATE_IOS_INFISICAL_BOOTSTRAPPED=1 "${INFISICAL_ARGS[@]}" -- "$0" "$@"
  fi
fi

if [[ "$#" -eq 0 ]]; then
  set -- \
    -project pirate.xcodeproj \
    -scheme pirate \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

HAS_VERY_BUILD_SETTING=0
USER_XCCONFIG=""
NORMALIZED_ARGS=()
SKIP_NEXT=0
for arg in "$@"; do
  if [[ "${SKIP_NEXT}" == "1" ]]; then
    USER_XCCONFIG="${arg}"
    SKIP_NEXT=0
    continue
  fi
  if [[ "${arg}" == "-xcconfig" ]]; then
    SKIP_NEXT=1
    continue
  fi
  if [[ "${arg}" == VERY_SDK_KEY=* ]]; then
    HAS_VERY_BUILD_SETTING=1
  fi
  NORMALIZED_ARGS+=("${arg}")
done
if [[ "${SKIP_NEXT}" == "1" ]]; then
  echo "error: -xcconfig requires a path" >&2
  exit 1
fi

TEMP_XCCONFIG=""
cleanup() {
  if [[ -n "${TEMP_XCCONFIG}" ]]; then
    rm -f "${TEMP_XCCONFIG}"
  fi
}
trap cleanup EXIT

cd "${IOS_DIR}"

XCODEBUILD_ARGS=("${NORMALIZED_ARGS[@]}")
if [[ -n "${USER_XCCONFIG}" ]]; then
  if [[ "${USER_XCCONFIG}" = /* ]]; then
    USER_XCCONFIG_PATH="${USER_XCCONFIG}"
  else
    USER_XCCONFIG_PATH="${IOS_DIR}/${USER_XCCONFIG}"
  fi
  XCODEBUILD_ARGS=(-xcconfig "${USER_XCCONFIG_PATH}" "${XCODEBUILD_ARGS[@]}")
fi

if [[ "${HAS_VERY_BUILD_SETTING}" != "1" ]]; then
  if [[ -n "${VERY_SDK_KEY:-}" ]]; then
    TEMP_XCCONFIG="$(mktemp "${TMPDIR:-/tmp}/pirate-ios-build.XXXXXX.xcconfig")"
    chmod 600 "${TEMP_XCCONFIG}"
    {
      if [[ -n "${USER_XCCONFIG}" ]]; then
        printf '#include "%s"\n' "${USER_XCCONFIG_PATH}"
      fi
      printf 'VERY_SDK_KEY = %s\n' "${VERY_SDK_KEY}"
    } > "${TEMP_XCCONFIG}"
    XCODEBUILD_ARGS=(-xcconfig "${TEMP_XCCONFIG}" "${NORMALIZED_ARGS[@]}")
  elif [[ "${PIRATE_IOS_REQUIRE_VERY_SDK_KEY:-}" == "1" ]]; then
    echo "VERY_SDK_KEY is missing. Set it in Infisical path ${PIRATE_IOS_INFISICAL_PATH:-${INFISICAL_PATH:-/services/api}} or export it before running this script." >&2
    exit 1
  else
    echo "warning: VERY_SDK_KEY is missing; native Very verification will be unavailable in this build." >&2
  fi
fi

xcodebuild "${XCODEBUILD_ARGS[@]}"
