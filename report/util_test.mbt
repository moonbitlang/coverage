///|
async test "source file lookup searches roots in order" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-source-file-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let first_root = @path.Path(root).join(Path("first")).to_string()
    let second_root = @path.Path(root).join(Path("second")).to_string()
    let filename = "src/a.mbt"
    let first_file = @path.Path(first_root).join(Path(filename)).to_string()
    let second_file = @path.Path(second_root).join(Path(filename)).to_string()
    @fs.mkdir(@path.Path(first_file).dirname().to_string(), recursive=true)
    @fs.mkdir(@path.Path(second_file).dirname().to_string(), recursive=true)
    @fs.write_file(first_file, b"first", create_mode=CreateOrTruncate)
    @fs.write_file(second_file, b"second", create_mode=CreateOrTruncate)
    assert_eq(
      @report.find_source_file(
        source_roots=[first_root, second_root],
        ignore_missing_files=false,
        filename~,
      ),
      Some(first_file),
    )
  })
}

///|
async test "source file lookup rejects a missing source by default" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-missing-source-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    try
      @report.find_source_file(
        source_roots=[root],
        ignore_missing_files=false,
        filename="src/missing.mbt",
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("expected a missing source file to fail")
    }
  })
}

///|
async test "source file lookup can ignore a missing source" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-ignored-source-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    assert_eq(
      @report.find_source_file(
        source_roots=[root],
        ignore_missing_files=true,
        filename="src/missing.mbt",
      ),
      None,
    )
  })
}

///|
async test "source file lookup checks an absolute filename directly" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-absolute-source-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source_file = @path.Path(root).join(Path("src/a.mbt")).to_string()
    @fs.mkdir(@path.Path(source_file).dirname().to_string(), recursive=true)
    @fs.write_file(source_file, b"source", create_mode=CreateOrTruncate)
    assert_eq(
      @report.find_source_file(
        source_roots=[@path.Path(root).join(Path("unused")).to_string()],
        ignore_missing_files=false,
        filename=source_file,
      ),
      Some(source_file),
    )
  })
}

///|
async test "source file lookup checks an explicit relative filename directly" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-relative-source-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source_file = @path.Path(root).join(Path("a.mbt")).to_string()
    @fs.write_file(source_file, b"source", create_mode=CreateOrTruncate)
    let cwd = @path.Path(@fs.realpath("."))
    let relative_source = @path.Path(source_file).relative(base=cwd).to_string()
    assert_true(@fs.exists(relative_source))
    assert_eq(
      @report.find_source_file(
        source_roots=[],
        ignore_missing_files=false,
        filename=relative_source,
      ),
      Some(relative_source),
    )
  })
}
