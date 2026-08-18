///|
priv struct CoberturaLine {
  number : Int
  hits : Int64
}

///|
priv struct CoberturaClass {
  name : String
  stats : (Int, Int)
  lines : Array[CoberturaLine]
}

///|
priv struct CoberturaPackage {
  name : String
  stats : (Int, Int)
  classes : Array[CoberturaClass]
}

///|
priv struct CoberturaReport {
  stats : (Int, Int)
  sources : Array[String]
  packages : Array[CoberturaPackage]
}

///|
fn add_stats(left : (Int, Int), right : (Int, Int)) -> (Int, Int) {
  (left.0 + right.0, left.1 + right.1)
}

///|
fn update_counts(
  counts : (Int, Int),
  line_counts : ArrayView[Int64?],
) -> (Int, Int) {
  line_counts.fold(init=counts, (counts, count) => {
    match count {
      None => counts
      Some(count) if count > 0L => (counts.0 + 1, counts.1 + 1)
      Some(_) => (counts.0, counts.1 + 1)
    }
  })
}

///|
fn line_rate(stats : (Int, Int)) -> String {
  let (visited, total) = stats
  guard total != 0 else { "nan" }
  let denominator = total.to_int64()
  let scaled = visited.to_int64() * 1000000L
  let quotient = scaled / denominator
  let twice_remainder = scaled % denominator * 2L
  let rounded = if twice_remainder > denominator ||
    (twice_remainder == denominator && quotient % 2L != 0L) {
    quotient + 1L
  } else {
    quotient
  }
  let whole = rounded / 1000000L
  let fractional = (rounded % 1000000L).to_string().pad_start(6, '0')
  "\{whole}.\{fractional}"
}

///|
fn CoberturaLine::to_xml(self : CoberturaLine) -> Xml {
  EmptyElement("line", [
    Attribute("number", self.number.to_string()),
    Attribute("hits", self.hits.to_string()),
  ])
}

///|
fn CoberturaClass::to_xml(self : CoberturaClass) -> Xml {
  Element(
    "class",
    [
      Attribute("name", self.name),
      Attribute("filename", self.name),
      Attribute("line-rate", line_rate(self.stats)),
    ],
    [Element("lines", [], self.lines.map(line => line.to_xml()))],
  )
}

///|
fn CoberturaPackage::to_xml(self : CoberturaPackage) -> Xml {
  Element(
    "package",
    [
      Attribute("name", self.name),
      Attribute("line-rate", line_rate(self.stats)),
    ],
    [Element("classes", [], self.classes.map(class_ => class_.to_xml()))],
  )
}

///|
fn CoberturaReport::to_xml(self : CoberturaReport) -> Xml {
  Element(
    "coverage",
    [
      Attribute("lines-valid", self.stats.1.to_string()),
      Attribute("lines-covered", self.stats.0.to_string()),
      Attribute("line-rate", line_rate(self.stats)),
    ],
    [
      Element(
        "sources",
        [],
        self.sources.map(source => Element("source", [], [Text(source)])),
      ),
      Element("packages", [], self.packages.map(package_ => package_.to_xml())),
    ],
  )
}

///|
fn render(report : CoberturaReport) -> String {
  Show::to_string(Fragment([Declaration, report.to_xml()]))
}

///|
async fn build_report(
  coverage : @common.Coverage,
  source_paths : ArrayView[String],
  ignore_missing_files : Bool,
) -> CoberturaReport {
  let classes : Array[CoberturaClass] = []
  let mut global_stats = (0, 0)
  let files = coverage.values().to_array()
  files.sort_by((left, right) => left.filename.compare(right.filename))
  for file in files {
    if @report.find_source_file(
        source_roots=source_paths,
        ignore_missing_files~,
        filename=file.filename,
      )
      is Some(source_file) {
      let source = @fs.read_file(source_file).binary()
      let line_counts = @report.line_counts(
        source,
        points=file.points,
        counts=file.counts,
      )
      let stats = update_counts((0, 0), line_counts)
      global_stats = add_stats(global_stats, stats)
      let lines = line_counts
        .mapi((index, hits) => {
          if hits is Some(hits) {
            Some(CoberturaLine::{ number: index + 1, hits })
          } else {
            None
          }
        })
        .filter_map(line => line)
      classes.push({ name: file.filename, stats, lines })
    }
  }
  {
    stats: global_stats,
    sources: ["."],
    packages: [{ name: ".", stats: global_stats, classes }],
  }
}

///|
/// Read and aggregate Bisect coverage files, resolve their source files, and
/// write a Cobertura-compatible XML report.
pub async fn[W : @io.Writer] output(
  writer~ : W,
  coverage_files~ : ArrayView[String],
  coverage_paths~ : ArrayView[String],
  source_paths~ : ArrayView[String],
  ignore_missing_files~ : Bool,
  expect~ : ArrayView[String],
  do_not_expect~ : ArrayView[String],
) -> Unit {
  let coverage = @report.load_coverage(
    coverage_files~,
    coverage_paths~,
    expect~,
    do_not_expect~,
  )
  let report = build_report(coverage, source_paths, ignore_missing_files)
  writer.write(render(report))
}
