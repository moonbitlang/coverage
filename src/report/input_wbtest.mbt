///|
fn expect_decode_error(input : BytesView) -> Unit raise {
  try decode(input, cwd="/workspace") catch {
    _ => ()
  } noraise {
    _ => fail("expected invalid coverage input")
  }
}

///|
test "decode a Bisect-generated coverage record" {
  let files = decode(
    b"BISECT-COVERAGE-4 1 7 test.ml 6 13 30 45 245 229 212 6 1 0 1 0 0 0",
    cwd="/workspace",
  )
  assert_eq(files.length(), 1)
  let file = files[0]
  assert_eq(file.filename, "test.ml")
  assert_eq(file.points, [13L, 30L, 45L, 245L, 229L, 212L])
  assert_eq(file.counts, [1L, 0L, 1L, 0L, 0L, 0L])
}

///|
test "decode empty coverage" {
  assert_true(decode(b"BISECT-COVERAGE-4 0", cwd="/workspace").is_empty())
}

///|
test "decode makes filenames under cwd relative like Bisect" {
  let files = decode(
    b"BISECT-COVERAGE-4 1 20 /workspace/lib/a.mbt 0 0",
    cwd="/workspace",
  )
  assert_eq(files[0].filename, "lib/a.mbt")
}

///|
test "decode preserves absolute filenames outside cwd" {
  let files = decode(
    b"BISECT-COVERAGE-4 1 16 /other/lib/a.mbt 0 0",
    cwd="/workspace",
  )
  assert_eq(files[0].filename, "/other/lib/a.mbt")
}

///|
test "relative path handling uses path semantics" {
  assert_eq(
    get_relative_path("/workspace/./lib/../lib/a.mbt", "/workspace"),
    "lib/a.mbt",
  )
  assert_eq(
    get_relative_path("/workspace-other/a.mbt", "/workspace"),
    "/workspace-other/a.mbt",
  )
  assert_eq(get_relative_path("lib/./a.mbt", "/workspace"), "lib/./a.mbt")
}

///|
test "decode follows Bisect delimiter handling" {
  expect_decode_error(b"BISECT-COVERAGE-3 0")
  assert_true(decode(b"BISECT-COVERAGE-4\t0", cwd="/workspace").is_empty())
  expect_decode_error(b"BISECT-COVERAGE-4 1\t4 a.ml 0 0")
}

///|
test "decode uses OCaml-style integer syntax" {
  let empty_coverage_inputs = [
    b"BISECT-COVERAGE-4 00", b"BISECT-COVERAGE-4 +0", b"BISECT-COVERAGE-4 -0", b"BISECT-COVERAGE-4 0x0",
    b"BISECT-COVERAGE-4 0_0",
  ]
  empty_coverage_inputs.each(input => {
    assert_true(decode(input, cwd="/workspace").is_empty())
  })
  expect_decode_error(b"BISECT-COVERAGE-4 ")
  expect_decode_error(b"BISECT-COVERAGE-4 -1")
  expect_decode_error(b"BISECT-COVERAGE-4 4611686018427387904")
}

///|
test "decode rejects malformed records" {
  expect_decode_error(b"BISECT-COVERAGE-4 1 4 a.m")
  expect_decode_error(b"BISECT-COVERAGE-4 1 1 \xff 0 0")
}

///|
test "decode accepts trailing bytes like Bisect's reader" {
  assert_true(
    decode(b"BISECT-COVERAGE-4 0 \t\r\n", cwd="/workspace").is_empty(),
  )
  assert_true(decode(b"BISECT-COVERAGE-4 0 X", cwd="/workspace").is_empty())
}

///|
async test "read one coverage file" {
  let path = "_build/read-one.coverage"
  @fs.write_file(
    path,
    b"BISECT-COVERAGE-4 1 5 a.mbt 1 0 1 1",
    create_mode=CreateOrTruncate,
  )
  let files = read(coverage_file=path)
  @fs.remove(path)
  assert_eq(files.length(), 1)
  assert_eq(files[0].filename, "a.mbt")
  assert_eq(files[0].points, [0L])
  assert_eq(files[0].counts, [1L])
}

///|
async test "read propagates filesystem errors" {
  try read(coverage_file="_build/does-not-exist.coverage") catch {
    _ => ()
  } noraise {
    _ => fail("expected a filesystem error")
  }
}
