///|
test "render summarizes project coverage" {
  let coverage : @common.Coverage = Map([])
  coverage["src/a.mbt"] = {
    filename: "src/a.mbt",
    points: [0L, 1L, 2L],
    counts: [1L, 0L, 3L],
  }
  assert_eq(render(coverage, per_file=false), "Coverage: 2/3 (66.67%)\n")
}

///|
test "render lists files in name order with aligned counts" {
  let coverage : @common.Coverage = Map([])
  coverage["b.mbt"] = {
    filename: "b.mbt",
    points: [],
    counts: [1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 0L, 0L],
  }
  coverage["a.mbt"] = { filename: "a.mbt", points: [], counts: [1L, 0L] }
  let expected =
    #| 50.00 %    1/2    a.mbt
    #| 83.33 %   10/12   b.mbt
    #| 78.57 %   11/14   Project coverage
    #|
  assert_eq(render(coverage, per_file=true), expected)
}

///|
test "render treats an empty project as fully covered" {
  let coverage : @common.Coverage = Map([])
  assert_eq(render(coverage, per_file=false), "Coverage: 0/0 (100.00%)\n")
}

///|
test "render uses printf-compatible round-to-even percentages" {
  let coverage : @common.Coverage = Map([])
  coverage["tie.mbt"] = {
    filename: "tie.mbt",
    points: [],
    counts: Array::makei(32, index => if index == 0 { 1L } else { 0L }),
  }
  assert_eq(render(coverage, per_file=false), "Coverage: 1/32 (3.12%)\n")
}
