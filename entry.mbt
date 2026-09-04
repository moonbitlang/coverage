///|
async fn exit_with_error(message : String) -> Unit {
  @stdio.stderr.write("error: \{message}\n")
  @sys.exit(1)
}

///|
async fn main {
  run_compiler_report(compiler_command().parse()) catch {
    MissingArgument(name) => exit_with_error("missing argument '\{name}'")
    UnknownFormat(format) =>
      exit_with_error("unknown output format '\{format}'")
    UnknownSendTarget(target) =>
      exit_with_error("unknown upload target '\{target}'")
    error => exit_with_error("\{error}")
  }
}
