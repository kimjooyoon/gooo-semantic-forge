#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: observe-semantic-forge.sh ROOT GOOO_GRAPH INPUT_DIRECTORY OUTPUT_DIRECTORY" >&2
  exit 64
fi

root=$(cd "$1" && pwd -P)
graph=$2
inputs=$3
requested_output=$4
denominator="$root/contracts/semantic-forge-denominator-v1.json"
lock="$root/contracts/semantic-forge-release-lock-v1.json"
graph_lock="$root/contracts/semantic-forge-observation-lock-v1.json"
observation="$root/examples/semantic-forge-v1/observation.gooo"

if test -e "$requested_output"; then
  test -d "$requested_output" || { echo "output path is not a directory" >&2; exit 73; }
  output=$(cd "$requested_output" && pwd -P)
else
  output_parent=$(cd "$(dirname "$requested_output")" && pwd -P)
  output="$output_parent/$(basename "$requested_output")"
fi
case "$output" in
  "$root"|"$root"/*)
    echo "output directory must be caller-owned and outside the Forge repository" >&2
    exit 73
    ;;
esac

test -f "$graph" || { echo "missing Gooo graph" >&2; exit 66; }
test -d "$inputs" || { echo "missing input directory" >&2; exit 66; }
test -f "$denominator" || { echo "missing denominator" >&2; exit 66; }
test -f "$lock" || { echo "missing release lock" >&2; exit 66; }
test -f "$graph_lock" || { echo "missing observation graph lock" >&2; exit 66; }
test -f "$observation" || { echo "missing Gooo observation" >&2; exit 66; }
test -f "$inputs/acquisition-receipt.json" || { echo "missing immutable acquisition receipt" >&2; exit 66; }

if test -e "$output" && test -n "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)"; then
  echo "output directory must be empty" >&2
  exit 73
fi
mkdir -p "$output"
output=$(cd "$output" && pwd -P)
case "$output" in
  "$root"|"$root"/*)
    echo "output directory resolves inside the Forge repository" >&2
    exit 73
    ;;
esac

work=$(mktemp -d "${TMPDIR:-/tmp}/gooo-semantic-forge.XXXXXX")
trap 'rm -rf "$work"' EXIT

json_or_null() {
  local candidate=$1 fallback=$2
  if test -f "$candidate"; then
    printf '%s\n' "$candidate"
  else
    printf 'null\n' > "$fallback"
    printf '%s\n' "$fallback"
  fi
}

verify_raw_asset() {
  local path=$1 scope=$2 selector=$3 expected_size expected_sha actual_size actual_sha
  expected_size=$(jq -r --arg scope "$scope" --arg selector "$selector" '.[$scope].assets[$selector].size' "$lock")
  expected_sha=$(jq -r --arg scope "$scope" --arg selector "$selector" '.[$scope].assets[$selector].sha256' "$lock")
  if test ! -f "$path"; then printf 'false\n'; return; fi
  actual_size=$(wc -c < "$path" | tr -d ' ')
  actual_sha=$(sha256sum "$path" | awk '{print $1}')
  if test "$actual_size" = "$expected_size" && test "$actual_sha" = "$expected_sha"; then printf 'true\n'; else printf 'false\n'; fi
}

member_matches_receipt() {
  local member=$1 file="$inputs/$1" expected actual archive_actual entry
  if test ! -f "$file"; then return 1; fi
  expected=$(jq -r --arg member "$member" '.members[$member] // empty' "$inputs/acquisition-receipt.json")
  actual=$(sha256sum "$file" | awk '{print $1}')
  test -n "$expected" && test "$actual" = "$expected" || return 1
  case "$member" in
    interchange/consumer-kit-v2/*)
      entry="consumer-kit-v2/${member#interchange/consumer-kit-v2/}"
      archive_actual=$(tar -xOzf "$inputs/raw/gooo-interchange-consumer-kit-v2.tar.gz" "$entry" 2>/dev/null | sha256sum | awk '{print $1}')
      test "$actual" = "$archive_actual"
      ;;
    local/*)
      entry=${member#local/}
      archive_actual=$(unzip -p "$inputs/raw/local-released-domain-envelope-v2-ci-artifact.zip" "$entry" 2>/dev/null | sha256sum | awk '{print $1}')
      test "$actual" = "$archive_actual"
      ;;
    design/*)
      entry=${member#design/}
      archive_actual=$(unzip -p "$inputs/raw/design-released-domain-envelope-v2-ci-artifact.zip" "$entry" 2>/dev/null | sha256sum | awk '{print $1}')
      test "$actual" = "$archive_actual"
      ;;
    release/*) true ;;
    *) return 1 ;;
  esac
}

all_members_match() {
  local member
  for member in "$@"; do member_matches_receipt "$member" || return 1; done
}

core_raw=$(verify_raw_asset "$inputs/raw/gooo-linux-amd64.tar.gz" core binary)
core_checksums_raw=$(verify_raw_asset "$inputs/raw/SHA256SUMS" core checksums)
interchange_raw=$(verify_raw_asset "$inputs/raw/gooo-interchange-consumer-kit-v2.tar.gz" interchange consumer_kit)
local_raw=$(verify_raw_asset "$inputs/raw/local-released-domain-envelope-v2-ci-artifact.zip" local ci_artifact)
design_raw=$(verify_raw_asset "$inputs/raw/design-released-domain-envelope-v2-ci-artifact.zip" design ci_artifact)
if test "$core_raw" = true && test "$core_checksums_raw" = true; then core_assets=true; else core_assets=false; fi
if test "$interchange_raw" = true; then interchange_assets=true; else interchange_assets=false; fi
if test "$local_raw" = true; then local_assets=true; else local_assets=false; fi
if test "$design_raw" = true; then design_assets=true; else design_assets=false; fi

if all_members_match release/core.json; then core_release_member=true; else core_release_member=false; fi
if all_members_match release/interchange.json; then interchange_release_member=true; else interchange_release_member=false; fi
if all_members_match interchange/consumer-kit-v2/manifest.json; then kit_manifest_member=true; else kit_manifest_member=false; fi
if all_members_match release/local.json; then local_release_member=true; else local_release_member=false; fi
if all_members_match local/adoption-report.json local/final-facts.json local/meta-graph.json local/immutable-inputs.json local/bundle-a/replay.json local/bundle-b/replay.json; then local_receipts_member=true; else local_receipts_member=false; fi
if all_members_match release/design.json; then design_release_member=true; else design_release_member=false; fi
if all_members_match design/envelope-adoption-report.json design/envelope-facts.json design/envelope-graph.json design/immutable-inputs.json design/envelope-a/replay.json design/envelope-b/replay.json; then design_receipts_member=true; else design_receipts_member=false; fi

source_sha256=$(sha256sum "$observation" | awk '{print $1}')
graph_sha256=$(sha256sum "$graph" | awk '{print $1}')
if test "$source_sha256" = "$(jq -r '.observation.source_sha256' "$graph_lock")" && test "$graph_sha256" = "$(jq -r '.observation.graph_sha256' "$graph_lock")"; then pinned_source_graph=true; else pinned_source_graph=false; fi
if jq -e \
  --arg source_sha256 "$source_sha256" --arg graph_sha256 "$graph_sha256" \
  --arg core_sha "$(jq -r '.core.assets.binary.sha256' "$lock")" \
  --arg core_checksums_sha "$(jq -r '.core.assets.checksums.sha256' "$lock")" \
  --arg kit_sha "$(jq -r '.interchange.assets.consumer_kit.sha256' "$lock")" \
  --arg local_sha "$(jq -r '.local.assets.ci_artifact.sha256' "$lock")" \
  --arg design_sha "$(jq -r '.design.assets.ci_artifact.sha256' "$lock")" '
    .schema == "gooo/semantic-forge/immutable-acquisition-receipt/v1" and
    .observation.source_sha256 == $source_sha256 and .observation.graph_sha256 == $graph_sha256 and
    .archives.core_binary.sha256 == $core_sha and .archives.core_checksums.sha256 == $core_checksums_sha and .archives.interchange_consumer_kit.sha256 == $kit_sha and
    .archives.local_ci_artifact.sha256 == $local_sha and .archives.design_ci_artifact.sha256 == $design_sha
  ' "$inputs/acquisition-receipt.json" >/dev/null; then acquisition_receipt=true; else acquisition_receipt=false; fi

jq -S -n \
  --arg source_sha256 "$source_sha256" --arg graph_sha256 "$graph_sha256" \
  --argjson acquisition_receipt "$acquisition_receipt" --argjson pinned_source_graph "$pinned_source_graph" \
  --argjson core_raw "$core_raw" --argjson core_checksums_raw "$core_checksums_raw" \
  --argjson core_assets "$core_assets" --argjson interchange_assets "$interchange_assets" \
  --argjson local_assets "$local_assets" --argjson design_assets "$design_assets" \
  --argjson core_release_member "$core_release_member" --argjson interchange_release_member "$interchange_release_member" \
  --argjson kit_manifest_member "$kit_manifest_member" --argjson local_release_member "$local_release_member" \
  --argjson local_receipts_member "$local_receipts_member" --argjson design_release_member "$design_release_member" \
  --argjson design_receipts_member "$design_receipts_member" '
  {schema:"gooo/semantic-forge/input-integrity/v1", acquisition_receipt:$acquisition_receipt,
   source_graph_binding:($acquisition_receipt and $pinned_source_graph), source_sha256:$source_sha256, graph_sha256:$graph_sha256,
   raw_assets:{core:$core_assets,core_binary:$core_raw,core_checksums:$core_checksums_raw,interchange:$interchange_assets,local:$local_assets,design:$design_assets},
   members:{core_release:$core_release_member,interchange_release:$interchange_release_member,kit_manifest:$kit_manifest_member,local_release:$local_release_member,local_receipts:$local_receipts_member,design_release:$design_release_member,design_receipts:$design_receipts_member}}
' > "$work/input-integrity.json"

required_json=(
  "$graph" "$denominator" "$lock" "$inputs/acquisition-receipt.json" "$inputs/authority.json"
  "$inputs/interchange/consumer-kit-v2/manifest.json"
  "$inputs/local/adoption-report.json" "$inputs/local/final-facts.json" "$inputs/local/meta-graph.json" "$inputs/local/immutable-inputs.json" "$inputs/local/bundle-a/replay.json" "$inputs/local/bundle-b/replay.json"
  "$inputs/design/envelope-adoption-report.json" "$inputs/design/envelope-facts.json" "$inputs/design/envelope-graph.json" "$inputs/design/immutable-inputs.json" "$inputs/design/envelope-a/replay.json" "$inputs/design/envelope-b/replay.json"
)
for file in "${required_json[@]}"; do
  test -f "$file" || { echo "missing required receipt: $file" >&2; exit 66; }
  jq -e 'type == "object" or type == "array"' "$file" >/dev/null
done

core_release=$(json_or_null "$inputs/release/core.json" "$work/core-release-null.json")
interchange_release=$(json_or_null "$inputs/release/interchange.json" "$work/interchange-release-null.json")
local_release=$(json_or_null "$inputs/release/local.json" "$work/local-release-null.json")
design_release=$(json_or_null "$inputs/release/design.json" "$work/design-release-null.json")
for release in "$core_release" "$interchange_release" "$local_release" "$design_release"; do jq -e 'type == "object" or . == null' "$release" >/dev/null; done

if cmp -s "$inputs/local/bundle-a/replay.json" "$inputs/local/bundle-b/replay.json"; then local_replay_equal=true; else local_replay_equal=false; fi
if cmp -s "$inputs/design/envelope-a/replay.json" "$inputs/design/envelope-b/replay.json"; then design_replay_equal=true; else design_replay_equal=false; fi

jq -S -n -f "$root/scripts/project-facts.jq" \
  --slurpfile denominator "$denominator" --slurpfile lock "$lock" --slurpfile graph "$graph" --slurpfile integrity "$work/input-integrity.json" \
  --slurpfile core_release "$core_release" --slurpfile interchange_release "$interchange_release" --slurpfile local_release "$local_release" --slurpfile design_release "$design_release" \
  --slurpfile authority "$inputs/authority.json" --slurpfile kit_manifest "$inputs/interchange/consumer-kit-v2/manifest.json" \
  --slurpfile local_report "$inputs/local/adoption-report.json" --slurpfile local_final "$inputs/local/final-facts.json" --slurpfile local_graph "$inputs/local/meta-graph.json" --slurpfile local_immutable "$inputs/local/immutable-inputs.json" \
  --slurpfile design_report "$inputs/design/envelope-adoption-report.json" --slurpfile design_facts "$inputs/design/envelope-facts.json" --slurpfile design_graph "$inputs/design/envelope-graph.json" --slurpfile design_immutable "$inputs/design/immutable-inputs.json" \
  --argjson local_replay_equal "$local_replay_equal" --argjson design_replay_equal "$design_replay_equal" > "$work/facts.json"

render_packet() {
  jq -S -n -f "$root/scripts/render-packet.jq" --slurpfile denominator "$denominator" --slurpfile graph "$graph" --slurpfile facts "$work/facts.json"
}
render_packet > "$work/packet-a.json"
render_packet > "$work/packet-b.json"

packet_byte_match=false
packet_digest_match=false
if cmp -s "$work/packet-a.json" "$work/packet-b.json"; then packet_byte_match=true; fi
packet_a_sha=$(sha256sum "$work/packet-a.json" | awk '{print $1}')
packet_b_sha=$(sha256sum "$work/packet-b.json" | awk '{print $1}')
if test "$packet_a_sha" = "$packet_b_sha"; then packet_digest_match=true; fi
if test "$packet_byte_match" != true || test "$packet_digest_match" != true; then echo "non-deterministic semantic packet" >&2; exit 65; fi

cp "$work/packet-a.json" "$output/semantic-forge-packet.json"
jq -S -n --arg packet_sha256 "$packet_a_sha" --argjson byte_match "$packet_byte_match" --argjson digest_match "$packet_digest_match" '
  {schema:"gooo/semantic-forge/replay/v1",packet_sha256:$packet_sha256,
   comparisons_satisfied:([$byte_match,$digest_match] | map(select(. == true)) | length),comparisons_total:2,
   mismatches:([$byte_match,$digest_match] | map(select(. != true)) | length),method:["BYTE_IDENTICAL_PACKET","SHA256_PACKET"]}
' > "$output/replay.json"

test "$(find "$output" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 2
test -f "$output/semantic-forge-packet.json"
test -f "$output/replay.json"
