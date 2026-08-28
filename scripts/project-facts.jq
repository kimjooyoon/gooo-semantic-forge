def release_ok($release; $expected):
  $release != null and
  $release.id == $expected.release_id and
  $release.tag_name == $expected.tag and
  $release.target_commitish == $expected.target_commit_sha and
  $release.draft == false and
  $release.prerelease == $expected.prerelease;

def asset_ok($release; $asset):
  $release != null and any($release.assets[]?;
    .id == $asset.id and .name == $asset.name and .size == $asset.size and
    .digest == ("sha256:" + $asset.sha256));

def closed($reason):
  {state:"CLOSED", reason:$reason, next_operation:"NONE", details:[]};
def unknown($stage; $step; $reason; $next):
  {state:"UNKNOWN", stage:$stage, step:$step, reason:$reason,
   unknown_class:"DIRECT_MISSING", next_operation:$next, blocked_by:[], details:[]};
def refuted($reason; $next; $details):
  {state:"REFUTED", reason:$reason, next_operation:$next, details:$details};

def graph_activity_count($graph):
  [$graph.nodes[]? | select(.kind == "Activity")] | length;
def activity_id($graph; $activity):
  [$graph.nodes[]? | select(.kind == "Activity" and .name == $activity) | .id] |
  if length == 1 then .[0] else null end;
def expected_causal_edges($denominator; $graph):
  [
    $denominator.cells[] as $cell |
    $cell.depends_on[] as $predecessor_id |
    ($denominator.cells[] | select(.id == $predecessor_id)) as $predecessor |
    {predicate:"used", subject:activity_id($graph; $cell.activity), object:$predecessor.cell_entity_id}
  ] | sort_by(.subject, .object);
def observed_causal_edges($denominator; $graph):
  ([$denominator.cells[] | activity_id($graph; .activity)]) as $activity_ids |
  ([$denominator.cells[].cell_entity_id]) as $cell_ids |
  [
    $graph.relations[]? |
    select(.predicate == "used") |
    select(.subject as $subject | .object as $object |
      ($activity_ids | index($subject)) != null and ($cell_ids | index($object)) != null) |
    {predicate, subject, object}
  ] | sort_by(.subject, .object);
def expected_output_edges($denominator; $graph):
  [
    $denominator.cells[] as $cell |
    {predicate:"wasGeneratedBy", subject:$cell.cell_entity_id, object:activity_id($graph; $cell.activity)}
  ] | sort_by(.subject, .object);
def observed_output_edges($denominator; $graph):
  ([$denominator.cells[] | activity_id($graph; .activity)]) as $activity_ids |
  ([$denominator.cells[].cell_entity_id]) as $cell_ids |
  [
    $graph.relations[]? |
    select(.predicate == "wasGeneratedBy") |
    select(.subject as $subject | .object as $object |
      ($cell_ids | index($subject)) != null and ($activity_ids | index($object)) != null) |
    {predicate, subject, object}
  ] | sort_by(.subject, .object);
def graph_shape($graph):
  if $graph == null then null else {
    node_kinds:([$graph.nodes[]? | .kind] | sort | group_by(.) | map({kind:.[0], count:length})),
    relation_profile:([$graph.relations[]? | {predicate, status}] | sort_by(.predicate, .status) | group_by(.) | map({predicate:.[0].predicate, status:.[0].status, count:length})),
    ir_status:$graph.ir.status,
    lowering_status:$graph.lowering.status,
    output_status:$graph.output.status,
    projection_status:$graph.projection.status
  } end;
def exact_pair($pair):
  ($pair | type) == "object" and
  ($pair.before | type) == "object" and
  ($pair.after | type) == "object" and
  ($pair.before.scenario_digest | type) == "string" and
  ($pair.before.input_digest | type) == "string" and
  ($pair.before.contract_digest | type) == "string" and
  ($pair.before.toolchain_digest | type) == "string" and
  $pair.before.scenario_digest == $pair.after.scenario_digest and
  $pair.before.input_digest == $pair.after.input_digest and
  $pair.before.contract_digest == $pair.after.contract_digest and
  $pair.before.toolchain_digest == $pair.after.toolchain_digest;

($denominator[0]) as $d |
($lock[0]) as $l |
($graph[0]) as $forge_graph |
($integrity[0]) as $integrity_value |
($core_release[0]) as $core |
($interchange_release[0]) as $interchange |
($local_release[0]) as $local_release_input |
($design_release[0]) as $design_release_input |
($authority[0]) as $a |
($kit_manifest[0]) as $kit |
($local_report[0]) as $local_report_value |
($local_final[0]) as $local_final_value |
($local_graph[0]) as $local_graph_value |
($local_immutable[0]) as $local_immutable_value |
($design_report[0]) as $design_report_value |
($design_facts[0]) as $design_facts_value |
($design_graph[0]) as $design_graph_value |
($design_immutable[0]) as $design_immutable_value |

(
  $d.schema == "gooo/semantic-forge/denominator/v1" and
  $d.target_cells == 12 and ($d.cells | length) == 12 and
  ([$d.cells[].id] | unique | length) == 12 and
  ([$d.cells[].activity] | unique | length) == 12 and
  ([$d.cells[].cell_entity_id] | unique | length) == 12 and
  ([$d.proof_totals[].total] | add) == 12 and
  ([$d.indicator_totals[].total] | add) == 12 and
  ([$d.proof_totals[] | select(.total == 4)] | length) == 3 and
  ([$d.indicator_totals[] | select(.total == 4)] | length) == 3
) as $denominator_ok |
(
  ([$forge_graph.nodes[]? | select(.kind == "Activity") | .name] | sort) ==
    ([$d.cells[].activity] | sort) and
  expected_causal_edges($d; $forge_graph) == observed_causal_edges($d; $forge_graph) and
  expected_output_edges($d; $forge_graph) == observed_output_edges($d; $forge_graph) and
  $integrity_value.acquisition_receipt == true and
  $integrity_value.source_graph_binding == true
) as $meta_bindings_ok |

(
  release_ok($core; $l.core) and asset_ok($core; $l.core.assets.binary) and
  asset_ok($core; $l.core.assets.checksums) and
  $integrity_value.raw_assets.core == true and $integrity_value.members.core_release == true
) as $core_ok |
(
  release_ok($interchange; $l.interchange) and asset_ok($interchange; $l.interchange.assets.consumer_kit) and
  $integrity_value.raw_assets.interchange == true and
  $integrity_value.members.interchange_release == true and $integrity_value.members.kit_manifest == true
) as $interchange_release_ok |
(
  $kit.schema == "gooo/interchange/released-domain-consumer-kit-manifest/v2" and
  $kit.authority.read_only == true and
  $kit.authority.repository_checkout_required == false and
  $kit.authority.cross_project_required_gates == 0 and
  $kit.authority.product_generation_authorized == false
) as $kit_ok |

(
  release_ok($local_release_input; $l.local) and asset_ok($local_release_input; $l.local.assets.ci_artifact) and
  $integrity_value.raw_assets.local == true and $integrity_value.members.local_release == true and
  $integrity_value.members.local_receipts == true
) as $local_release_identity_ok |
(
  $local_report_value.schema == "gooo/local-ledger/released-domain-envelope-v2-adoption-evaluation/v1" and
  $local_report_value.subject_sha == $l.local.target_commit_sha and
  $local_report_value.summary.cells_closed == 12 and $local_report_value.summary.cells_total == 12 and
  $local_report_value.summary.cells_unknown == 0 and $local_report_value.summary.cells_refuted == 0 and
  $local_final_value.meta.activities_observed == 12 and $local_final_value.meta.activities_total == 12
) as $local_receipts_ok |

(
  release_ok($design_release_input; $l.design) and asset_ok($design_release_input; $l.design.assets.ci_artifact) and
  $integrity_value.raw_assets.design == true and $integrity_value.members.design_release == true and
  $integrity_value.members.design_receipts == true
) as $design_release_identity_ok |
(
  $design_report_value.schema == "gooo/design-evidence/released-domain-envelope-adoption-report/v2" and
  $design_report_value.subject_sha == $l.design.target_commit_sha and
  $design_report_value.summary.closed == 12 and $design_report_value.summary.total == 12 and
  $design_report_value.summary.unknown == 0 and $design_report_value.summary.refuted == 0 and
  $design_report_value.state_examples.normal.observed == 1 and $design_report_value.state_examples.refuted.observed == 5
) as $design_receipts_ok |

(
  $local_immutable_value.core.identity_verified == true and
  $local_immutable_value.core.repository == $l.core.repository and
  $local_immutable_value.core.tag == $l.core.tag and
  $local_immutable_value.core.target_commit_sha == $l.core.target_commit_sha and
  $local_immutable_value.core.asset_sha256 == $l.core.assets.binary.sha256 and
  $local_immutable_value.kit.identity_verified == true and
  $local_immutable_value.kit.repository == $l.interchange.repository and
  $local_immutable_value.kit.tag == $l.interchange.tag and
  $local_immutable_value.kit.target_commit_sha == $l.interchange.target_commit_sha and
  $local_immutable_value.kit.asset_sha256 == $l.interchange.assets.consumer_kit.sha256 and
  $design_immutable_value.core.identity_verified == true and
  $design_immutable_value.core.tag == $l.core.tag and
  $design_immutable_value.core.target_commit_sha == $l.core.target_commit_sha and
  $design_immutable_value.core.asset_sha256 == $l.core.assets.binary.sha256 and
  $design_immutable_value.specification.identity_verified == true and
  $design_immutable_value.specification.tag == $l.interchange.tag and
  $design_immutable_value.specification.target_commit_sha == $l.interchange.target_commit_sha and
  $design_immutable_value.specification.consumer_kit_asset_sha256 == $l.interchange.assets.consumer_kit.sha256
) as $primitive_ok |
(
  graph_activity_count($local_graph_value) == 12 and graph_activity_count($design_graph_value) == 12 and
  graph_shape($local_graph_value) == graph_shape($design_graph_value) and
  $local_report_value.summary.evidence == $local_report_value.summary.evidence_total and
  $design_report_value.summary.evidence.observed == $design_report_value.summary.evidence.total
) as $shape_ok |
(
  $local_final_value.unknown_coordinates.all_six_fields == true and
  $local_final_value.unknown_coordinates.six_fields == 6 and
  $local_final_value.unknown_coordinates.direct_missing == 1 and
  $local_final_value.unknown_coordinates.dependency_blocked == 1 and
  $design_report_value.source.resolution_precedence == ["REFUTED", "UNKNOWN", "CLOSED"] and
  $design_report_value.source.unknown_coordinate_fields.observed == 6 and
  $design_report_value.source.unknown_coordinate_fields.total == 6 and
  $design_report_value.state_examples.unknown.coordinate_fields_observed == 6
) as $resolution_ok |
(
  $local_replay_equal and $design_replay_equal and
  $local_report_value.summary.envelope_files == $local_report_value.summary.envelope_files_total and
  $design_report_value.summary.envelope_files.observed == $design_report_value.summary.envelope_files.total and
  $local_report_value.summary.generated_artifacts_observed == $local_report_value.summary.generated_artifacts_total and
  $design_report_value.artifact_counts.outputs.observed == $design_report_value.artifact_counts.outputs.total
) as $artifact_ok |
(
  $local_report_value.adoption.external_utility.observed == 0 and $local_report_value.adoption.external_utility.total == 1 and
  $local_report_value.adoption.external_utility.state == "UNKNOWN" and
  $design_report_value.adoption.external_utility.observed == 0 and $design_report_value.adoption.external_utility.total == 1 and
  $design_report_value.adoption.external_utility.state == "UNKNOWN"
) as $utility_ok |
(
  $local_report_value.authority.repository_writes == 0 and $local_report_value.authority.local_test_executions == 0 and
  $local_report_value.authority.cross_project_required_gates == 0 and $local_report_value.authority.product_generation_authorized == false and
  $design_report_value.authority.repository_writes == 0 and $design_report_value.authority.cross_project_required_gates == 0 and
  $design_report_value.authority.product_generation_authorized == false and
  $a.repository_writes == 0 and $a.product_local_tests_run == 0 and $a.cross_project_required_gates == 0 and
  $a.common_generator_authorized == false and $a.product_generation_authorized == false and
  $a.central_orchestration_authorized == false and $a.product_source_checkouts == 0 and
  $a.product_source_files_read == 0 and $a.product_source_lines_read == 0
) as $authority_ok |
(
  [
    (if $local_report_value.decision == "RELEASED_DOMAIN_ENVELOPE_V2_CANDIDATE_CLOSED" then empty else "TOP_LEVEL_DECISION_UNRECOGNIZED" end),
    (if $design_report_value.decision == "ADOPTION_CANDIDATE_CONFORMANT" then empty else "TOP_LEVEL_DECISION_UNRECOGNIZED" end),
    (if $local_final_value.adversarial.fixed_point.decision == "FAIL_CLOSED" then empty else "FIXED_POINT_INVALID" end)
  ]
) as $baseline_failures |
(
  $interchange_release_ok and $kit_ok and $l.local.repository != $l.design.repository and
  ($baseline_failures | length) == 0
) as $baseline_ok |

(
  if $core == null then unknown("CORE_RELEASE"; "OBSERVE_CORE_META_TOOL"; "CORE_META_TOOL_UNAVAILABLE"; "FETCH_PINNED_CORE_RELEASE")
  elif $core_ok then closed("CORE_META_TOOL_OBSERVED")
  else refuted("CORE_META_TOOL_ACQUISITION_OR_IDENTITY_MISMATCH"; "RESTORE_PINNED_CORE_RELEASE"; []) end
) as $core_fact |
(
  if $local_release_input == null then unknown("PRODUCT_RELEASE"; "OBSERVE_LOCAL_PRODUCT_RELEASE"; "LOCAL_PRODUCT_RELEASE_UNAVAILABLE"; "FETCH_PINNED_LOCAL_PRODUCT_RELEASE")
  elif $local_release_identity_ok and $local_receipts_ok then closed("LOCAL_PRODUCT_RELEASE_OBSERVED")
  else refuted("LOCAL_PRODUCT_RELEASE_ACQUISITION_OR_IDENTITY_MISMATCH"; "RESTORE_PINNED_LOCAL_PRODUCT_RELEASE"; []) end
) as $local_fact |
(
  if $design_release_input == null then unknown("PRODUCT_RELEASE"; "OBSERVE_DESIGN_PRODUCT_RELEASE"; "DESIGN_PRODUCT_RELEASE_UNAVAILABLE"; "FETCH_PINNED_DESIGN_PRODUCT_RELEASE")
  elif $design_release_identity_ok and $design_receipts_ok then closed("DESIGN_PRODUCT_RELEASE_OBSERVED")
  else refuted("DESIGN_PRODUCT_RELEASE_ACQUISITION_OR_IDENTITY_MISMATCH"; "RESTORE_PINNED_DESIGN_PRODUCT_RELEASE"; []) end
) as $design_fact |
(
  if $baseline_ok then closed("TWO_CONSUMER_BASELINE_OBSERVED")
  else refuted(($baseline_failures[0] // "TWO_CONSUMER_BASELINE_MISMATCH"); "RESTORE_PINNED_TWO_CONSUMER_BASELINE"; $baseline_failures) end
) as $baseline_fact |
(
  if $primitive_ok then closed("SHARED_PRIMITIVE_BOUND") else refuted("SHARED_PRIMITIVE_MISMATCH"; "RESTORE_SHARED_PRIMITIVE"; []) end
) as $primitive_fact |
(
  if $shape_ok then closed("SHARED_GRAPH_SHAPE_BOUND") else refuted("SHARED_GRAPH_SHAPE_MISMATCH"; "RESTORE_SHARED_GRAPH_SHAPE"; []) end
) as $shape_fact |
(
  if $resolution_ok then closed("SHARED_RESOLUTION_MODEL_BOUND") else refuted("SHARED_RESOLUTION_MODEL_MISMATCH"; "RESTORE_SHARED_RESOLUTION_MODEL"; []) end
) as $resolution_fact |
(
  if $artifact_ok then closed("SHARED_ARTIFACT_MODEL_BOUND") else refuted("SHARED_ARTIFACT_MODEL_MISMATCH"; "RESTORE_SHARED_ARTIFACT_MODEL"; []) end
) as $artifact_fact |
(
  if $utility_ok then closed("TWO_PRODUCT_EXTERNAL_UTILITY_REMAINS_UNKNOWN") else refuted("PRODUCT_UTILITY_LAUNDERED"; "REMOVE_UNEVIDENCED_UTILITY_CLAIM"; []) end
) as $utility_fact |
(
  if $authority_ok then closed("READ_ONLY_PRODUCT_AUTHORITY_PRESERVED") else refuted("READ_ONLY_PRODUCT_AUTHORITY_ESCALATED"; "REMOVE_GENERATION_OR_ORCHESTRATION_AUTHORITY"; []) end
) as $authority_fact |
(
  if $denominator_ok and $meta_bindings_ok then closed("TWELVE_META_ACTIVITIES_AND_CAUSAL_EDGES_BOUND")
  else refuted("GOOO_META_ACTIVITY_OR_CAUSAL_EDGE_MISMATCH"; "RESTORE_PINNED_GOOO_GRAPH_BINDING"; []) end
) as $meta_fact |
{
  schema:"gooo/semantic-forge/facts/v2",
  facts:{
    TWO_CONSUMER_BASELINE:$baseline_fact,
    CORE_META_TOOL:$core_fact,
    LOCAL_PRODUCT_RELEASE:$local_fact,
    DESIGN_PRODUCT_RELEASE:$design_fact,
    SHARED_PRIMITIVE:$primitive_fact,
    SHARED_GRAPH_SHAPE:$shape_fact,
    SHARED_RESOLUTION_MODEL:$resolution_fact,
    SHARED_ARTIFACT_MODEL:$artifact_fact,
    AGGREGATE_UTILITY_UNKNOWN:$utility_fact,
    READ_ONLY_PRODUCT_AUTHORITY:$authority_fact,
    TWELVE_META_ACTIVITIES:$meta_fact,
    OPTIONAL_FORGE_EXPERIMENT:closed("OPTIONAL_FORGE_EXPERIMENT_DEPENDENCY_GRAPH_READY")
  },
  authority:$a,
  input_counts:{
    releases:{observed:([$core, $interchange, $local_release_input, $design_release_input] | map(select(. != null)) | length), total:4},
    assets:{observed:([
      $integrity_value.raw_assets.core_binary, $integrity_value.raw_assets.core_checksums, $integrity_value.raw_assets.interchange,
      $integrity_value.raw_assets.local, $integrity_value.raw_assets.design
    ] | map(select(. == true)) | length), total:5}
  },
  acquisition:{
    boundary:"RAW_LOCKED_ARCHIVES_AND_MEMBER_DIGEST_RECEIPT",
    receipt_verified:$integrity_value.acquisition_receipt,
    source_sha256:$integrity_value.source_sha256,
    graph_sha256:$integrity_value.graph_sha256,
    source_graph_binding:$integrity_value.source_graph_binding,
    raw_assets:$integrity_value.raw_assets,
    members:$integrity_value.members
  },
  utility:{
    declarations:(($local_report_value.adoption.external_utility.total // 0) + ($design_report_value.adoption.external_utility.total // 0)),
    evidence:(($local_report_value.adoption.external_utility.observed // 0) + ($design_report_value.adoption.external_utility.observed // 0)),
    state:(if $utility_ok then "UNKNOWN" else "INVALID" end)
  },
  improvement:{
    exact_before_after_pairs:{
      observed:(if [exact_pair($local_report_value.improvement), exact_pair($design_report_value.improvement)] | any then 1 else 0 end),
      total:1
    },
    state:"UNKNOWN",
    reason:"COMPLETE_SAME_SCENARIO_INPUT_CONTRACT_TOOLCHAIN_PAIR_NOT_PROVIDED"
  }
}
