///|
test "source text is escaped and tabs expand before rendering" {
  inspect(
    Show::to_string(
      Fragment(source_line_content(2, b"a<&>\t", offset=0L, points=[])),
    ),
    content="a&lt;&amp;&gt;  ",
  )
}

///|
test "instrumented byte offsets become hit and miss markers" {
  inspect(
    Show::to_string(
      Fragment(
        source_line_content(4, b"<x", offset=10L, points=[(10L, 3L), (11L, 0L)]),
      ),
    ),
    content=(
      #|<span class="coverage-point is-hit" data-count="3" title="Visited 3 times">&lt;</span><span class="coverage-point is-miss" data-count="0" title="Never visited">x</span>
    ),
  )
}

///|
test "instrumented offsets stay byte-based around UTF-8 source" {
  inspect(
    Show::to_string(
      Fragment(
        source_line_content(2, @utf8.encode("中x"), offset=20L, points=[
          (20L, 2L),
          (23L, 0L),
        ]),
      ),
    ),
    content=(
      #|<span class="coverage-point is-hit" data-count="2" title="Visited 2 times">中</span><span class="coverage-point is-miss" data-count="0" title="Never visited">x</span>
    ),
  )
}

///|
test "source page renders line states and file statistics" {
  let file : @common.InstrumentedFile = {
    filename: "report/a.mbt",
    points: [0L, 2L, 3L],
    counts: [4L, 1L, 0L],
  }
  let (page, stats) = render_source_page(
    title="moon_cove",
    theme=Auto,
    tab_size=2,
    report_path="report/a.mbt",
    source=b"a\n<&\nz",
    file~,
  )
  assert_eq(stats, (2, 3))
  assert_true(page.contains("<title>a.mbt — moon_cove coverage</title>"))
  assert_true(page.contains("href=\"../coverage.css\""))
  assert_true(page.contains("<h1>report/a.mbt</h1>"))
  assert_true(page.contains("<strong>66.7%</strong> · 2 / 3 points"))
  assert_true(page.contains("id=\"L1\" data-coverage=\"covered\""))
  assert_true(page.contains("id=\"L2\" data-coverage=\"mixed\""))
  assert_true(page.contains("id=\"L3\" data-coverage=\"neutral\""))
  assert_true(page.contains("title=\"Never visited\">&amp;</span>"))
}

///|
test "missing visit counts are rendered as uncovered points" {
  let (lines, stats) = source_lines(2, b"x", [0L], [])
  assert_eq(stats, (0, 1))
  assert_eq(lines.length(), 1)
  assert_true(lines[0].state == Uncovered)
  assert_true(
    Show::to_string(Fragment(lines[0].content)).contains("data-count=\"0\""),
  )
}
