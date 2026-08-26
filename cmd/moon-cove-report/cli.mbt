///|
priv suberror ReportCliError {
  MissingArgument(String)
  UnknownFormat(String)
} derive(Debug)

///|
priv enum OutputFormat {
  Bisect
  Html
  Coveralls
  Cobertura
  Summary
  FullSummary
}

///|
fn compiler_command() -> @argparse.Command {
  Command(
    "moon-cove-report",
    about="Generate reports from MoonBit compiler coverage data.",
    version="0.2.0",
    flags=[
      FlagArg(
        "ignore-missing-files",
        about="Skip missing source files.",
        negatable=true,
      ),
      FlagArg("absolute-file-paths", about="Keep absolute paths in reports."),
      FlagArg("verbose", about="Print collection diagnostics."),
      FlagArg("coveralls-parallel", about="Mark a parallel Coveralls build."),
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
        default_values=["bisect"],
        about="Report format: bisect, html, coveralls, cobertura, summary, or full_summary.",
      ),
      OptionArg("output", short='o', about="Output file or directory."),
      OptionArg("package", short='p', about="Only include this package."),
      OptionArg("file", short='F', about="Only include this source file."),
      OptionArg(
        "source-paths",
        default_values=["."],
        about="Comma-separated source roots.",
      ),
      OptionArg("service-name", default_values=[""]),
      OptionArg("service-number", default_values=[""]),
      OptionArg("service-job-id", default_values=[""]),
      OptionArg("service-pull-request", default_values=[""]),
      OptionArg("coveralls-token", default_values=[""]),
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
    "html" => Html
    "coveralls" => Coveralls
    "cobertura" => Cobertura
    "summary" => Summary
    "full_summary" => FullSummary
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
    Summary | FullSummary => None
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
  let format = parse_format(cli_value(matches, "format"))
  let source_paths = cli_value(matches, "source-paths")
    .split(",")
    .map(part => part.to_owned())
    .to_array()
  let coverage = @collector.prepare({
    trace_sources: cli_values(matches, "trace-sources"),
    runtime_logs: cli_values(matches, "runtime-log"),
    source_paths,
    package_filter: cli_optional(matches, "package"),
    file_filter: cli_optional(matches, "file"),
    absolute_paths: cli_flag(matches, "absolute-file-paths"),
    current_directory,
  }).to_bisect()
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
    Coveralls => {
      let reader = @io.MemoryReader() <| writer => {
        @coveralls.output(
          writer~,
          coverage~,
          service_name=cli_value(matches, "service-name"),
          service_number=cli_value(matches, "service-number"),
          service_job_id=cli_value(matches, "service-job-id"),
          service_pull_request=cli_value(matches, "service-pull-request"),
          repo_token=cli_value(matches, "coveralls-token"),
          parallel=cli_flag(matches, "coveralls-parallel"),
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
  }
}
