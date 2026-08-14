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

## Todo

- [x] Coveralls report
- [x] HTML export
- [x] CLI support
- [ ] MoonBit workspace
