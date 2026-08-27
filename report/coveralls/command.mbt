///|
priv suberror CommandError {
  SpawnFailed(program~ : String, reason~ : String)
  NonZeroExit(
    program~ : String,
    exit_code~ : Int,
    stdout~ : String,
    stderr~ : String
  )
}

///|
impl Show for CommandError with fn output(self, logger) {
  logger.write_string(
    match self {
      SpawnFailed(program~, reason~) =>
        "failed to start command '\{program}': \{reason}"
      NonZeroExit(program~, exit_code~, stdout~, stderr~) =>
        "command '\{program}' exited with status \{exit_code}; stdout: \{stdout}; stderr: \{stderr}"
    },
  )
}

///|
fn bounded_command_output(value : String) -> String {
  let char_limit = 2048
  if value.length() <= char_limit {
    value
  } else {
    let output = StringBuilder()
    let count = Ref(0)
    for char in value {
      if count.val >= char_limit {
        break
      }
      output.write_char(char)
      count.val = count.val + 1
    }
    output.write_string("\n...[truncated]")
    output.to_string()
  }
}

///|
priv struct CommandResult {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
priv struct CommandRunner(
  async (String, Array[String], Map[String, String]) -> CommandResult
)

///|
async fn CommandRunner::run(
  self : CommandRunner,
  program : String,
  args : Array[String],
  extra_env : Map[String, String],
) -> CommandResult {
  let CommandRunner(run) = self
  run(program, args, extra_env)
}

///|
fn process_runner() -> CommandRunner {
  CommandRunner((program, args, extra_env) => {
    let (exit_code, stdout, stderr) = @process.collect_output(
      program,
      args,
      extra_env~,
    )
    { exit_code, stdout: stdout.text(), stderr: stderr.text() }
  })
}

///|
async fn run_checked(
  runner : CommandRunner,
  program : String,
  args : Array[String],
  extra_env? : Map[String, String] = {},
) -> CommandResult {
  let result = runner.run(program, args, extra_env) catch {
    error if @async.is_being_cancelled() => raise error
    error => raise CommandError::SpawnFailed(program~, reason="\{error}")
  }
  if result.exit_code != 0 {
    raise CommandError::NonZeroExit(
      program~,
      exit_code=result.exit_code,
      stdout=bounded_command_output(result.stdout),
      stderr=bounded_command_output(result.stderr),
    )
  }
  result
}

///|
async fn execute_upload_with_runner(
  plan : UploadPlan,
  runner : CommandRunner,
) -> Unit {
  ignore(run_checked(runner, plan.program, plan.args, extra_env=plan.extra_env))
}

///|
async fn upload_with_runner(
  target : SendTarget,
  report_file~ : String,
  codecov_token? : String = "",
  runner~ : CommandRunner,
) -> Unit {
  execute_upload_with_runner(
    upload_plan(target, report_file~, codecov_token~),
    runner,
  )
}

///|
/// Upload an already-written coverage report.
///
/// For Coveralls, the repository token must already have been written into
/// the JSON report by `output`; `codecov_token` is ignored. For Codecov, a
/// non-blank `codecov_token` is passed only through the child process's
/// `CODECOV_TOKEN` environment variable. It never appears in argv.
pub async fn upload(
  target : SendTarget,
  report_file~ : String,
  codecov_token? : String = "",
) -> Unit {
  upload_with_runner(
    target,
    report_file~,
    codecov_token~,
    runner=process_runner(),
  )
}

///|
async fn git_output(runner : CommandRunner, args : Array[String]) -> String {
  run_checked(runner, "git", args).stdout.trim().to_owned()
}

///|
async fn collect_git_info_with_runner(runner : CommandRunner) -> GitInfo {
  let head_output = run_checked(runner, "git", [
      "log", "-1", "--pretty=format:%H%x00%an%x00%ae%x00%cn%x00%ce%x00%s",
    ]).stdout
  guard head_output
    .trim_end(chars="\r\n")
    .split("\u{0}")
    .map(field => field.to_owned())
    .to_array()
    is [id, author_name, author_email, committer_name, committer_email, message] else {
    fail("invalid NUL-delimited git metadata")
  }
  let branch = git_output(runner, ["rev-parse", "--abbrev-ref", "HEAD"])
  {
    head: {
      id,
      author_name,
      author_email,
      committer_name,
      committer_email,
      message,
    },
    branch,
  }
}

///|
pub async fn collect_git_info() -> GitInfo {
  collect_git_info_with_runner(process_runner())
}
