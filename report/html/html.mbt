///|
async fn write_assets(to_directory : String) -> Unit {
  let root = @path.Path(to_directory)
  let fonts = root.join(Path("fonts"))
  @report.mkdirs(fonts.to_string())
  @fs.write_file(
    root.join(Path("coverage.css")).to_string(),
    coverage_css,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    fonts.join(Path("inria-sans-regular.woff2")).to_string(),
    inria_sans_regular,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    fonts.join(Path("inria-sans-700.woff2")).to_string(),
    inria_sans_bold,
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    fonts.join(Path("OFL-1.1.txt")).to_string(),
    inria_sans_license,
    create_mode=CreateOrTruncate,
  )
}

///|
/// Write an offline tree-shaped HTML report from prepared coverage.
pub async fn output(
  to_directory~ : String,
  title~ : String,
  tab_size~ : Int,
  theme~ : Theme,
  coverage~ : @common.Coverage,
  source_paths~ : ArrayView[String],
  ignore_missing_files~ : Bool,
) -> Unit {
  guard tab_size >= 0 else { fail("HTML tab size cannot be negative") }
  @report.mkdirs(to_directory)
  let files = coverage.values().to_array()
  files.sort_by((left, right) => left.filename.compare(right.filename))
  let index_files = []
  for file in files {
    if @report.find_source_file(
        source_roots=source_paths,
        ignore_missing_files~,
        filename=file.filename,
      )
      is Some(source_file) {
      let source = @fs.read_file(source_file).binary()
      let report_path = safe_report_path(file.filename)
      let (page, stats) = render_source_page(
        title~,
        theme~,
        tab_size~,
        report_path~,
        source~,
        file~,
      )
      let html_path = @path.Path(to_directory).join(Path(report_path + ".html"))
      @report.mkdirs(html_path.dirname().to_string())
      @fs.write_file(html_path.to_string(), page, create_mode=CreateOrTruncate)
      index_files.push(IndexFile::{
        filename: file.filename,
        report_path,
        href: report_href(report_path) + ".html",
        stats,
      })
    }
  }
  let index = render_index_page(title~, theme~, files=index_files)
  @fs.write_file(
    @path.Path(to_directory).join(Path("index.html")).to_string(),
    index,
    create_mode=CreateOrTruncate,
  )
  write_assets(to_directory)
}
