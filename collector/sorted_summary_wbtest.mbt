///|
test "sorted summary keeps informative points and uses deterministic ties" {
  let long_source =
    #|before one
    #|before two
    #|before three
    #|  start here
    #|span one
    #|span two
    #|span three
    #|span four
    #|end here
    #|after one
    #|after two
    #|after three
  let files : Map[String, PreparedFile] = Map([])
  files["z"] = {
    file_id: "z",
    filename: "/resolved/z.mbt",
    package_name: "fixture",
    points: [
      {
        ranges: [
          {
            package_name: "fixture/cov",
            filename: "cov.mbt",
            start_line: 1,
            start_column: 0,
            end_line: 1,
            end_column: 5,
          },
        ],
        parent: None,
        hits: 10L,
      },
      {
        ranges: [
          {
            package_name: "fixture/cov",
            filename: "cov.mbt",
            start_line: 2,
            start_column: 0,
            end_line: 2,
            end_column: 5,
          },
        ],
        parent: Some(0),
        hits: 10L,
      },
      {
        ranges: [
          {
            package_name: "fixture/cov",
            filename: "cov.mbt",
            start_line: 4,
            start_column: 2,
            end_line: 4,
            end_column: 6,
          },
          {
            package_name: "fixture/cov",
            filename: "cov.mbt",
            start_line: 9,
            start_column: 0,
            end_line: 9,
            end_column: 7,
          },
        ],
        parent: Some(1),
        hits: 20L,
      },
    ],
    byte_offsets: [],
    source: @utf8.encode(long_source),
  }
  files["a"] = {
    file_id: "a",
    filename: "/resolved/a.mbt",
    package_name: "fixture",
    points: [
      {
        ranges: [
          {
            package_name: "",
            filename: "a.mbt",
            start_line: 1,
            start_column: 0,
            end_line: 1,
            end_column: 0,
          },
        ],
        parent: None,
        hits: 20L,
      },
    ],
    byte_offsets: [],
    source: b"a",
  }
  let coverage : PreparedCoverage = { files, }
  inspect(
    coverage.sorted_summary(),
    content=(
      #|a.mbt:1:1: 20 hits
      #|* a
      #|  ^
      #|fixture/cov/cov.mbt:4:3: 20 hits
      #|  before one
      #|  before two
      #|  before three
      #|*   start here
      #|    ^...
      #|* span one
      #|* span two
      #|* span three
      #|* // ...
      #|* span four
      #|* end here
      #|  after one
      #|  after two
      #|  after three
      #|fixture/cov/cov.mbt:1:1: 10 hits
      #|* before one
      #|  ^^^^^^
      #|  before two
      #|  before three
      #|    start here
      #|
    ),
  )
  inspect(
    coverage.sorted_summary(limit=1),
    content=(
      #|a.mbt:1:1: 20 hits
      #|* a
      #|  ^
      #|
    ),
  )
}
