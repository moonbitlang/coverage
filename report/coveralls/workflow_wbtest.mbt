///|
async test "upload execution raises when the process exits nonzero" {
  let calls : Array[(String, Array[String])] = []
  let long_stdout = "response:" + "x".repeat(5000)
  let long_stderr = "failure:" + "y".repeat(5000)
  let runner = CommandRunner((program, args, _extra_env) => {
    calls.push((program, args.copy()))
    { exit_code: 22, stdout: long_stdout, stderr: long_stderr }
  })
  let plan = upload_plan(Coveralls, report_file="coverage.json")
  try execute_upload_with_runner(plan, runner) catch {
    CommandError::NonZeroExit(program~, exit_code~, stdout~, stderr~) as error => {
      assert_eq(program, "curl")
      assert_eq(exit_code, 22)
      assert_true(stdout.contains("response:"))
      assert_true(stderr.contains("failure:"))
      assert_true(stdout.length() <= 4200)
      assert_true(stderr.length() <= 4200)
      let message = "\{error}"
      assert_true(message.contains("curl"))
      assert_true(message.contains("22"))
      assert_true(message.contains("stdout"))
      assert_true(message.contains("stderr"))
    }
    _ => fail("expected a nonzero process error")
  } noraise {
    _ => fail("expected upload execution to raise")
  }
  assert_eq(calls, [
    (
      "curl",
      [
        "-L", "-F", "json_file=@coverage.json", "https://coveralls.io/api/v1/jobs",
        "--fail-with-body",
      ],
    ),
  ])
}

///|
async test "Git metadata is collected with an executable and argument arrays" {
  let calls : Array[(String, Array[String])] = []
  let outputs = [
    "deadbeef\u{0}Author Name\u{0}author@example.test\u{0}Committer Name\u{0}committer@example.test\u{0}subject with \"quotes\"",
    "feature/argv\n",
  ]
  let runner = CommandRunner((program, args, _extra_env) => {
    let index = calls.length()
    calls.push((program, args.copy()))
    { exit_code: 0, stdout: outputs[index], stderr: "" }
  })
  let git = collect_git_info_with_runner(runner)
  assert_eq(git.head.id, "deadbeef")
  assert_eq(git.head.author_name, "Author Name")
  assert_eq(git.head.author_email, "author@example.test")
  assert_eq(git.head.committer_name, "Committer Name")
  assert_eq(git.head.committer_email, "committer@example.test")
  assert_eq(git.head.message, "subject with \"quotes\"")
  assert_eq(git.branch, "feature/argv")
  assert_eq(calls, [
    (
      "git",
      ["log", "-1", "--pretty=format:%H%x00%an%x00%ae%x00%cn%x00%ce%x00%s"],
    ),
    ("git", ["rev-parse", "--abbrev-ref", "HEAD"]),
  ])
}

///|
async test "Codecov upload passes its token only through the child environment" {
  let calls : Array[(String, Array[String], Map[String, String])] = []
  let runner = CommandRunner((program, args, extra_env) => {
    calls.push((program, args.copy(), extra_env.copy()))
    { exit_code: 0, stdout: "uploaded", stderr: "" }
  })
  upload_with_runner(
    Codecov,
    report_file="build output/coverage.json",
    codecov_token="secret-token",
    runner~,
  )
  assert_eq(calls, [
    (
      "codecovcli",
      [
        "upload-process", "--disable-search", "--fail-on-error", "-f", "build output/coverage.json",
      ],
      { "CODECOV_TOKEN": "secret-token" },
    ),
  ])
}

///|
async test "process spawn failures are wrapped with the executable name" {
  let runner = CommandRunner((_program, _args, _extra_env) => {
    fail("missing executable")
  })
  try upload_with_runner(Codecov, report_file="coverage.json", runner~) catch {
    CommandError::SpawnFailed(program~, reason~) as error => {
      assert_eq(program, "codecovcli")
      assert_true(reason.contains("missing executable"))
      assert_true("\{error}".contains("codecovcli"))
    }
    _ => fail("expected a wrapped spawn failure")
  } noraise {
    _ => fail("expected upload to raise")
  }
}
