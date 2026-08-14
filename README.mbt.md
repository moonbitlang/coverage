# moon_cov

MoonBit port of Bisect's coverage-report pipeline. Its source tree follows the
original Bisect split:

```text
src/common/bisect_common.mbt  shared coverage types and format identifier
src/report/input.mbt          report discovery, reading, and aggregation
```

The `Input` slice is complete. It uses `moonbitlang/async/fs` to discover and
read `BISECT-COVERAGE-4` files, uses `moonbitlang/x/path` for platform-aware
paths, accumulates repeated source records with saturating `Int64` counters,
and implements the `expect`/`do_not_expect` checks for MoonBit `.mbt` sources.

`report.load_coverage` is the public entry point. The binary decoder and
single-file reader remain private, matching Bisect's `Input` module boundary.
