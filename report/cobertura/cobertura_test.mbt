///|
async test "output emits a Cobertura report with line coverage" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-cobertura-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let source_file = @path.Path(root).join(Path("test.mbt")).to_string()
    @fs.write_file(
      source_file,
      b"x\nx\nx\nx\nx\nx\nx\nx\nx\nx\nx\nx\nx\nx\nx\nx\n",
      create_mode=CreateOrTruncate,
    )
    let coverage : @common.Coverage = Map([
      (
        "test.mbt",
        {
          filename: "test.mbt",
          points: [2L, 8L, 14L, 24L, 26L, 30L],
          counts: [1L, 0L, 1L, 0L, 0L, 0L],
        },
      ),
    ])
    let reader = @io.MemoryReader() <| writer => {
      @cobertura.output(
        writer~,
        coverage~,
        source_paths=[root],
        ignore_missing_files=false,
      )
    }
    defer reader.close()
    inspect(
      reader.read_all().text(),
      content=(
        #|<?xml version="1.0" ?>
        #|<coverage lines-valid="6" lines-covered="2" line-rate="0.333333">
        #|  <sources>
        #|    <source>.</source>
        #|  </sources>
        #|  <packages>
        #|    <package name="." line-rate="0.333333">
        #|      <classes>
        #|        <class name="test.mbt" filename="test.mbt" line-rate="0.333333">
        #|          <lines>
        #|            <line number="2" hits="1"/>
        #|            <line number="5" hits="0"/>
        #|            <line number="8" hits="1"/>
        #|            <line number="13" hits="0"/>
        #|            <line number="14" hits="0"/>
        #|            <line number="16" hits="0"/>
        #|          </lines>
        #|        </class>
        #|      </classes>
        #|    </package>
        #|  </packages>
        #|</coverage>
      ),
    )
  })
}
