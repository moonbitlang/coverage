# moon_cov

MoonBit port of Bisect's coverage-report pipeline. Its source tree follows the
original Bisect split:

```text
src/common/bisect_common.mbt  shared coverage types and format identifier
src/report/input.mbt          report discovery, reading, and aggregation
```

The current slice implements the shared record types plus the internal
`Input.read` equivalent using `moonbitlang/async/fs`. It reads one
`BISECT-COVERAGE-4` file, decodes its source records, and makes absolute source
paths below the current directory relative. Like Bisect, the reader stays
private; `load_coverage` will become the public report interface when discovery
and aggregation are implemented.
