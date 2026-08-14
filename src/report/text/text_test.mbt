///|
async test "output reads coverage files and writes text" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-text-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let coverage_file = @path.Path(root).join(Path("text.coverage")).to_string()
    @fs.write_file(
      coverage_file,
      b"BISECT-COVERAGE-4 1 5 a.mbt 2 0 1 2 1 0",
      create_mode=CreateOrTruncate,
    )
    let reader = @io.MemoryReader() <| writer => {
      @text.output(
        writer~,
        per_file=false,
        coverage_files=[coverage_file],
        coverage_paths=[],
        expect=[],
        do_not_expect=[],
      )
    }
    defer reader.close()
    assert_eq(reader.read_all().text(), "Coverage: 1/2 (50.00%)\n")
  })
}
