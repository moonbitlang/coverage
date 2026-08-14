///|
async test "output writes decodable pointwise-merged coverage" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-merge-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let first = @path.Path(root).join(Path("first.coverage")).to_string()
    let second = @path.Path(root).join(Path("second.coverage")).to_string()
    let merged_file = @path.Path(root).join(Path("merged.coverage")).to_string()
    @fs.write_file(
      first,
      b"BISECT-COVERAGE-4 1 5 a.mbt 2 1 2 2 9223372036854775806 4",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      second,
      b"BISECT-COVERAGE-4 2 5 a.mbt 2 7 8 2 20 6 5 b.mbt 1 9 1 11",
      create_mode=CreateOrTruncate,
    )
    @merge.output(to_file=merged_file, coverage_files=[first, second], coverage_paths=[])
    let merged = @report.load_coverage(
      coverage_files=[merged_file],
      coverage_paths=[],
      expect=[],
      do_not_expect=[],
    )
    assert_eq(merged.length(), 2)
    assert_eq(merged["a.mbt"].points, [7L, 8L])
    assert_eq(merged["a.mbt"].counts, [9223372036854775807L, 10L])
    assert_eq(merged["b.mbt"].points, [9L])
    assert_eq(merged["b.mbt"].counts, [11L])
  })
}

///|
async test "output creates missing parent directories" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-merge-parent-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let input_file = @path.Path(root).join(Path("input.coverage")).to_string()
    let merged_file = @path.Path(root)
      .join(Path("nested"))
      .join(Path("reports"))
      .join(Path("merged.coverage"))
      .to_string()
    @fs.write_file(
      input_file,
      b"BISECT-COVERAGE-4 0",
      create_mode=CreateOrTruncate,
    )
    @merge.output(to_file=merged_file, coverage_files=[input_file], coverage_paths=[])
    assert_true(@fs.exists(merged_file))
  })
}
