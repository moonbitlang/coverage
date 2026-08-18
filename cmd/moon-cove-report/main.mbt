///|
priv suberror CliError {
  MissingArgument(String)
  MissingSubcommand
  InvalidTabSize(String)
  InvalidTheme(String)
} derive(Debug)

///|
fn coverage_path_option() -> @argparse.OptionArg {
  OptionArg(
    "coverage-path",
    about="Directory searched recursively for .coverage files; repeatable.",
    action=Append,
  )
}

///|
fn source_path_option() -> @argparse.OptionArg {
  OptionArg(
    "source-path",
    about="Root used to resolve source filenames; repeatable.",
    action=Append,
    default_values=["."],
  )
}

///|
fn expect_option() -> @argparse.OptionArg {
  OptionArg(
    "expect",
    about="Source path expected in the report; repeatable.",
    action=Append,
  )
}

///|
fn do_not_expect_option() -> @argparse.OptionArg {
  OptionArg(
    "do-not-expect",
    about="Exclude a source path from --expect; repeatable.",
    action=Append,
  )
}

///|
fn ignore_missing_files_flag() -> @argparse.FlagArg {
  FlagArg(
    "ignore-missing-files",
    about="Skip coverage entries whose source file cannot be found.",
  )
}

///|
fn coverage_files_position() -> @argparse.PositionArg {
  PositionArg(
    "coverage-files",
    about="Optional Bisect .coverage files.",
    num_args=ValueRange(),
  )
}

///|
fn html_command() -> @argparse.Command {
  Command(
    "html",
    about="Generate a local static HTML coverage report.",
    flags=[ignore_missing_files_flag()],
    options=[
      OptionArg("output", short='o', about="Output directory.", default_values=[
        "./_coverage",
      ]),
      OptionArg("title", about="Report title used in HTML pages.", default_values=[
        "Coverage report",
      ]),
      OptionArg("tab-size", about="TAB width used in source pages.", default_values=[
        "2",
      ]),
      OptionArg("theme", about="Color theme: auto, light, or dark.", default_values=[
        "auto",
      ]),
      coverage_path_option(),
      source_path_option(),
      expect_option(),
      do_not_expect_option(),
    ],
    positionals=[coverage_files_position()],
  )
}

///|
fn summary_command() -> @argparse.Command {
  Command(
    "summary",
    about="Write a coverage summary to stdout.",
    flags=[FlagArg("per-file", about="Include coverage per source file.")],
    options=[coverage_path_option(), expect_option(), do_not_expect_option()],
    positionals=[coverage_files_position()],
  )
}

///|
fn cobertura_command() -> @argparse.Command {
  Command(
    "cobertura",
    about="Generate a Cobertura XML report.",
    flags=[ignore_missing_files_flag()],
    options=[
      coverage_path_option(),
      source_path_option(),
      expect_option(),
      do_not_expect_option(),
    ],
    positionals=[
      PositionArg(
        "output",
        about="Output XML file.",
        num_args=@argparse.ValueRange::single(),
      ),
      coverage_files_position(),
    ],
  )
}

///|
fn command() -> @argparse.Command {
  Command(
    "moon-cove-report",
    about="Generate reports from Bisect coverage data.",
    version="0.1.0",
    subcommand_required=true,
    subcommands=[html_command(), summary_command(), cobertura_command()],
  )
}

///|
fn values(matches : @argparse.Matches, name : String) -> Array[String] {
  if matches.values.get(name) is Some(values) {
    values
  } else {
    []
  }
}

///|
fn value(matches : @argparse.Matches, name : String) -> String raise CliError {
  match matches.values.get(name) {
    Some([value, ..]) => value
    _ => raise MissingArgument(name)
  }
}

///|
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get_or_default(name, false)
}

///|
fn parse_tab_size(value : String) -> Int raise CliError {
  let tab_size = @string.parse_int(value) catch {
    _ => raise InvalidTabSize(value)
  }
  if tab_size < 0 {
    raise InvalidTabSize(value)
  } else {
    tab_size
  }
}

///|
fn parse_theme(value : String) -> @html.Theme raise CliError {
  match value {
    "auto" => Auto
    "light" => Light
    "dark" => Dark
    _ => raise InvalidTheme(value)
  }
}

///|
async fn run_html(matches : @argparse.Matches) -> Unit {
  let output = value(matches, "output")
  @html.output(
    to_directory=output,
    title=value(matches, "title"),
    tab_size=parse_tab_size(value(matches, "tab-size")),
    theme=parse_theme(value(matches, "theme")),
    coverage_files=values(matches, "coverage-files"),
    coverage_paths=values(matches, "coverage-path"),
    source_paths=values(matches, "source-path"),
    ignore_missing_files=flag(matches, "ignore-missing-files"),
    expect=values(matches, "expect"),
    do_not_expect=values(matches, "do-not-expect"),
  )
  println("Coverage report written to \{output}/index.html")
}

///|
async fn[W : @io.Writer] run_summary(
  matches : @argparse.Matches,
  writer~ : W,
) -> Unit {
  @text.output(
    writer~,
    per_file=flag(matches, "per-file"),
    coverage_files=values(matches, "coverage-files"),
    coverage_paths=values(matches, "coverage-path"),
    expect=values(matches, "expect"),
    do_not_expect=values(matches, "do-not-expect"),
  )
}

///|
async fn run_cobertura(matches : @argparse.Matches) -> Unit {
  let output = value(matches, "output")
  let reader = @io.MemoryReader() <| writer => {
    @cobertura.output(
      writer~,
      coverage_files=values(matches, "coverage-files"),
      coverage_paths=values(matches, "coverage-path"),
      source_paths=values(matches, "source-path"),
      ignore_missing_files=flag(matches, "ignore-missing-files"),
      expect=values(matches, "expect"),
      do_not_expect=values(matches, "do-not-expect"),
    )
  }
  defer reader.close()
  let report = reader.read_all()
  @report.mkdirs(@path.Path(output).dirname().to_string())
  let file = @fs.open(output, mode=WriteOnly, create_mode=CreateOrTruncate)
  defer file.close()
  file.write(report)
  println("Cobertura report written to \{output}")
}

///|
async fn run() -> Unit {
  let matches = command().parse()
  match matches.subcommand {
    Some(("html", matches)) => run_html(matches)
    Some(("summary", matches)) => run_summary(matches, writer=@stdio.stdout)
    Some(("cobertura", matches)) => run_cobertura(matches)
    _ => raise MissingSubcommand
  }
}

///|
async fn exit_with_error(message : String) -> Unit {
  @stdio.stderr.write("error: \{message}\n")
  @sys.exit(1)
}

///|
async fn main {
  run() catch {
    MissingArgument(name) => exit_with_error("missing argument '\{name}'")
    MissingSubcommand => exit_with_error("missing report command")
    InvalidTabSize(value) => exit_with_error("invalid tab size '\{value}'")
    InvalidTheme(value) => exit_with_error("invalid theme '\{value}'")
    error => raise error
  }
}
