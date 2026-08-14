///|
async test "load coverage aggregates repeated source files" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-load-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let first = @path.Path(root).join(Path("first.coverage")).to_string()
    let second = @path.Path(root).join(Path("second.coverage")).to_string()
    @fs.write_file(
      first,
      b"BISECT-COVERAGE-4 1 9 src/a.mbt 3 1 2 3 3 9223372036854775806 20 30",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      second,
      b"BISECT-COVERAGE-4 2 9 src/a.mbt 2 7 8 2 2 6 9 src/b.mbt 1 4 1 1",
      create_mode=CreateOrTruncate,
    )
    let coverage = @report.load_coverage(
      coverage_files=[first, second],
      coverage_paths=[],
      expect=[],
      do_not_expect=[],
    )
    assert_eq(coverage.length(), 2)
    assert_eq(coverage["src/a.mbt"].points, [7L, 8L])
    assert_eq(coverage["src/a.mbt"].counts, [@int64.MAX_VALUE, 26L, 30L])
    assert_eq(coverage["src/b.mbt"].counts, [1L])
  })
}
