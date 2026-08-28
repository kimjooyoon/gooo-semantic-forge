# Gooo Semantic Forge

Gooo Semantic Forge is an optional, read-only protocol and CLI for composing a
single project experiment from immutable public release evidence and Gooo
relationships. It is not a package manager, a build system, a common generator,
or a central release coordinator.

The initial experiment reads exactly four released identities: Gooo Core
`v0.4.0-dev`, Gooo Interchange `v0.3.0-dev`, Local Ledger `v0.9.0-dev`, and
Design Evidence `v0.8.0-dev`. It reads release assets only: it never checks out
or imports product source.

## User path

1. A caller supplies the five pinned raw release archives, the released receipt
   members, and an immutable acquisition receipt in a caller-owned directory.
2. `gooo-semantic-forge observe` verifies archive SHA-256/size, receipt-member
   digests, the pinned Gooo source digest, and the pinned released graph digest.
3. It writes exactly two files to an empty caller-owned output directory that
   is outside the Forge repository:
   `semantic-forge-packet.json` and `replay.json`.
4. The caller may review the selected experiment packet. Forge never runs it,
   edits a product, creates a pull request, merges code, or deploys anything.

Forge is optional. A product can develop and release when Forge is absent,
unavailable, UNKNOWN, or REFUTED. Forge is not a required product CI gate and
cross-project required gates remain zero.

Forge verifies released upstream test receipts; that is not a product build or
test re-execution. CI records `ci_build_executions=0`,
`ci_build_wall_ms=0`, and `NO_PRODUCT_BUILD_REQUIRED`. Receipt reuse is CLOSED
only when subject, contract, toolchain, and command digests are all present and
equal. The v1 public receipts do not provide a command digest, so their reuse
and any time-saving claim remain UNKNOWN rather than inferred. Product-source
checkout, build, test, read, and write counts remain zero.

The packet declares only its two expected output names and expected replay
comparison count. A separate runtime observation records the files actually
created and the replay result, so an output never proves its own existence.

The fixed 12-cell contract, immutable inputs, state rules, and authority
boundary are defined in [the RFC](docs/rfcs/semantic-forge-v1.md).
