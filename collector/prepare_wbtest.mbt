///|
test "prepare compiler coverage and project it to Bisect" {
  let traces = decode_trace_source(@base64.decode(compiler_v4_fixture))
  let log =
    #|----- BEGIN MOONBIT COVERAGE -----
    #|{ "fixture/cov$cov": [1, 0, 0] }
    #|----- END MOONBIT COVERAGE -----
    #|----- BEGIN MOONBIT COVERAGE -----
    #|{ "fixture/cov$cov": [0, 1, 0] }
    #|----- END MOONBIT COVERAGE -----
    #|
  let hits = parse_runtime_log(log)
  guard traces is [trace] else { fail("one trace") }
  let source =
    #|///|
    #|pub fn classify(n : Int) -> String {
    #|  if n > 0 {
    #|    "positive"
    #|  } else {
    #|    "non-positive"
    #|  }
    #|}
    #|
  let prepared = prepare_data(
    [trace, trace],
    hits,
    Map([(trace.filename, @utf8.encode(source))]),
  )
  guard prepared.to_bisect().get(trace.filename) is Some(file) else {
    fail("projected file")
  }
  assert_eq(file.points, [44L, 59L, 85L])
  assert_eq(file.counts, [1L, 1L, 0L])
}

///|
test "reject runtime data unrelated to selected traces" {
  let traces = decode_trace_source(@base64.decode(compiler_v4_fixture))
  try prepare_data(traces, [{ file_id: "other", hits: [] }], Map([])) catch {
    NoMatchingRuntimeData => ()
    _ => fail("unrelated runtime data")
  } noraise {
    _ => fail("expected unrelated runtime data to fail")
  }
}

///|
test "reject mismatched runtime counters" {
  let traces = decode_trace_source(@base64.decode(compiler_v4_fixture))
  guard traces is [trace] else { fail("one trace") }
  try
    prepare_data(
      traces,
      [{ file_id: trace.file_id, hits: [1L] }],
      Map([(trace.filename, b"source")]),
    )
  catch {
    CountMismatch(_, 3, 1) => ()
    _ => fail("count mismatch")
  } noraise {
    _ => fail("expected mismatch")
  }
}

///|
test "reject invalid parent point" {
  let traces = decode_trace_source(@base64.decode(compiler_v4_fixture))
  guard traces is [trace] && trace.points is [root, second, third] else {
    fail("fixture shape")
  }
  let trace = { ..trace, points: [{ ..root, parent: Some(9) }, second, third] }
  let source =
    #|///|
    #|pub fn classify(n : Int) -> String {
    #|  if n > 0 { "positive" } else { "non-positive" }
    #|}
  try
    prepare_data(
      [trace],
      [{ file_id: trace.file_id, hits: [1L, 1L, 0L] }],
      Map([(trace.filename, @utf8.encode(source))]),
    )
  catch {
    InvalidParent(_, 0, 9) => ()
    _ => fail("invalid parent")
  } noraise {
    _ => fail("expected invalid parent")
  }
}
