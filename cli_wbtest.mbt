///|
let cli_v4_fixture =
  #|TU9PTkNPVkUwMDAwMDAwNISVpr4AAAChAAAAHAAAAG8AAABkoMAJNC9wcml2YXRlL3RtcC9tb29uLWNvdi1maXh0dXJlLk5PRklMRS9wcm9qZWN0L2Nvdi5tYnQvZml4dHVyZS9jb3YkY292K2ZpeHR1cmUvY292sKCgsAQFsCdjb3YubWJ0Q0KwBAJERKCwBAqwBAVETrAEBkZEoLAEDgQDsAQJR0NAQKCgsAQSBAsECECQQKCgsAQWBAuwBBFGUkCQQEA=

///|
test "compiler-style command parses report inputs" {
  let matches = compiler_command().parse(
    argv=[
      "a.trace.source", "b.trace.source", "-t", "run-1.log", "-t", "run-2.log", "-f",
      "cobertura", "-o", "coverage.xml", "-p", "pkg", "-F", "a.mbt", "--source-paths",
      "src,generated", "--absolute-file-paths",
    ],
    env={},
  )
  assert_eq(cli_values(matches, "trace-sources"), [
    "a.trace.source", "b.trace.source",
  ])
  assert_eq(cli_values(matches, "runtime-log"), ["run-1.log", "run-2.log"])
  assert_eq(cli_value(matches, "format"), "cobertura")
  assert_eq(cli_value(matches, "output"), "coverage.xml")
  assert_eq(cli_value(matches, "package"), "pkg")
  assert_eq(cli_value(matches, "file"), "a.mbt")
  assert_true(cli_flag(matches, "absolute-file-paths"))
  assert_true(cli_flag(matches, "ignore-missing-files", default=true))
  let strict = compiler_command().parse(argv=["--no-ignore-missing-files"], env={})
  assert_false(cli_flag(strict, "ignore-missing-files", default=true))
}

///|
test "final command exposes all compiler report formats" {
  assert_true(parse_format("caret") is Caret)
  assert_true(parse_format("simp_caret") is SimplifiedCaret)
  assert_true(parse_format("sorted_summary") is SortedSummary)
  let matches = compiler_command().parse(
    argv=[
      "-f", "sorted_summary", "--send-to", "codecov", "--coveralls-include-git-info",
    ],
    env={},
  )
  assert_eq(cli_value(matches, "send-to"), "codecov")
  assert_true(parse_send_target("coveralls") is Coveralls)
  assert_true(parse_send_target("codecov") is Codecov)
  assert_true(cli_flag(matches, "coveralls-include-git-info"))
  let help = compiler_command().render_help()
  assert_true(help.contains("Usage: moon_cove"))
  for
    format in [
      "bisect", "caret", "simp_caret", "coveralls", "cobertura", "html", "summary",
      "full_summary", "sorted_summary",
    ] {
    assert_true(help.contains(format))
  }
}

///|
async test "CLI writes compiler coverage as Bisect" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-cli-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let path : (String) -> String = name => {
      @path.Path(root).join(Path(name)).to_string()
    }
    @fs.write_file(
      path("cov.trace.source"),
      @base64.decode(cli_v4_fixture),
      create_mode=CreateOrTruncate,
    )
    let source =
      #|///|
      #|pub fn classify(n : Int) -> String {
      #|  if n > 0 {
      #|    "positive"
      #|  } else {
      #|    "non-positive"
      #|  }
      #|}
      #|
    @fs.write_file(
      path("cov.mbt"),
      @utf8.encode(source),
      create_mode=CreateOrTruncate,
    )
    let log =
      #|----- BEGIN MOONBIT COVERAGE -----
      #|{ "fixture/cov$cov": [1, 1, 0] }
      #|----- END MOONBIT COVERAGE -----
      #|
    @fs.write_file(
      path("run.log"),
      @utf8.encode(log),
      create_mode=CreateOrTruncate,
    )
    let output = path("result.coverage")
    let matches = compiler_command().parse(
      argv=[
        path("cov.trace.source"),
        "-t",
        path("run.log"),
        "-o",
        output,
        "--source-paths",
        root,
      ],
      env={},
    )
    run_compiler_report(matches, current_directory=root)
    assert_eq(
      @fs.read_file(output).text(),
      "BISECT-COVERAGE-4 1 7 cov.mbt 3 44 59 85 3 1 1 0",
    )
    // Moon coverage analyze prepends its default format to user arguments.
    for
      i, formats in [
        ["-f=simp_caret", "-f=bisect"],
        ["-f", "simp_caret", "--format", "bisect"],
        ["--format=summary", "-fbisect"],
        ["-f=bisect", "-f=summary", "--format=bisect"],
      ] {
      let output = path("result-\{i}.coverage")
      let argv = [
        path("cov.trace.source"),
        "-t",
        path("run.log"),
        "-o",
        output,
        "--source-paths",
        root,
      ]
      argv.append(formats)
      let matches = compiler_command().parse(argv~, env={})
      run_compiler_report(matches, current_directory=root)
      assert_eq(
        @fs.read_file(output).text(),
        "BISECT-COVERAGE-4 1 7 cov.mbt 3 44 59 85 3 1 1 0",
      )
    }
  })
}
