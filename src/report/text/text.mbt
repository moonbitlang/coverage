///|
fn percentage(numerator : Int, denominator : Int) -> String {
  guard denominator != 0 else { "100.00" }
  let denominator = denominator.to_int64()
  let scaled = numerator.to_int64() * 10000L
  let quotient = scaled / denominator
  let twice_remainder = scaled % denominator * 2L
  let rounded = if twice_remainder > denominator ||
    (twice_remainder == denominator && quotient % 2L != 0L) {
    quotient + 1L
  } else {
    quotient
  }
  let whole = (rounded / 100L).to_string()
  let fractional = (rounded % 100L).to_string().pad_start(2, '0')
  "\{whole}.\{fractional}"
}

///|
fn render(coverage : @common.Coverage, per_file~ : Bool) -> String {
  let stats = coverage
    .values()
    .map(file => {
      let total = file.counts.length()
      let visited = file.counts.fold(init=0, (visited, count) => {
        if count > 0L {
          visited + 1
        } else {
          visited
        }
      })
      (file.filename, visited, total)
    })
    .to_array()
  let visited_total = stats.fold(init=0, (total, stat) => total + stat.1)
  let overall_total = stats.fold(init=0, (total, stat) => total + stat.2)
  if per_file {
    let digits : (Int) -> Int = number => number.to_string().length()
    let visited_digits = stats.fold(init=digits(visited_total), (width, stat) => {
      @cmp.maximum(width, digits(stat.1))
    })
    let total_digits = stats.fold(init=digits(overall_total), (width, stat) => {
      @cmp.maximum(width, digits(stat.2))
    })
    stats.sort_by((left, right) => left.0.compare(right.0))
    let output = StringBuilder()
    for stat in stats {
      let (name, visited, total) = stat
      let percentage = percentage(visited, total).pad_start(6, ' ')
      let visited = visited.to_string().pad_start(visited_digits, ' ')
      let total = total.to_string().pad_end(total_digits, ' ')
      output.write_string("\{percentage} %   \{visited}/\{total}   \{name}\n")
    }
    let percentage = percentage(visited_total, overall_total).pad_start(6, ' ')
    output.write_string(
      "\{percentage} %   \{visited_total}/\{overall_total}   Project coverage\n",
    )
    output.to_string()
  } else {
    "Coverage: \{visited_total}/\{overall_total} (\{percentage(visited_total, overall_total)}%)\n"
  }
}

///|
/// Read and aggregate Bisect coverage files, then write the text report.
///
/// The writer is explicit so callers choose stdout, a file, or an in-memory
/// destination without changing the report logic.
pub async fn output(
  writer~ : &@io.Writer,
  per_file~ : Bool,
  coverage_files~ : ArrayView[String],
  coverage_paths~ : ArrayView[String],
  expect~ : ArrayView[String],
  do_not_expect~ : ArrayView[String],
) -> Unit {
  let coverage = @report.load_coverage(
    coverage_files~,
    coverage_paths~,
    expect~,
    do_not_expect~,
  )
  writer.write(render(coverage, per_file~))
}
