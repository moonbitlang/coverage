///|
async test "detailed caret follows the compiler golden output" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-caret-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source_file = @path.Path(root).join(Path("simple.mbt")).to_string()
    let source =
      #|///|
      #|/// Make this
      #|/// file longer
      #|fn main {
      #|  if 1 == 3 {
      #|    println("Hello, World!")
      #|  } else {
      #|    match None {
      #|      Some(_) => println("Hello, World!")
      #|      None => println("Goodbye, World!")
      #|    }
      #|  }
      #|}
      #|
    @fs.write_file(
      source_file,
      @utf8.encode(source),
      create_mode=CreateOrTruncate,
    )
    let coverage : @common.Coverage = Map([
      (
        "simple.mbt",
        { filename: "simple.mbt", points: [59L, 116L], counts: [0L, 0L] },
      ),
    ])
    let actual = @caret.render(
      coverage~,
      style=Detailed,
      source_paths=[root],
      ignore_missing_files=false,
    )
    let expected = "warning: this line has no test coverage\n --> simple.mbt:6\n" +
      "4\tfn main {\n" +
      "5\t  if 1 == 3 {\n" +
      "6\t    println(\"Hello, World!\")\n" +
      " \t    ^^^^^^^^^^^^^^^^^^^^^^^^\n" +
      "7\t  } else {\n" +
      "8\t    match None {\n\n\n" +
      "warning: this line has no test coverage\n --> simple.mbt:9\n" +
      " 7\t  } else {\n" +
      " 8\t    match None {\n" +
      " 9\t      Some(_) => println(\"Hello, World!\")\n" +
      "  \t      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n" +
      "10\t      None => println(\"Goodbye, World!\")\n" +
      "11\t    }\n\n\n"
    assert_eq(actual, expected)
  })
}

///|
async test "simplified caret groups uncovered lines by declaration" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-simp-caret-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source =
      #|///|
      #|/// Make this
      #|/// file longer
      #|fn main {
      #|  if 1 == 3 {
      #|    println("Hello,")
      #|    println("World!")
      #|  } else {
      #|    match None {
      #|      Some(_) => println("Hello, World!")
      #|      None => println("Goodbye, World!")
      #|    }
      #|  }
      #|}
      #|
      #|fn helper {
      #|  println("Never")
      #|}
      #|
    @fs.write_file(
      @path.Path(root).join(Path("simple.mbt")).to_string(),
      @utf8.encode(source),
      create_mode=CreateOrTruncate,
    )
    let coverage : @common.Coverage = Map([
      (
        "simple.mbt",
        {
          filename: "simple.mbt",
          points: [59L, 131L, 239L],
          counts: [0L, 0L, 0L],
        },
      ),
    ])
    let actual = @caret.render(
      coverage~,
      style=Simplified,
      source_paths=[root],
      ignore_missing_files=false,
    )
    let expected = "Total: 3 uncovered line(s) in 1 file(s)\n\n" +
      "3 uncovered line(s) in simple.mbt:\n\n" +
      " 4\tfn main {\n" +
      " 5\t  if 1 == 3 {\n" +
      " 6\t    println(\"Hello,\")\t<-- UNCOVERED\n" +
      " 7\t    println(\"World!\")\n" +
      " 8\t  } else {\n" +
      " 9\t    match None {\n" +
      "10\t      Some(_) => println(\"Hello, World!\")\t<-- UNCOVERED\n" +
      "11\t      None => println(\"Goodbye, World!\")\n" +
      "12\t    }\n" +
      "13\t  }\n" +
      "14\t}\n" +
      "  \t…\n\n" +
      "16\tfn helper {\n" +
      "17\t  println(\"Never\")\t<-- UNCOVERED\n" +
      "18\t}\n" +
      "  \t…\n\n" +
      "Total: 3 uncovered line(s) in 1 file(s)\n"
    assert_eq(actual, expected)

    let fully_covered : @common.Coverage = Map([
      ("simple.mbt", { filename: "simple.mbt", points: [59L], counts: [1L] }),
    ])
    assert_eq(
      @caret.render(
        coverage=fully_covered,
        style=Simplified,
        source_paths=[root],
        ignore_missing_files=false,
      ),
      "All source files are fully covered\n",
    )

    @fs.write_file(
      @path.Path(root).join(Path("broken.mbt")).to_string(),
      b"fn main(\n",
      create_mode=CreateOrTruncate,
    )
    let broken : @common.Coverage = Map([
      ("broken.mbt", { filename: "broken.mbt", points: [0L], counts: [0L] }),
    ])
    try
      @caret.render(
        coverage=broken,
        style=Simplified,
        source_paths=[root],
        ignore_missing_files=false,
      )
    catch {
      Failure::Failure(parse_message) =>
        assert_true(
          parse_message.contains("cannot parse source file 'broken.mbt'"),
        )
      _ => fail("expected a readable parser error")
    } noraise {
      _ => fail("expected parsing to fail")
    }

    @fs.write_file(
      @path.Path(root).join(Path("outside.mbt")).to_string(),
      b"// uncovered\nfn main {}\n",
      create_mode=CreateOrTruncate,
    )
    let outside : @common.Coverage = Map([
      ("outside.mbt", { filename: "outside.mbt", points: [0L], counts: [0L] }),
    ])
    try
      @caret.render(
        coverage=outside,
        style=Simplified,
        source_paths=[root],
        ignore_missing_files=false,
      )
    catch {
      Failure::Failure(outside_message) =>
        assert_true(
          outside_message.contains(
            "uncovered line 1 in 'outside.mbt' is not inside a top-level declaration",
          ),
        )
      _ => fail("expected a readable declaration-range error")
    } noraise {
      _ => fail("expected declaration-range lookup to fail")
    }
  })
}
