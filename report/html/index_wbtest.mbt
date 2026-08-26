///|
test "index page collates files into uniform package nodes" {
  let files : Array[IndexFile] = [
    {
      filename: "common/base.mbt",
      report_path: "common/base.mbt",
      href: "common/base.mbt.html",
      stats: (2, 2),
    },
    {
      filename: "src/summary.mbt",
      report_path: "src/summary.mbt",
      href: "src/summary.mbt.html",
      stats: (2, 3),
    },
    {
      filename: "src/nested/detail.mbt",
      report_path: "src/nested/detail.mbt",
      href: "src/nested/detail.mbt.html",
      stats: (0, 1),
    },
  ]
  let page = render_index_page(title="moon_cove", theme=Auto, files~)
  assert_true(page.contains("<title>moon_cove coverage</title>"))
  assert_true(
    page.contains("<strong>66.7%</strong> · 4 / 6 points · 3 files"),
  )
  assert_eq(page.split("class=\"tree-node package-node\"").length(), 4)
  assert_eq(page.split("class=\"node-title package-title\"").length(), 4)
  assert_true(page.contains(">src/</span>"))
  assert_true(page.contains(">nested/</span>"))
  assert_true(page.contains("href=\"src/nested/detail.mbt.html\""))
  assert_false(page.contains("directory-node"))
  assert_false(page.contains("<script"))
}
