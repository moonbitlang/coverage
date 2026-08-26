///|
let compiler_v4_fixture =
  #|TU9PTkNPVkUwMDAwMDAwNISVpr4AAAChAAAAHAAAAG8AAABkoMAJNC9wcml2YXRlL3RtcC9tb29uLWNvdi1maXh0dXJlLk5PRklMRS9wcm9qZWN0L2Nvdi5tYnQvZml4dHVyZS9jb3YkY292K2ZpeHR1cmUvY292sKCgsAQFsCdjb3YubWJ0Q0KwBAJERKCwBAqwBAVETrAEBkZEoLAEDgQDsAQJR0NAQKCgsAQSBAsECECQQKCgsAQWBAuwBBFGUkCQQEA=

///|
let compiler_v4_block32_fixture =
  #|TU9PTkNPVkUwMDAwMDAwNISVpr4AAAK/AAAAvAAAAqUAAAKYoMAJOi9wcml2YXRlL3RtcC9tb29uLWNvdi1maXh0dXJlLk5PRklMRS9wcm9qZWN0L21hbnkvbWFueS5tYnQ1Zml4dHVyZS9jb3YvbWFueSRtYW55MGZpeHR1cmUvY292L21hbnkIAABcAKCgsAQFsChtYW55Lm1idENCsAQCQ06gsAQKsAQFQ0+wBAZER6CwBA6wBAlOSbAECk5NQECgoLAEEwQMBAlAkECgoLAEFwQMsAQSRFOgsAQasAQVRFSwBBZFR6CwBB4EELAEGU5NQJBAoKCwBCMEDAQJQJBCoKCwBCcEDLAEIkVToLAEKrAEJUVUsAQmRkegsAQuBCCwBClOTUCQQqCgsAQzBAwECUCQRKCgsAQ3BAywBDJGU6CwBDqwBDVGVLAENkdHoLAEPgQwsAQ5Tk1AkESgoLAEQwQMBAlAkEagoLAERwQMsARCR1OgsARKsARFR1SwBEZIR6CwBE4EQLAESU5NQJBGoKCwBFMEDAQJQJBIoKCwBFcEDLAEUkhToLAEWrAEVUhUsARWSUegsAReBFCwBFlOTUCQSKCgsARjBAwECUCQSqCgsARnBAywBGJJU6CwBGqwBGVJVLAEZkpHoLAEbgRgsARpTk1AkEqgoLAEcwQMBAlAkEygoLAEdwQMsARySlOgsAR6sAR1SlSwBHZLR6CwBH4EcLAEeU5NQJBMoKCwBIMEDAQJQJBOoKCwBIcEDLAEgktToLAEirAEhUtUsASGTEegsASOBICwBIlOTUCQTqCgsASTBAwECUCQUKCgsASXBAywBJJMU6CwBJqwBJVMVLAElk1HoLAEngSQsASZTk1AkFCgoLAEowQMBAlAkFKgoLAEpwQMsASiTVSgsASqsASlTVYEnaCwBK0En7AEqE5NQJBSoKCwBLIECwQIQJBUoKCwBLYEqLAEsU5LQJBUQA==

///|
test "marshal atoms do not occupy shared object slots" {
  assert_true(
    decode_marshaled(@base64.decode("hJWmvgAAAAEAAAAAAAAAAAAAAACA"))
    is Block(0, []),
  )
}

///|
test "decode compiler v4 trace source" {
  guard decode_trace_source(@base64.decode(compiler_v4_fixture)) is [file] else {
    fail("one trace file")
  }
  assert_eq(file.file_id, "fixture/cov$cov")
  assert_eq(file.package_name, "fixture/cov")
  assert_true(file.filename.has_suffix("/cov.mbt"))
  guard file.points is [root, positive, negative] else { fail("three points") }
  assert_eq(root.parent, None)
  assert_eq(root.ranges.length(), 3)
  assert_eq(positive.parent, Some(0))
  let range = positive.ranges[0]
  assert_eq((range.start_line, range.start_column), (4, 4))
  assert_eq((range.end_line, range.end_column), (4, 14))
  assert_eq(negative.parent, Some(0))
}

///|
test "decode compiler v4 block32 point array" {
  guard decode_trace_source(@base64.decode(compiler_v4_block32_fixture))
    is [file] else {
    fail("one trace file")
  }
  assert_eq(file.points.length(), 23)
}
