# moon_cov

MoonBit implementation of the MoonBit compiler coverage reporter.

It reads compiler-generated `.trace.source` metadata together with
`moonbit_coverage_*` runtime logs. The supported trace schema is
`MOONCOVE00000004`.

## Usage

Generate coverage artifacts in the target project:

```sh
moon test --enable-coverage
```

Then run `moon_cove_report` from that project root. With no explicit inputs it
recursively discovers both artifact types:

```sh
moon_cove_report -f html
moon_cove_report -f caret
moon_cove_report -f simp_caret
moon_cove_report -f summary
moon_cove_report -f full_summary
moon_cove_report -f sorted_summary
moon_cove_report -f cobertura
moon_cove_report -f coveralls
moon_cove_report -f bisect
```

File-producing formats default to:

- `bisect.coverage`
- `_coverage/`
- `coveralls.json`
- `cobertura.xml`

Inputs and filters can be explicit:

```sh
moon_cove_report path/to/package.trace.source \
  -t path/to/moonbit_coverage_1.txt \
  -p username/module/pkg \
  -F source.mbt \
  --source-paths src,generated \
  -f caret
```

Package and file filters use exact or `/suffix` matching.

## Uploads

Coveralls upload uses `curl`; Codecov upload uses the official `codecovcli`
executable. Both must already be available on `PATH`.

```sh
moon_cove_report -f coveralls \
  --send-to coveralls

moon_cove_report -f coveralls \
  --send-to codecov
```

CircleCI, Travis CI, GitHub Actions, and GitLab CI metadata are detected from
the environment. Store tokens in `COVERALLS_REPO_TOKEN` or `CODECOV_TOKEN`
instead of command-line arguments. Explicit `--service-name`,
`--service-job-id`, and `--service-pull-request` values take precedence.
Use `--coveralls-include-git-info` to include commit and branch metadata.

Upload reports are written to a private temporary directory and removed after
the upload attempt. Local `-f coveralls` output is retained normally.

## Development

```sh
moon check --target all --warn-list +73
moon test --target native
moon test --target wasm
moon info
moon fmt
```
