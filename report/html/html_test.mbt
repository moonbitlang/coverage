///|
async test "output writes a complete offline HTML report" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-html-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source_file = @path.Path(root).join(Path("src/a.mbt")).to_string()
    let output_directory = @path.Path(root).join(Path("report")).to_string()
    @fs.mkdir(@path.Path(source_file).dirname().to_string(), recursive=true)
    @fs.write_file(source_file, b"a\n<&\n", create_mode=CreateOrTruncate)
    let coverage : @common.Coverage = Map([
      (
        "src/a.mbt",
        { filename: "src/a.mbt", points: [0L, 2L, 3L], counts: [4L, 1L, 0L] },
      ),
    ])
    @html.output(
      to_directory=output_directory,
      title="moon_cove",
      tab_size=2,
      theme=Auto,
      coverage~,
      source_paths=[root],
      ignore_missing_files=false,
    )
    let index_file = @path.Path(output_directory)
      .join(Path("index.html"))
      .to_string()
    let source_page = @path.Path(output_directory)
      .join(Path("src/a.mbt.html"))
      .to_string()
    let stylesheet = @path.Path(output_directory)
      .join(Path("coverage.css"))
      .to_string()
    let regular_font = @path.Path(output_directory)
      .join(Path("fonts/inria-sans-regular.woff2"))
      .to_string()
    assert_true(@fs.exists(index_file))
    assert_true(@fs.exists(source_page))
    assert_true(@fs.exists(stylesheet))
    assert_true(@fs.exists(regular_font))
    let index = @fs.read_file(index_file).text()
    let source = @fs.read_file(source_page).text()
    assert_true(index.contains("href=\"src/a.mbt.html\""))
    assert_true(index.contains("<strong>66.7%</strong> · 2 / 3 points"))
    assert_true(source.contains("<h1>src/a.mbt</h1>"))
    assert_true(source.contains("data-coverage=\"mixed\""))
    assert_false(index.contains("<script"))
    assert_false(source.contains("<script"))
    assert_eq(@fs.read_file(regular_font).binary().length(), 23876)
  })
}

///|
async test "output writes multiple source files from one directory" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-html-siblings-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source_directory = @path.Path(root).join(Path("src"))
    let first_source = source_directory.join(Path("a.mbt")).to_string()
    let second_source = source_directory.join(Path("b.mbt")).to_string()
    let output_directory = @path.Path(root).join(Path("report")).to_string()
    @fs.mkdir(source_directory.to_string(), recursive=true)
    @fs.write_file(first_source, b"a\n", create_mode=CreateOrTruncate)
    @fs.write_file(second_source, b"b\n", create_mode=CreateOrTruncate)
    let coverage : @common.Coverage = Map([
      ("src/a.mbt", { filename: "src/a.mbt", points: [0L], counts: [1L] }),
      ("src/b.mbt", { filename: "src/b.mbt", points: [0L], counts: [0L] }),
    ])
    @html.output(
      to_directory=output_directory,
      title="siblings",
      tab_size=2,
      theme=Auto,
      coverage~,
      source_paths=[root],
      ignore_missing_files=false,
    )
    assert_true(
      @fs.exists(
        @path.Path(output_directory).join(Path("src/a.mbt.html")).to_string(),
      ),
    )
    assert_true(
      @fs.exists(
        @path.Path(output_directory).join(Path("src/b.mbt.html")).to_string(),
      ),
    )
  })
}
