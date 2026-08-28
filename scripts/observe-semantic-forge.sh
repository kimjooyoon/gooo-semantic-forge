#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: observe-semantic-forge.sh ROOT GOOO_GRAPH INPUT_DIRECTORY OUTPUT_DIRECTORY" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
graph=$2
inputs=$3
output=$4
denominator="$root/contracts/semantic-forge-denominator-v1.json"
lock="$root/contracts/semantic-forge-release-lock-v1.json"
observation="$root/examples/semantic-forge-v1/observation.gooo"

test -f "$graph" || { echo "missing Gooo graph" >&2; exit 66; }
test -d "$inputs" || { echo "missing input directory" >&2; exit 66; }
test -f "$denominator" || { echo "missing denominator" >&2; exit 66; }
test -f "$lock" || { echo "missing release lock" >&2; exit 66; }
test -f "$observation" || { echo "missing Gooo observation" >&2; exit 66; }

if test -e "$output" && test -n "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)"; then
  echo "output directory must be empty" >&2
  exit 73
fi
mkdir -p "$output"

work=$(mktemp -d "${TMPDIR:-/tmp}/gooo-semantic-forge.XXXXXX")
trap 'rm -rf "$work"' EXIT

json_or_null() {
  local candidate=$1
  local fallback=$2
  if test -f "$candidate"; then
    printf '%s\n' "$candidate"
  else
    printf 'null\n' > "$fallback"
    printf '%s\n' "$fallback"
  fi
}

required_json=(
  "$graph"
  "$denominator"
  "$lock"
  "$inputs/release/core.json"
  "$inputs/release/interchange.json"
  "$inputs/release/local.json"
  "$inputs/authority.json"
  "$inputs/interchange/consumer-kit-v2/manifest.json"
  "$inputs/local/adoption-report.json"
  "$inputs/local/final-facts.json"
  "$inputs/local/meta-graph.json"
  "$inputs/local/immutable-inputs.json"
  "$inputs/local/bundle-a/replay.json"
  "$inputs/local/bundle-b/replay.json"
  "$inputs/design/envelope-adoption-report.json"
  "$inputs/design/envelope-facts.json"
  "$inputs/design/envelope-graph.json"
  "$inputs/design/immutable-inputs.json"
  "$inputs/design/envelope-a/replay.json"
  "$inputs/design/envelope-b/replay.json"
)
for file in "${required_json[@]}"; do
  test -f "$file" || { echo "missing required receipt: $file" >&2; exit 66; }
  jq -e 'type == "object" or type == "array"' "$file" >/dev/null
done

design_release=$(json_or_null "$inputs/release/design.json" "$work/design-release-null.json")
jq -e 'type == "object" or . == null' "$design_release" >/dev/null

if cmp -s "$inputs/local/bundle-a/replay.json" "$inputs/local/bundle-b/replay.json"; then
  local_replay_equal=true
else
  local_replay_equal=false
fi
if cmp -s "$inputs/design/envelope-a/replay.json" "$inputs/design/envelope-b/replay.json"; then
  design_replay_equal=true
else
  design_replay_equal=false
fi

jq -S -n -f "$root/scripts/project-facts.jq" \
  --slurpfile denominator "$denominator" \
  --slurpfile lock "$lock" \
  --slurpfile graph "$graph" \
  --slurpfile core_release "$inputs/release/core.json" \
  --slurpfile interchange_release "$inputs/release/interchange.json" \
  --slurpfile local_release "$inputs/release/local.json" \
  --slurpfile design_release "$design_release" \
  --slurpfile authority "$inputs/authority.json" \
  --slurpfile kit_manifest "$inputs/interchange/consumer-kit-v2/manifest.json" \
  --slurpfile local_report "$inputs/local/adoption-report.json" \
  --slurpfile local_final "$inputs/local/final-facts.json" \
  --slurpfile local_graph "$inputs/local/meta-graph.json" \
  --slurpfile local_immutable "$inputs/local/immutable-inputs.json" \
  --slurpfile design_report "$inputs/design/envelope-adoption-report.json" \
  --slurpfile design_facts "$inputs/design/envelope-facts.json" \
  --slurpfile design_graph "$inputs/design/envelope-graph.json" \
  --slurpfile design_immutable "$inputs/design/immutable-inputs.json" \
  --argjson local_replay_equal "$local_replay_equal" \
  --argjson design_replay_equal "$design_replay_equal" \
  > "$work/facts.json"

render_packet() {
  jq -S -n -f "$root/scripts/render-packet.jq" \
    --slurpfile denominator "$denominator" \
    --slurpfile graph "$graph" \
    --slurpfile facts "$work/facts.json"
}

render_packet > "$work/packet-a.json"
render_packet > "$work/packet-b.json"

packet_byte_match=false
packet_digest_match=false
if cmp -s "$work/packet-a.json" "$work/packet-b.json"; then
  packet_byte_match=true
fi
packet_a_sha=$(sha256sum "$work/packet-a.json" | awk '{print $1}')
packet_b_sha=$(sha256sum "$work/packet-b.json" | awk '{print $1}')
if test "$packet_a_sha" = "$packet_b_sha"; then
  packet_digest_match=true
fi
if test "$packet_byte_match" != true || test "$packet_digest_match" != true; then
  echo "non-deterministic semantic packet" >&2
  exit 65
fi

cp "$work/packet-a.json" "$output/semantic-forge-packet.json"
jq -S -n \
  --arg packet_sha256 "$packet_a_sha" \
  --argjson byte_match "$packet_byte_match" \
  --argjson digest_match "$packet_digest_match" '
  {
    schema:"gooo/semantic-forge/replay/v1",
    packet_sha256:$packet_sha256,
    comparisons_satisfied:([$byte_match,$digest_match]|map(select(.==true))|length),
    comparisons_total:2,
    mismatches:([$byte_match,$digest_match]|map(select(.!=true))|length),
    method:["BYTE_IDENTICAL_PACKET","SHA256_PACKET"]
  }
' > "$output/replay.json"

test "$(find "$output" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 2
test -f "$output/semantic-forge-packet.json"
test -f "$output/replay.json"
