///|
priv suberror ReportCliError {
  MissingArgument(String)
  UnknownFormat(String)
  UnknownSendTarget(String)
} derive(Debug)

///|
priv enum OutputFormat {
  Bisect
  SimplifiedCaret
  Caret
  Html
  Coveralls
  Cobertura
  Summary
  FullSummary
  SortedSummary
}

///|
fn compiler_command() -> @argparse.Command {
  Command(
    "moon_cove",
    about="Generate reports from MoonBit compiler coverage data.",
    version="0.3.3",
    flags=[
      FlagArg(
        "ignore-missing-files",
        about="Skip missing source files.",
        negatable=true,
      ),
      FlagArg("absolute-file-paths", about="Keep absolute paths in reports."),
      FlagArg("verbose", about="Print collection diagnostics."),
      FlagArg("coveralls-parallel", about="Mark a parallel Coveralls build."),
      FlagArg(
        "coveralls-include-git-info",
        about="Include Git metadata in Coveralls output.",
      ),
    ],
    options=[
      OptionArg(
        "runtime-log",
        short='t',
        action=Append,
        about="Coverage runtime log.",
      ),
      OptionArg(
        "format",
        short='f',
        action=Append,
        default_values=["bisect"],
        about="Report format: bisect, caret, simp_caret, coveralls, cobertura, html, summary, full_summary, or sorted_summary.",
      ),
      OptionArg("output", short='o', about="Output file or directory."),
      OptionArg("package", short='p', about="Only include this package."),
      OptionArg("file", short='F', about="Only include this source file."),
      OptionArg(
        "source-paths",
        default_values=["."],
        about="Comma-separated source roots.",
      ),
      OptionArg(
        "service-name",
        default_values=[""],
        about="Service name for Coveralls metadata.",
      ),
      OptionArg(
        "service-number",
        default_values=[""],
        about="Build number for Coveralls metadata.",
      ),
      OptionArg(
        "service-job-id",
        default_values=[""],
        about="CI job identifier for uploads.",
      ),
      OptionArg(
        "service-pull-request",
        default_values=[""],
        about="Pull request number for uploads.",
      ),
      OptionArg(
        "coveralls-token",
        default_values=[""],
        about="Coveralls or Codecov upload token.",
      ),
      OptionArg(
        "send-to",
        about="Upload the coveralls report to coveralls or codecov.",
      ),
    ],
    positionals=[
      PositionArg(
        "trace-sources",
        num_args=ValueRange(),
        about=".trace.source files",
      ),
    ],
  )
}

///|
fn cli_values(matches : @argparse.Matches, name : String) -> Array[String] {
  matches.values.get(name).unwrap_or([])
}

///|
fn cli_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise ReportCliError {
  guard cli_values(matches, name) is [value, ..] else {
    raise MissingArgument(name)
  }
  value
}

///|
fn cli_optional(matches : @argparse.Matches, name : String) -> String? {
  cli_values(matches, name).get(0)
}

///|
fn cli_flag(
  matches : @argparse.Matches,
  name : String,
  default? : Bool = false,
) -> Bool {
  matches.flags.get(name).unwrap_or(default)
}

///|
fn parse_format(value : String) -> OutputFormat raise ReportCliError {
  match value.to_lower() {
    "bisect" => Bisect
    "simp_caret" => SimplifiedCaret
    "caret" => Caret
    "html" => Html
    "coveralls" => Coveralls
    "cobertura" => Cobertura
    "summary" => Summary
    "full_summary" => FullSummary
    "sorted_summary" => SortedSummary
    _ => raise UnknownFormat(value)
  }
}

///|
fn default_output(format : OutputFormat) -> String? {
  match format {
    Bisect => Some("bisect.coverage")
    Html => Some("_coverage")
    Coveralls => Some("coveralls.json")
    Cobertura => Some("cobertura.xml")
    SimplifiedCaret | Caret | Summary | FullSummary | SortedSummary => None
  }
}

///|
async fn write_output(path : String, data : &@io.Data) -> Unit {
  @report.mkdirs(@path.Path(path).dirname().to_string())
  @fs.write_file(path, data, create_mode=CreateOrTruncate)
}

///|
fn output_path(
  matches : @argparse.Matches,
  format : OutputFormat,
) -> String raise ReportCliError {
  match cli_optional(matches, "output") {
    Some(path) => path
    None => default_output(format).unwrap_or_error(MissingArgument("output"))
  }
}

///|
async fn run_compiler_report(
  matches : @argparse.Matches,
  current_directory? : String = ".",
) -> Unit {
  // Preserve the legacy reporter's last-format-wins behavior.
  guard cli_values(matches, "format") is [.., value] else {
    raise MissingArgument("format")
  }
  let format = parse_format(value)
  let source_paths = cli_value(matches, "source-paths")
    .split(",")
    .map(part => part.to_owned())
    .to_array()
  let prepared = @collector.prepare({
    trace_sources: cli_values(matches, "trace-sources"),
    runtime_logs: cli_values(matches, "runtime-log"),
    source_paths,
    package_filter: cli_optional(matches, "package"),
    file_filter: cli_optional(matches, "file"),
    absolute_paths: cli_flag(matches, "absolute-file-paths"),
    current_directory,
  })
  let coverage = prepared.to_bisect()
  if cli_flag(matches, "verbose") {
    @stdio.stderr.write("Collected \{coverage.length()} source file(s)\n")
  }
  match format {
    Bisect =>
      write_output(
        output_path(matches, format),
        @common.write_coverage(coverage),
      )
    Html =>
      @html.output(
        to_directory=output_path(matches, format),
        title="",
        tab_size=2,
        theme=Auto,
        coverage~,
        source_paths~,
        ignore_missing_files=cli_flag(
          matches,
          "ignore-missing-files",
          default=true,
        ),
      )
    SimplifiedCaret =>
      @stdio.stdout.write(
        @caret.render(
          coverage~,
          style=Simplified,
          source_paths~,
          ignore_missing_files=cli_flag(
            matches,
            "ignore-missing-files",
            default=true,
          ),
        ),
      )
    Caret =>
      @stdio.stdout.write(
        @caret.render(
          coverage~,
          style=Detailed,
          source_paths~,
          ignore_missing_files=cli_flag(
            matches,
            "ignore-missing-files",
            default=true,
          ),
        ),
      )
    Coveralls => run_coveralls(matches, coverage, source_paths)
    Cobertura => {
      let reader = @io.MemoryReader() <| writer => {
        @cobertura.output(
          writer~,
          coverage~,
          source_paths~,
          ignore_missing_files=cli_flag(
            matches,
            "ignore-missing-files",
            default=true,
          ),
        )
      }
      defer reader.close()
      write_output(output_path(matches, format), reader.read_all())
    }
    Summary =>
      @stdio.stdout.write(@summary.render(coverage, include_full=false))
    FullSummary =>
      @stdio.stdout.write(@summary.render(coverage, include_full=true))
    SortedSummary => @stdio.stdout.write(prepared.sorted_summary())
  }
}
