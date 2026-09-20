///|
fn parse_send_target(
  value : String,
) -> @coveralls.SendTarget raise ReportCliError {
  match value.to_lower() {
    "coveralls" => Coveralls
    "codecov" => Codecov
    _ => raise UnknownSendTarget(value)
  }
}

///|
async fn coveralls_git(
  matches : @argparse.Matches,
  automatic? : Bool = false,
) -> @coveralls.GitInfo? {
  if automatic || cli_flag(matches, "coveralls-include-git-info") {
    Some(@coveralls.collect_git_info())
  } else {
    None
  }
}

///|
async fn render_coveralls(
  matches : @argparse.Matches,
  coverage : @common.Coverage,
  source_paths : ArrayView[String],
  service_name~ : String,
  service_job_id~ : String,
  service_pull_request~ : String,
  repo_token~ : String,
  git : @coveralls.GitInfo?,
) -> Bytes {
  let reader = @io.MemoryReader() <| writer => {
    @coveralls.output(
      writer~,
      coverage~,
      service_name~,
      service_number=cli_value(matches, "service-number"),
      service_job_id~,
      service_pull_request~,
      repo_token~,
      parallel=cli_flag(matches, "coveralls-parallel"),
      git?,
      source_paths~,
      ignore_missing_files=cli_flag(
        matches,
        "ignore-missing-files",
        default=true,
      ),
    )
  }
  defer reader.close()
  reader.read_all().binary()
}

///|
async fn run_coveralls(
  matches : @argparse.Matches,
  coverage : @common.Coverage,
  source_paths : ArrayView[String],
) -> Unit {
  match cli_optional(matches, "send-to") {
    None => {
      let git = coveralls_git(matches)
      let report = render_coveralls(
        matches,
        coverage,
        source_paths,
        service_name=cli_value(matches, "service-name"),
        service_job_id=cli_value(matches, "service-job-id"),
        service_pull_request=cli_value(matches, "service-pull-request"),
        repo_token=cli_value(matches, "coveralls-token"),
        git,
      )
      write_output(output_path(matches, Coveralls), report)
    }
    Some(value) => {
      let target = parse_send_target(value)
      let metadata = @coveralls.resolve_upload_metadata(
        @env.get_env_vars(),
        target,
        service_name=cli_value(matches, "service-name"),
        service_job_id=cli_value(matches, "service-job-id"),
        service_pull_request=cli_value(matches, "service-pull-request"),
        repo_token=cli_value(matches, "coveralls-token"),
      )
      let git = coveralls_git(matches, automatic=metadata.include_git)
      let report = render_coveralls(
        matches,
        coverage,
        source_paths,
        service_name=metadata.service_name,
        service_job_id=metadata.service_job_id,
        service_pull_request=metadata.service_pull_request,
        repo_token=if target is Coveralls { metadata.repo_token } else { "" },
        git,
      )
      @async.with_task_group(group => {
        let directory = @fs.tmpdir(prefix="moon-cove-upload-")
        group.add_defer(() => @fs.rmdir(directory, recursive=true))
        let path = @path.Path(directory).join(Path("coverage.json")).to_string()
        @fs.write_file(
          path,
          report,
          create_mode=CreateOrTruncate,
          permission=0o600,
        )
        match target {
          Coveralls => @coveralls.upload(target, report_file=path)
          Codecov =>
            @coveralls.upload(
              target,
              report_file=path,
              codecov_token=metadata.repo_token,
            )
        }
      })
    }
  }
}
