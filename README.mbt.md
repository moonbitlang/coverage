# moon_cov

MoonBit implementation of the MoonBit compiler coverage reporter.

It reads compiler-generated `.trace.source` metadata together with
`moonbit_coverage_*` runtime logs. The current reader supports trace schema
`MOONCOVE00000004`.

## Usage

Run tests with coverage in the target project:

```sh
moon test --enable-coverage
```

When `moon-cove-report` runs from that project root, it discovers both input
types recursively:

```sh
moon-cove-report -f html
moon-cove-report -f summary
moon-cove-report -f cobertura -o cobertura.xml
moon-cove-report -f coveralls -o coveralls.json
moon-cove-report -f bisect -o bisect.coverage
```

Inputs can also be explicit:

```sh
moon-cove-report path/to/package.trace.source \
  -t path/to/moonbit_coverage_1.txt \
  -f html \
  --source-paths /path/to/project
```

Filters use exact or path-suffix matching:

```sh
moon-cove-report -p username/module/pkg -F source.mbt -f summary
```

Supported formats in this stage are `bisect`, `html`, `coveralls`,
`cobertura`, `summary`, and `full_summary`.

## Next stage

- Detailed and grouped caret reports
- Parent-aware hot-point summary
- Coveralls and Codecov upload
- Portable trace schema
