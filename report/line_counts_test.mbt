///|
test "line counts map byte offsets to source lines" {
  assert_eq(
    @report.line_counts(b"first\nsecond\nthird", points=[1L, 8L, 14L], counts=[
      3L, 0L, 2L,
    ]),
    [Some(3L), Some(0L), Some(2L)],
  )
}

///|
test "line counts use the least visited point on a line" {
  assert_eq(
    @report.line_counts(b"line\n", points=[0L, 2L, 4L], counts=[5L, 2L, 7L]),
    [Some(2L)],
  )
}

///|
test "line counts sort instrumentation points by byte offset" {
  assert_eq(
    @report.line_counts(b"first\nsecond\nthird", points=[8L, 1L, 14L], counts=[
      0L, 3L, 2L,
    ]),
    [Some(3L), Some(0L), Some(2L)],
  )
}

///|
test "line counts treat a missing counter as zero" {
  assert_eq(@report.line_counts(b"line\n", points=[1L], counts=[]), [Some(0L)])
}
