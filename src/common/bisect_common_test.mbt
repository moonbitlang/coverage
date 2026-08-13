///|
test "instrumented file is a record indexed by filename" {
  let file : @common.InstrumentedFile = {
    filename: "lib/a.mbt",
    points: [3L, 9L],
    counts: [1L, 0L],
  }
  let coverage : @common.Coverage = Map([])
  coverage[file.filename] = file
  assert_eq(coverage["lib/a.mbt"].points, [3L, 9L])
  assert_eq(coverage["lib/a.mbt"].counts, [1L, 0L])
}
