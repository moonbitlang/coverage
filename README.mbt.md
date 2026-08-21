# moon_cov

MoonBit port of Bisect's coverage-report pipeline (working in progress)

## HTML report

Generate Bisect-compatible coverage data, then render the static
report with `moon_cov`:

```sh
moon test --enable-coverage
moon coverage report -f bisect -o moonbit.coverage

moon run --target native cmd/moon-cove-report -- \
  html moonbit.coverage \
  --source-path /path/to/project \
  --title "MoonBit coverage" \
  -o ./_coverage
```

Open `./_coverage/index.html`. The output is self-contained apart from its
local CSS and font assets and does not require JavaScript or a web server.

## Text summary

Write the project summary to stdout, optionally including one row per source
file:

```sh
moon run --target native cmd/moon-cove-report -- \
  summary moonbit.coverage --per-file
```

## Cobertura XML

Generate a line-oriented Cobertura report for CI integrations:

```sh
moon run --target native cmd/moon-cove-report -- \
  cobertura coverage.xml moonbit.coverage \
  --source-path /path/to/project
```

## Todo

- [x] Coveralls report
- [x] HTML export
- [x] Text summary
- [x] Cobertura XML
- [x] CLI support
- [x] Wasm Target
- [ ] MoonBit workspace
