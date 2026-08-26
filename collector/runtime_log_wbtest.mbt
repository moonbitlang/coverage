///|
test "parse all coverage blocks without losing Int64 counts" {
  let log =
    #|ordinary output
    #|----- BEGIN MOONBIT COVERAGE -----
    #|{ "pkg$a": [1, 9007199254740993] }
    #|----- END MOONBIT COVERAGE -----
    #|more output
    #|----- BEGIN MOONBIT COVERAGE -----
    #|{ "pkg$b": [2] }
    #|----- END MOONBIT COVERAGE -----
  guard parse_runtime_log(log) is [first, second] else { fail("two blocks") }
  assert_eq(first.file_id, "pkg$a")
  assert_eq(first.hits, [1L, 9007199254740993L])
  assert_eq(second.file_id, "pkg$b")
  assert_eq(second.hits, [2L])
}
