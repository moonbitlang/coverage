///|
test "report paths cannot escape the output directory" {
  assert_eq(
    safe_report_path("report/a.mbt"),
    @path.Path("report/a.mbt").normalize().to_string(),
  )
  let escaped = safe_report_path("../a.mbt")
  assert_false(@path.Path(escaped).is_absolute())
  assert_false(escaped == ".." || escaped.has_prefix("../"))
  assert_true(escaped.has_suffix("a.mbt"))
  let absolute = safe_report_path(@path.Path("/tmp/a.mbt").to_string())
  assert_false(@path.Path(absolute).is_absolute())
  assert_true(absolute.has_suffix("a.mbt"))
}

///|
test "report hrefs percent-encode URL-significant filename bytes" {
  assert_eq(report_href("report/a b#c.mbt"), "report/a%20b%23c.mbt")
}
