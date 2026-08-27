///|
test "CI metadata is inferred from an environment map and explicit values win" {
  let github = @coveralls.resolve_upload_metadata(
    {
      "GITHUB_ACTIONS": "true",
      "GITHUB_RUN_NUMBER": "88",
      "GITHUB_REF": "refs/pull/17/merge",
      "COVERALLS_REPO_TOKEN": "env-coveralls-token",
    },
    Coveralls,
    service_name="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
  )
  assert_eq(github.service_name, "github")
  assert_eq(github.service_job_id, "88")
  assert_eq(github.service_pull_request, "17")
  assert_eq(github.repo_token, "env-coveralls-token")
  let travis = @coveralls.resolve_upload_metadata(
    {
      "TRAVIS": "true",
      "TRAVIS_JOB_ID": "77",
      "COVERALLS_REPO_TOKEN": "travis-token",
    },
    Coveralls,
    service_name="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
  )
  assert_eq(travis.service_name, "travis-ci")
  assert_eq(travis.service_job_id, "77")
  let gitlab_env = {
    "GITLAB_CI": "true",
    "CI_JOB_ID": "501",
    "CI_MERGE_REQUEST_IID": "23",
    "CODECOV_TOKEN": "env-codecov-token",
  }
  let gitlab = @coveralls.resolve_upload_metadata(
    gitlab_env,
    Codecov,
    service_name="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
  )
  assert_eq(gitlab.service_name, "gitlab-ci")
  assert_eq(gitlab.service_job_id, "501")
  assert_eq(gitlab.service_pull_request, "23")
  assert_eq(gitlab.repo_token, "env-codecov-token")
  let overridden = @coveralls.resolve_upload_metadata(
    gitlab_env,
    Codecov,
    service_name=" explicit ",
    service_job_id=" cli-job ",
    service_pull_request=" cli-pr ",
    repo_token=" cli-token ",
  )
  assert_eq(overridden.service_name, "explicit")
  assert_eq(overridden.service_job_id, "cli-job")
  assert_eq(overridden.service_pull_request, "cli-pr")
  assert_eq(overridden.repo_token, "cli-token")
}

///|
test "metadata resolution rejects unsupported CI without explicit identity" {
  try
    @coveralls.resolve_upload_metadata(
      {},
      Coveralls,
      service_name="",
      service_job_id="",
      service_pull_request="",
      repo_token="token",
    )
  catch {
    UnsupportedCI => ()
    _ => fail("expected UnsupportedCI")
  } noraise {
    _ => fail("expected metadata resolution to raise")
  }
  let explicit = @coveralls.resolve_upload_metadata(
    {},
    Coveralls,
    service_name="manual-ci",
    service_job_id="manual-job",
    service_pull_request="",
    repo_token="token",
  )
  assert_eq(explicit.service_name, "manual-ci")
  assert_eq(explicit.service_job_id, "manual-job")
}

///|
test "metadata resolution reports a missing CI job id" {
  try
    @coveralls.resolve_upload_metadata(
      { "GITHUB_ACTIONS": "true", "COVERALLS_REPO_TOKEN": "token" },
      Coveralls,
      service_name="",
      service_job_id="",
      service_pull_request="",
      repo_token="",
    )
  catch {
    MissingMetadata("service_job_id") => ()
    _ => fail("expected missing service_job_id")
  } noraise {
    _ => fail("expected metadata resolution to raise")
  }
}

///|
test "Coveralls requires a token while Codecov permits tokenless uploads" {
  let env = { "GITHUB_ACTIONS": "true", "GITHUB_RUN_NUMBER": "88" }
  try
    @coveralls.resolve_upload_metadata(
      env,
      Coveralls,
      service_name="",
      service_job_id="",
      service_pull_request="",
      repo_token="",
    )
  catch {
    MissingMetadata("repo_token") => ()
    _ => fail("expected missing Coveralls token")
  } noraise {
    _ => fail("expected Coveralls metadata resolution to raise")
  }
  let codecov = @coveralls.resolve_upload_metadata(
    env,
    Codecov,
    service_name="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
  )
  assert_eq(codecov.repo_token, "")
  assert_eq(codecov.service_pull_request, "")
  let travis = @coveralls.resolve_upload_metadata(
    { "TRAVIS": "true", "TRAVIS_JOB_ID": "77" },
    Coveralls,
    service_name="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
  )
  assert_eq(travis.repo_token, "")
}

///|
test "CircleCI pull request metadata prefers a number and normalizes URLs" {
  let resolve_pr = fn(env : Map[String, String]) raise {
    @coveralls.resolve_upload_metadata(
      env,
      Coveralls,
      service_name="",
      service_job_id="",
      service_pull_request="",
      repo_token="",
    ).service_pull_request
  }
  let base = {
    "CIRCLECI": "true",
    "CIRCLE_BUILD_NUM": "19",
    "COVERALLS_REPO_TOKEN": "token",
  }
  let preferred = base.copy()
  preferred["CIRCLE_PR_NUMBER"] = "42"
  preferred["CIRCLE_PULL_REQUEST"] = "https://github.com/acme/repo/pull/99"
  assert_eq(resolve_pr(preferred), "42")
  let from_url = base.copy()
  from_url["CIRCLE_PULL_REQUEST"] = "https://github.com/acme/repo/pull/99/"
  assert_eq(resolve_pr(from_url), "99")
  let numeric = base.copy()
  numeric["CIRCLE_PULL_REQUEST"] = "17"
  assert_eq(resolve_pr(numeric), "17")
}

///|
test "public upload names its optional token for Codecov only" {
  let coveralls_call : async () -> Unit = () => {
    @coveralls.upload(Coveralls, report_file="coverage.json")
  }
  let codecov_call : async () -> Unit = () => {
    @coveralls.upload(
      Codecov,
      report_file="coverage.json",
      codecov_token="token",
    )
  }
  ignore(coveralls_call)
  ignore(codecov_call)
}
