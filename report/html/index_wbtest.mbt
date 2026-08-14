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
      filename: "report/input.mbt",
      report_path: "report/input.mbt",
      href: "report/input.mbt.html",
      stats: (2, 3),
    },
    {
      filename: "report/text/text.mbt",
      report_path: "report/text/text.mbt",
      href: "report/text/text.mbt.html",
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
  assert_true(page.contains(">report/</span>"))
  assert_true(page.contains(">text/</span>"))
  assert_true(page.contains("href=\"report/text/text.mbt.html\""))
  assert_false(page.contains("directory-node"))
  assert_false(page.contains("<script"))
}
