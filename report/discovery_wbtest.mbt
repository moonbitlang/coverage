///|
async test "non-recursive discovery only returns root coverage files" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-discovery-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let nested = @path.Path(root).join(Path("nested")).to_string()
    @fs.mkdir(nested)
    @fs.write_file(
      @path.Path(root).join(Path("root.coverage")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      @path.Path(root).join(Path("notes.txt")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      @path.Path(nested).join(Path("nested.coverage")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    let files = list_non_recursively(is_coverage_file, root)
    files.sort()
    assert_eq(files, ["root.coverage"])
  })
}

///|
async test "recursive discovery includes nested coverage files" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-recursive-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let root_coverage = @path.Path(root).join(Path("root.coverage")).to_string()
    let nested = @path.Path(root).join(Path("nested")).to_string()
    let nested_coverage = @path.Path(nested)
      .join(Path("nested.coverage"))
      .to_string()
    @fs.mkdir(nested)
    @fs.write_file(root_coverage, b"", create_mode=CreateOrTruncate)
    @fs.write_file(nested_coverage, b"", create_mode=CreateOrTruncate)
    @fs.write_file(
      @path.Path(nested).join(Path("notes.txt")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    let files = list_recursively(is_coverage_file, root)
    files.sort()
    let expected = [root_coverage, nested_coverage]
    expected.sort()
    assert_eq(files, expected)
  })
}

///|
async test "coverage search combines explicit files and search paths" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-search-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let nested = @path.Path(root).join(Path("nested")).to_string()
    let root_coverage = @path.Path(root).join(Path("root.coverage")).to_string()
    let nested_coverage = @path.Path(nested)
      .join(Path("nested.coverage"))
      .to_string()
    @fs.mkdir(nested)
    @fs.write_file(root_coverage, b"", create_mode=CreateOrTruncate)
    @fs.write_file(nested_coverage, b"", create_mode=CreateOrTruncate)
    let files = list_coverage_files(files_on_command_line=["manual.coverage"], coverage_search_paths=[
      root,
    ])
    assert_eq(files[0], "manual.coverage")
    let discovered = files[1:].to_owned()
    discovered.sort()
    let expected = [root_coverage, nested_coverage]
    expected.sort()
    assert_eq(discovered, expected)
  })
}

///|
async test "coverage search rejects an empty result" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-empty-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    try
      list_coverage_files(files_on_command_line=[], coverage_search_paths=[root])
    catch {
      _ => ()
    } noraise {
      _ => fail("expected an empty coverage search to fail")
    }
  })
}

///|
async test "default coverage search uses current target and build directories" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-default-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let target = @path.Path(root).join(Path("target")).to_string()
    let build = @path.Path(root).join(Path("_build")).to_string()
    let target_coverage = @path.Path(target)
      .join(Path("target.coverage"))
      .to_string()
    let build_coverage = @path.Path(build)
      .join(Path("build.coverage"))
      .to_string()
    @fs.mkdir(target)
    @fs.mkdir(build)
    @fs.write_file(
      @path.Path(root).join(Path("root.coverage")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(target_coverage, b"", create_mode=CreateOrTruncate)
    @fs.write_file(build_coverage, b"", create_mode=CreateOrTruncate)
    let files = list_coverage_files(
      files_on_command_line=[],
      coverage_search_paths=[],
      current_directory=root,
      target_directory=Some(target),
    )
    assert_eq(files[0], "root.coverage")
    let discovered = files[1:].to_owned()
    discovered.sort()
    let expected = [target_coverage, build_coverage]
    expected.sort()
    assert_eq(discovered, expected)
  })
}
