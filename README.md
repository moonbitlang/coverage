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

Run directly from Mooncakes:

```sh
moonx --target native moonbitlang/moon_cove@latest -f summary
```

Or install the root executable and run `moon_cove` from the target project root:

```sh
moon install moonbitlang/moon_cove@latest
```

With no explicit inputs, `moon_cove` recursively discovers both artifact types:

```sh
moon_cove -f html
moon_cove -f caret
moon_cove -f simp_caret
moon_cove -f summary
moon_cove -f full_summary
moon_cove -f sorted_summary
moon_cove -f cobertura
moon_cove -f coveralls
moon_cove -f bisect
```

File-producing formats default to:

- `bisect.coverage`
- `_coverage/`
- `coveralls.json`
- `cobertura.xml`

Inputs and filters can be explicit:

```sh
moon_cove path/to/package.trace.source \
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
moon_cove -f coveralls \
  --send-to coveralls

moon_cove -f coveralls \
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
