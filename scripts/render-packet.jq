def closed($cell):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"CLOSED", reason:$cell.closed_reason, unknown_class:null, next_operation:"NONE", blocked_by:[], details:[], frontier:[]};
def direct_unknown($cell; $fact):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"UNKNOWN", stage:$fact.stage, step:$fact.step, reason:$fact.reason,
   unknown_class:"DIRECT_MISSING", next_operation:$fact.next_operation,
   blocked_by:[], details:[], frontier:[$cell.id]};
def direct_refuted($cell; $fact):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"REFUTED", stage:$cell.stage, step:$cell.step, reason:$fact.reason,
   unknown_class:null, next_operation:$fact.next_operation, blocked_by:[],
   details:($fact.details // []), frontier:[$cell.id]};
def dependency_unknown($cell; $frontier):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"UNKNOWN", stage:"DEPENDENCY", step:"RESOLVE_DECLARED_PREDECESSORS", reason:"DEPENDENCY_BLOCKED",
   unknown_class:"DEPENDENCY_BLOCKED", next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",
   blocked_by:$frontier, details:[], frontier:$frontier};
def dependency_refuted($cell; $frontier):
  ($cell | del(.closed_reason, .unknown_reason, .refuted_reason)) +
  {state:"REFUTED", stage:"DEPENDENCY", step:"RESOLVE_DECLARED_PREDECESSORS", reason:"DEPENDENCY_REFUTED",
   unknown_class:null, next_operation:"RESTORE_REFUTED_PREDECESSORS", blocked_by:[],
   details:$frontier, frontier:$frontier};
def activity_bound($graph; $activity):
  ([$graph.nodes[]? | select(.kind == "Activity" and .name == $activity)] | length) == 1;

($denominator[0]) as $d |
($graph[0]) as $g |
($facts[0]) as $f |
def cell($id): $d.cells[] | select(.id == $id);
def direct($cell):
  $f.facts[$cell.id] as $fact |
  if activity_bound($g; $cell.activity) | not then
    direct_refuted($cell; {reason:"GOOO_META_ACTIVITY_OR_CAUSAL_EDGE_MISMATCH", next_operation:"RESTORE_PINNED_GOOO_GRAPH_BINDING", details:[]})
  elif $fact.state == "REFUTED" then direct_refuted($cell; $fact)
  elif $fact.state == "UNKNOWN" then direct_unknown($cell; $fact)
  else closed($cell) end;
def evaluate($id):
  cell($id) as $cell |
  [$cell.depends_on[] | evaluate(.)] as $dependencies |
  direct($cell) as $own |
  ([$dependencies[] | select(.state == "REFUTED") | .frontier[]] | unique | sort) as $refuted_frontier |
  ([$dependencies[] | select(.state == "UNKNOWN") | .frontier[]] | unique | sort) as $unknown_frontier |
  if $own.state == "REFUTED" then $own
  elif ($refuted_frontier | length) > 0 then dependency_refuted($cell; $refuted_frontier)
  elif $own.state == "UNKNOWN" then $own
  elif ($unknown_frontier | length) > 0 then dependency_unknown($cell; $unknown_frontier)
  else $own end;
($d.cells | map(evaluate(.id))) as $evaluated_cells |
($evaluated_cells | map(del(.frontier))) as $cells |
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
    input_releases:$f.input_counts.releases, input_assets:$f.input_counts.assets
  },
  proofs:(["FOUNDATION", "COHERENCE", "REGRESSION"] | map(. as $choice | {choice:$choice, closed:([$cells[] | select(.proof_choice == $choice and .state == "CLOSED")] | length), total:([$cells[] | select(.proof_choice == $choice)] | length)})),
  indicator_classes:(["DRIVER", "OUTCOME", "GUARDRAIL"] | map(. as $class | {class:$class, closed:([$cells[] | select(.indicator_class == $class and .state == "CLOSED")] | length), total:([$cells[] | select(.indicator_class == $class)] | length)})),
  utility:{declarations:$f.utility.declarations, evidence:$f.utility.evidence, state:$f.utility.state},
  improvement:$f.improvement,
  authority:{
    product_source_checkouts:$f.authority.product_source_checkouts,
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
  acquisition:$f.acquisition,
  outputs:{expected_total:2, expected_names:["semantic-forge-packet.json", "replay.json"]},
  replay:{expected_comparisons:2, method:["BYTE_IDENTICAL_PACKET", "SHA256_PACKET"]},
  cells:$cells
}
