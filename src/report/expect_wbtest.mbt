///|
test "strip extensions removes everything from the first basename dot" {
  let expected = @path.Path("lib").join(Path("example")).to_string()
  assert_eq(strip_extensions("lib/example.pp.mbt"), expected)
  assert_eq(strip_extensions("example"), "example")
}

///|
async test "expected directories expand recursively and exclusions subtract files" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-expect-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let sources = @path.Path(root).join(Path("sources")).to_string()
    let nested = @path.Path(sources).join(Path("nested")).to_string()
    let source_a = @path.Path(sources).join(Path("a.mbt")).to_string()
    let source_c = @path.Path(nested).join(Path("c.mbt")).to_string()
    @fs.mkdir(nested, recursive=true)
    @fs.write_file(source_a, b"", create_mode=CreateOrTruncate)
    @fs.write_file(source_c, b"", create_mode=CreateOrTruncate)
    @fs.write_file(
      @path.Path(sources).join(Path("notes.txt")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    let directory = sources + @path.sep.to_string()
    assert_eq(
      filtered_expected_files(expect=[directory], do_not_expect=[source_c]),
      [source_a],
    )
  })
}

///|
async test "expected source matching ignores extensions like Bisect" {
  let present_a = @path.Path("src").join(Path("a.mbt")).to_string()
  let present_b = @path.Path("src").join(Path("b.generated.mbt")).to_string()
  let expected_b = @path.Path("src").join(Path("b.mbt")).to_string()
  assert_expected_sources_are_present(
    [present_a, present_b],
    expect=[present_a, expected_b],
    do_not_expect=[],
  )
}

///|
async test "expected source matching rejects a missing source" {
  let present = @path.Path("src").join(Path("present.mbt")).to_string()
  let missing = @path.Path("src").join(Path("missing.mbt")).to_string()
  try
    assert_expected_sources_are_present([present], expect=[present, missing], do_not_expect=[])
  catch {
    _ => ()
  } noraise {
    _ => fail("expected a missing source to fail")
  }
}
