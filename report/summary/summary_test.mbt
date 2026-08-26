///|
test "summary and full summary follow compiler output" {
  let coverage : @common.Coverage = Map([
    ("b", { filename: "b.mbt", points: [1L, 2L], counts: [1L, 1L] }),
    ("a", { filename: "a.mbt", points: [1L, 2L], counts: [1L, 0L] }),
  ])
  assert_eq(
    @summary.render(coverage, include_full=false),
    "a.mbt: 1/2\nTotal: 3/4\n",
  )
  assert_eq(
    @summary.render(coverage, include_full=true),
    "a.mbt: 1/2\nb.mbt: 2/2\nTotal: 3/4\n",
  )
}
