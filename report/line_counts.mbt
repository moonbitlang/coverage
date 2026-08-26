///|
/// Compute line-oriented coverage from byte-oriented instrumentation points.
pub fn line_counts(
  source : BytesView,
  points~ : ArrayView[Int64],
  counts~ : ArrayView[Int64],
) -> Array[Int64?] {
  let points = points.mapi((index, offset) => (offset, index))
  points.sort_by((left, right) => {
    let offset_order = left.0.compare(right.0)
    if offset_order != 0 {
      offset_order
    } else {
      left.1.compare(right.1)
    }
  })
  let line_ends = []
  for index, byte in source {
    if byte == b'\n' {
      line_ends.push((index + 1).to_int64())
    }
  }
  if !source.is_empty() && source.get(source.length() - 1) != Some(b'\n') {
    line_ends.push(source.length().to_int64())
  }
  let line_counts = []
  let mut point_index = 0
  for line_end in line_ends {
    let mut least = None
    let mut second = None
    while point_index < points.length() && points[point_index].0 < line_end {
      let count = counts.get(points[point_index].1).unwrap_or(0L)
      match least {
        None => least = Some(count)
        Some(first) if count < first => {
          second = least
          least = Some(count)
        }
        Some(_) if second is None || count < second.unwrap() =>
          second = Some(count)
        _ => ()
      }
      point_index += 1
    }
    line_counts.push(
      if least == Some(0L) && second is Some(value) {
        Some(value)
      } else {
        least
      },
    )
  }
  line_counts
}
