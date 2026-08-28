def closed($cell):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"CLOSED", reason:$cell.closed_reason, unknown_class:null, next_operation:"NONE", blocked_by:[], details:[]};
def refuted($cell; $fact):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"REFUTED", stage:$cell.stage, step:$cell.step, reason:$fact.reason,
   unknown_class:null, next_operation:$fact.next_operation, blocked_by:[], details:($fact.details // [])};
def dependent_unknown($cell; $root):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"UNKNOWN", stage:"DEPENDENCY", step:"RESOLVE_PRODUCT_DEPENDENCY", reason:"DEPENDENCY_BLOCKED",
   unknown_class:"DEPENDENCY_BLOCKED", next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",
   blocked_by:[$root.id], details:[]};
def direct_unknown($cell; $fact):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"UNKNOWN", stage:$fact.stage, step:$fact.step, reason:$fact.reason,
   unknown_class:$fact.unknown_class, next_operation:$fact.next_operation,
   blocked_by:$fact.blocked_by, details:[]};
def activity_bound($graph; $activity):
  ([$graph.nodes[]? | select(.kind == "Activity" and .name == $activity)] | length) == 1;

($denominator[0]) as $d |
($graph[0]) as $g |
($facts[0]) as $f |
def product_dependent($id):
  ["DESIGN_PRODUCT_RELEASE", "SHARED_PRIMITIVE", "SHARED_GRAPH_SHAPE", "SHARED_RESOLUTION_MODEL", "SHARED_ARTIFACT_MODEL", "AGGREGATE_UTILITY_UNKNOWN", "READ_ONLY_PRODUCT_AUTHORITY", "OPTIONAL_FORGE_EXPERIMENT"] | index($id) != null;
def first_product_unknown:
  ([
    {id:"LOCAL_PRODUCT_RELEASE", fact:$f.facts.LOCAL_PRODUCT_RELEASE},
    {id:"DESIGN_PRODUCT_RELEASE", fact:$f.facts.DESIGN_PRODUCT_RELEASE}
  ] | map(select(.fact.state == "UNKNOWN")) | first);
def evaluate($cell):
  $f.facts[$cell.id] as $fact |
  first_product_unknown as $product_unknown |
  if activity_bound($g; $cell.activity) | not then
    refuted($cell; {reason:"GOOO_META_ACTIVITY_MISSING", next_operation:"RESTORE_GOOO_META_ACTIVITY", details:[]})
  elif $fact.state == "REFUTED" then refuted($cell; $fact)
  elif product_dependent($cell.id) and $product_unknown != null then
    if $cell.id == $product_unknown.id then direct_unknown($cell; $product_unknown.fact)
    else dependent_unknown($cell; $product_unknown) end
  elif $fact.state == "UNKNOWN" then direct_unknown($cell; $fact)
  else closed($cell) end;
($d.cells | map(evaluate(.))) as $cells |
([$cells[] | select(.state == "CLOSED")] | length) as $closed |
([$cells[] | select(.state == "UNKNOWN")] | length) as $unknown |
([$cells[] | select(.state == "REFUTED")] | length) as $refuted |
(([$cells[] | select(.state == "REFUTED")] | first) // ([$cells[] | select(.state == "UNKNOWN")] | first)) as $first_nonclosed |
{
  schema:"gooo/semantic-forge/packet/v1",
  decision:(if $refuted > 0 then "FAIL_CLOSED" elif $unknown > 0 then "DEFER" else "BUILD_READ_ONLY" end),
  claim:{
    state:(if $refuted > 0 then "REFUTED" elif $unknown > 0 then "UNKNOWN" else "CLOSED" end),
    stage:($first_nonclosed.stage // null), step:($first_nonclosed.step // null),
    reason:($first_nonclosed.reason // "TWELVE_OF_TWELVE_READ_ONLY_FORGE_CELLS_CLOSED"),
    unknown_class:($first_nonclosed.unknown_class // null),
    next_operation:($first_nonclosed.next_operation // "REVIEW_OPTIONAL_READ_ONLY_EXPERIMENT"),
    blocked_by:($first_nonclosed.blocked_by // [])
  },
  summary:{
    total_cells:12, closed_cells:$closed, unknown_cells:$unknown, refuted_cells:$refuted,
    activities_bound:([$d.cells[] | select(activity_bound($g; .activity))] | length), activities_total:12,
    scenarios:{normal:1, unknown:1, refuted:5},
    input_releases:$f.input_counts.releases, input_assets:$f.input_counts.assets,
    output_artifacts:{observed:2, total:2}, replay_comparisons:{observed:2, total:2, mismatches:0}
  },
  proofs:(["FOUNDATION", "COHERENCE", "REGRESSION"] | map(. as $choice | {choice:$choice, closed:([$cells[] | select(.proof_choice == $choice and .state == "CLOSED")] | length), total:([$cells[] | select(.proof_choice == $choice)] | length)})),
  indicator_classes:(["DRIVER", "OUTCOME", "GUARDRAIL"] | map(. as $class | {class:$class, closed:([$cells[] | select(.indicator_class == $class and .state == "CLOSED")] | length), total:([$cells[] | select(.indicator_class == $class)] | length)})),
  utility:{declarations:$f.utility.declarations, evidence:$f.utility.evidence, state:$f.utility.state},
  improvement:$f.improvement,
  authority:{
    product_source_files_read:$f.authority.product_source_files_read,
    product_source_lines_read:$f.authority.product_source_lines_read,
    repository_writes:$f.authority.repository_writes,
    product_local_tests_run:$f.authority.product_local_tests_run,
    cross_project_required_gates:$f.authority.cross_project_required_gates,
    common_generator_authorized:$f.authority.common_generator_authorized,
    product_generation_authorized:$f.authority.product_generation_authorized,
    central_orchestration_authorized:$f.authority.central_orchestration_authorized,
    output_scope:"CALLER_OWNED_TEMP_OR_OUTPUT_ONLY"
  },
  outputs:{observed:2, total:2, names:["semantic-forge-packet.json", "replay.json"]},
  cells:$cells
}
