///|
test "saturating add clamps Int64 overflow" {
  assert_eq(saturating_add(20L, 22L), 42L)
  assert_eq(saturating_add(@int64.MAX_VALUE - 1L, 2L), @int64.MAX_VALUE)
  assert_eq(saturating_add(@int64.MIN_VALUE + 1L, -2L), @int64.MIN_VALUE)
  assert_eq(saturating_add(@int64.MAX_VALUE, -1L), @int64.MAX_VALUE - 1L)
}

///|
test "elementwise saturating add preserves the longer suffix" {
  assert_eq(
    elementwise_saturating_add([1L, @int64.MAX_VALUE - 1L, 7L], [2L, 2L]),
    [3L, @int64.MAX_VALUE, 7L],
  )
  assert_eq(elementwise_saturating_add([4L], [5L, 6L]), [9L, 6L])
}
