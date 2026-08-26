///|
pub fn render(coverage : @common.Coverage, include_full~ : Bool) -> String {
  let files = coverage.values().to_array()
  files.sort_by((left, right) => left.filename.compare(right.filename))
  let output = StringBuilder()
  let mut total = 0
  let mut covered = 0
  for file in files {
    let file_total = file.counts.length()
    let file_covered = file.counts.fold(init=0, (sum, hits) => {
      if hits > 0L {
        sum + 1
      } else {
        sum
      }
    })
    total += file_total
    covered += file_covered
    if include_full || file_covered < file_total {
      output.write_string("\{file.filename}: \{file_covered}/\{file_total}\n")
    }
  }
  output.write_string("Total: \{covered}/\{total}\n")
  output.to_string()
}
