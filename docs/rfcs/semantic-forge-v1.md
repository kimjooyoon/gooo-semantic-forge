# RFC: Gooo Semantic Forge v1

Status: experimental, optional, and read-only.

## Decision

Semantic Forge composes one reviewable experiment packet from released Gooo
relationships and immutable public evidence. It is not a central build system,
generic generator, product code generator, release orchestrator, or required
cross-project gate.

Local Ledger and Design Evidence remain independently releasable. Neither
imports Forge, waits for Forge CI, or grants Forge mutation authority. A Forge
failure changes only Forge's packet decision.

## Immutable inputs

The v1 lock pins only public release identities and release assets:

- Core `v0.4.0-dev`, including the Linux CLI and `SHA256SUMS`;
- Interchange `v0.3.0-dev` consumer kit;
- Local Ledger `v0.9.0-dev` CI artifact;
- Design Evidence `v0.8.0-dev` CI artifact.

Forge requires five raw locked archives, the released receipt members, and an
immutable acquisition receipt. It verifies release ID, tag, target commit,
prerelease state, asset ID, asset name, asset size, archive SHA-256, and each
receipt-member digest. It never checks out, imports, scans, or counts product
source.

The two product CI artifacts are upstream test receipts, not a request to
rebuild or retest either product. CI reports `ci_build_executions=0` and
`ci_build_wall_ms=0` with reason `NO_PRODUCT_BUILD_REQUIRED`. A receipt is
reused only when its `subject_digest`, `contract_digest`, `toolchain_digest`,
and `command_digest` are all present and exactly match. A mismatch is
`STALE`; a missing digest is `UNKNOWN`. The pinned v1 artifacts lack a command
digest, so CI records two available receipts, zero reused, zero re-executions
skipped, zero stale, and two UNKNOWN. This is separate from the one current
Forge cross-product conformer execution, which reads the receipts and Gooo
activity graph without executing product code. Product-source checkout, build,
test, read, and write counts are all zero.

## Semantic authority

The denominator has exactly twelve cells and `observation.gooo` has exactly
twelve Gooo activities. Each cell binds to one and only one released activity.
Every declared `depends_on` predecessor is also a pinned Gooo graph `used`
edge from the successor activity to the predecessor cell output; every cell has
the matching `wasGeneratedBy` edge. The source and graph SHA-256 values are
locked with the Core release identity, so a caller-supplied graph with matching
activity names alone is insufficient.
The CLI, shell, and jq project and validate released receipts; they may not add
a cell, close a cell merely because a declaration exists, or claim a semantic
fact not bound to an activity.

The proof and indicator distributions are fixed at FOUNDATION/COHERENCE/
REGRESSION `4/4/4` and DRIVER/OUTCOME/GUARDRAIL `4/4/4`.

## State and scenarios

`REFUTED` takes precedence over `UNKNOWN`. UNKNOWN always contains `stage`,
`step`, `reason`, `unknown_class`, `next_operation`, and `blocked_by`.

The evaluator derives all propagation from denominator `depends_on`; it has no
product-specific dependency list. A direct missing cell has `blocked_by: []`.
Dependent UNKNOWN and REFUTED cells carry the sorted, stable, minimal frontier
of direct predecessor cell IDs. This preserves independent Design evidence when
Local is missing and propagates Core, Local, Design, and release contradictions
only along their declared edges.

The CI scenario contract is exactly one normal case, one direct-missing UNKNOWN
case, and five fail-closed REFUTED cases. The direct-missing Design release
case closes four cells and marks the Design release plus its seven dependent
cells UNKNOWN; dependencies are marked `DEPENDENCY_BLOCKED` rather than being
silently closed. Unknown top-level product decisions and invalid fixed-point
receipts are REFUTED.

The normal packet intentionally reports two declared external utility cases,
zero evidence, and `UNKNOWN`. It also reports an exact before/after pair of
`0/1` as `UNKNOWN`; no utility or improvement is inferred.

## Outputs and replay

An empty caller-owned output directory receives exactly:

1. `semantic-forge-packet.json`
2. `replay.json`

The packet contains the denominator's expected two output names and expected
two replay comparisons only. The CLI renders the packet twice from the same
verified receipts; its separate `replay.json` reports the byte/SHA-256 result.
CI invokes the CLI twice and records actual output names, file digests, and
outer replay comparisons in a runtime observation. Repository-root and
repository-descendant output paths fail closed before any directory is created.

## Authority boundary

Product repository writes, product-local tests, and cross-project required
gates are all zero. Common generator, product-generation, and central
orchestration authority are false. Forge may write only its two outputs under a
caller-owned temporary or output directory. It may not patch products,
automatically repair or merge changes, deploy, or invoke a product build.

### Future product-generation authorization

This v1 denominator can never turn `product_generation_authorized` from `0` to
`1`: any such value is a REFUTED authority escalation. A future denominator
version may consider `1` only after all of the following immutable evidence is
released independently by every affected product:

- a product-owned, exact-subject authorization receipt names the allowed
  generated artifact scope and a product-owned rollback path;
- the receipt's subject, contract, toolchain, and command digests are all
  present and exactly match the proposed operation;
- two independently released consumer receipts demonstrate the declared
  utility with non-zero evidence and an exact, reproducible before/after pair;
- the proposed operation remains opt-in for each product, with zero
  cross-project required gates, and does not grant a common generator or
  central orchestration authority.

Each condition must be bound to a new Gooo activity and evaluated in the new
denominator. A Forge declaration, a missing digest, a simulated counterexample,
or an unevidenced utility claim cannot authorize the transition.

## CI-only validation

GitHub Actions is the execution authority for v1. It uses Go 1.27, runs
`go fix` only when this repository actually has a module root, and records the
actual module-root count. It records root-README-excluded inventory, physical
lines, Go and Gooo file/line counts, peak RSS, and actual wall milliseconds for
release receipt verification, current conformance, scenario evaluation,
deterministic replay, and total execution. It separately records upstream test
receipt availability/reuse, current subject checks, skipped re-executions, and
stale receipts. Saved time and speed improvement remain UNKNOWN because no
exact before/after pair exists. These dynamic measurements stay outside the
deterministic packet bytes.

The workflow runs for pull requests and pushes to `main`. It records an ID,
measured wall time, and a SHA-256 of each check's display command. That display
hash is explicitly non-authoritative metadata: it is never an execution
identity and is excluded from receipt reuse, improvement, and authorization
decisions. It distinguishes custom Forge checks from the two released
Interchange-kit conformer executions, while separately recording zero product
build and test executions. Packet JSON is validated against its Draft 2020-12
schema in Actions. An exact improvement pair is counted only when complete
before/after evidence has the same scenario, input, contract, and toolchain
digests; the current value remains `0/1 UNKNOWN`.
