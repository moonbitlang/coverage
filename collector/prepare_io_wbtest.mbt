///|
async test "prepare discovers and filters compiler artifacts" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-prepare-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let path : (String) -> String = name => {
      @path.Path(root).join(Path(name)).to_string()
    }
    let source =
      #|///|
      #|pub fn classify(n : Int) -> String {
      #|  if n > 0 {
      #|    "positive"
      #|  } else {
      #|    "non-positive"
      #|  }
      #|}
      #|
    @fs.write_file(
      path("cov.mbt"),
      @utf8.encode(source),
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      path("cov.trace.source"),
      @base64.decode(compiler_v4_fixture),
      create_mode=CreateOrTruncate,
    )
    let log =
      #|----- BEGIN MOONBIT COVERAGE -----
      #|{ "fixture/cov$cov": [1, 1, 0] }
      #|----- END MOONBIT COVERAGE -----
      #|
    @fs.write_file(
      path("moonbit_coverage_1.txt"),
      @utf8.encode(log),
      create_mode=CreateOrTruncate,
    )
    let coverage = prepare({
      trace_sources: [],
      runtime_logs: [],
      source_paths: [root],
      package_filter: Some("cov"),
      file_filter: Some("cov.mbt"),
      absolute_paths: false,
      current_directory: root,
    }).to_bisect()
    guard coverage.get("cov.mbt") is Some(file) else { fail("prepared file") }
    assert_eq(file.filename, "cov.mbt")
    assert_eq(file.counts, [1L, 1L, 0L])
  })
}

///|
async test "source resolution prefers a valid path, then its longest suffix" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-source-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let checkout = @path.Path(root).join(Path("checkout"))
    let original = @path.Path(root).join(Path("original/pkg/main.mbt"))
    let nested = checkout.join(Path("pkg/main.mbt"))
    let shadow = checkout.join(Path("main.mbt"))
    @fs.mkdir(original.dirname().to_string(), recursive=true)
    @fs.mkdir(nested.dirname().to_string(), recursive=true)
    for path in [original, nested, shadow] {
      @fs.write_file(path.to_string(), b"", create_mode=CreateOrTruncate)
    }
    assert_eq(
      resolve_source(original.to_string(), [checkout.to_string()]),
      @fs.realpath(original.to_string()),
    )
    let stale = @path.Path(root).join(Path("gone/pkg/main.mbt")).to_string()
    assert_eq(
      resolve_source(stale, [checkout.to_string()]),
      @fs.realpath(nested.to_string()),
    )
  })
}
