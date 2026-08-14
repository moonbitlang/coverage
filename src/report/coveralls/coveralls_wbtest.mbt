///|
test "coverage JSON preserves null and exact Int64 spelling" {
  assert_eq(coverage_count_json(None).stringify(), "null")
  assert_eq(
    coverage_count_json(Some(@int64.MAX_VALUE)).stringify(),
    "9223372036854775807",
  )
}
