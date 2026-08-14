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

///|
test "write coverage serializes an empty coverage map" {
  let coverage : @common.Coverage = Map([])
  assert_eq(@common.write_coverage(coverage), b"BISECT-COVERAGE-4 0")
}

///|
test "write coverage serializes one instrumented file" {
  let coverage : @common.Coverage = Map([])
  coverage["a.mbt"] = { filename: "a.mbt", points: [0L, 7L], counts: [1L, 0L] }
  assert_eq(
    @common.write_coverage(coverage),
    b"BISECT-COVERAGE-4 1 5 a.mbt 2 0 7 2 1 0",
  )
}

///|
test "write coverage measures filenames in UTF-8 bytes" {
  let coverage : @common.Coverage = Map([])
  coverage["源.mbt"] = { filename: "源.mbt", points: [], counts: [] }
  assert_eq(
    @common.write_coverage(coverage),
    b"BISECT-COVERAGE-4 1 7 源.mbt 0 0",
  )
}
