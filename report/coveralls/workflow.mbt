///|
pub(all) suberror MetadataError {
  UnsupportedCI
  MissingMetadata(String)
}

///|
impl Show for MetadataError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnsupportedCI =>
        "unsupported CI environment; set service_name and service_job_id explicitly"
      MissingMetadata(name) => "missing upload metadata '\{name}'"
    },
  )
}

///|
priv enum CI {
  CircleCI
  Travis
  GitHubActions
  GitLabCI
}

///|
pub(all) enum SendTarget {
  Coveralls
  Codecov
}

///|
pub(all) struct UploadMetadata {
  service_name : String
  service_job_id : String
  service_pull_request : String
  repo_token : String
}

///|
priv struct UploadPlan {
  program : String
  args : Array[String]
  extra_env : Map[String, String]
}

///|
fn non_blank(value : String) -> String? {
  let trimmed = value.trim()
  if trimmed.is_empty() {
    None
  } else {
    Some(trimmed.to_owned())
  }
}

///|
fn env_value(env : Map[String, String], name : String) -> String? {
  match env.get(name) {
    Some(value) => non_blank(value)
    None => None
  }
}

///|
fn detect_ci(env : Map[String, String]) -> CI? {
  if env.get("CIRCLECI") is Some("true") {
    Some(CircleCI)
  } else if env.get("TRAVIS") is Some("true") {
    Some(Travis)
  } else if env.get("GITHUB_ACTIONS") is Some("true") {
    Some(GitHubActions)
  } else if env.get("GITLAB_CI") is Some("true") {
    Some(GitLabCI)
  } else {
    None
  }
}

///|
fn CI::service_name(self : CI) -> String {
  match self {
    CircleCI => "circleci"
    Travis => "travis-ci"
    GitHubActions => "github"
    GitLabCI => "gitlab-ci"
  }
}

///|
fn CI::job_id_variable(self : CI) -> String {
  match self {
    CircleCI => "CIRCLE_BUILD_NUM"
    Travis => "TRAVIS_JOB_ID"
    GitHubActions => "GITHUB_RUN_NUMBER"
    GitLabCI => "CI_JOB_ID"
  }
}

///|
fn CI::coveralls_requires_token(self : CI) -> Bool {
  match self {
    Travis => false
    CircleCI | GitHubActions | GitLabCI => true
  }
}

///|
fn github_pull_request(env : Map[String, String]) -> String? {
  match env_value(env, "PULL_REQUEST_NUMBER") {
    Some(value) => Some(value)
    None =>
      match env_value(env, "GITHUB_REF") {
        Some(value) =>
          match value.split("/").to_array() {
            ["refs", "pull", number, ..] => Some(number.to_owned())
            _ => None
          }
        None => None
      }
  }
}

///|
fn circle_pull_request(env : Map[String, String]) -> String? {
  match env_value(env, "CIRCLE_PR_NUMBER") {
    Some(value) => Some(value)
    None =>
      match env_value(env, "CIRCLE_PULL_REQUEST") {
        Some(value) => {
          let trimmed = value.trim(chars="/")
          if trimmed.is_empty() {
            None
          } else {
            trimmed.split("/").to_array().last().map(part => part.to_owned())
          }
        }
        None => None
      }
  }
}

///|
fn CI::pull_request(self : CI, env : Map[String, String]) -> String? {
  let value = match self {
    CircleCI => circle_pull_request(env)
    Travis => env_value(env, "TRAVIS_PULL_REQUEST")
    GitHubActions => github_pull_request(env)
    GitLabCI => env_value(env, "CI_MERGE_REQUEST_IID")
  }
  match value {
    Some("false") => None
    other => other
  }
}

///|
fn prefer(explicit : String, inferred : String?) -> String {
  match non_blank(explicit) {
    Some(value) => value
    None => inferred.unwrap_or("")
  }
}

///|
pub fn resolve_upload_metadata(
  env : Map[String, String],
  target : SendTarget,
  service_name~ : String,
  service_job_id~ : String,
  service_pull_request~ : String,
  repo_token~ : String,
) -> UploadMetadata raise MetadataError {
  let ci = detect_ci(env)
  if ci is None &&
    (non_blank(service_name) is None || non_blank(service_job_id) is None) {
    raise UnsupportedCI
  }
  let inferred_service_name = ci.map(found => found.service_name())
  let inferred_job_id = ci.bind(found => env_value(env, found.job_id_variable()))
  let inferred_pull_request = ci.bind(found => found.pull_request(env))
  let inferred_token = match target {
    Coveralls => env_value(env, "COVERALLS_REPO_TOKEN")
    Codecov => env_value(env, "CODECOV_TOKEN")
  }
  let service_job_id = prefer(service_job_id, inferred_job_id)
  if service_job_id.is_empty() {
    raise MissingMetadata("service_job_id")
  }
  let repo_token = prefer(repo_token, inferred_token)
  let token_required = target is Coveralls &&
    ci.map_or(true, found => found.coveralls_requires_token())
  if token_required && repo_token.is_empty() {
    raise MissingMetadata("repo_token")
  }
  {
    service_name: prefer(service_name, inferred_service_name),
    service_job_id,
    service_pull_request: prefer(service_pull_request, inferred_pull_request),
    repo_token,
  }
}

///|
fn upload_plan(
  target : SendTarget,
  report_file~ : String,
  codecov_token? : String = "",
) -> UploadPlan {
  match target {
    Coveralls =>
      {
        program: "curl",
        args: [
          "-L",
          "-F",
          "json_file=@" + report_file,
          "https://coveralls.io/api/v1/jobs",
          "--fail-with-body",
        ],
        extra_env: {},
      }
    Codecov =>
      {
        program: "codecovcli",
        args: [
          "upload-process", "--disable-search", "--fail-on-error", "-f", report_file,
        ],
        extra_env: match non_blank(codecov_token) {
          Some(token) => { "CODECOV_TOKEN": token }
          None => {}
        },
      }
  }
}
