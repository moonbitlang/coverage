///|
/// Merge coverage files by summing their counters pointwise, then write one
/// Bisect-compatible coverage file.
pub async fn output(
  to_file~ : String,
  coverage_files~ : ArrayView[String],
  coverage_paths~ : ArrayView[String],
) -> Unit {
  let coverage = @report.load_coverage(
    coverage_files~,
    coverage_paths~,
    expect=[],
    do_not_expect=[],
  )
  let parent = @path.Path(to_file).dirname().to_string()
  if !@fs.exists(parent) {
    @fs.mkdir(parent, permission=0o755, recursive=true)
  }
  @fs.write_file(
    to_file,
    @common.write_coverage(coverage),
    create_mode=CreateOrTruncate,
  )
}
