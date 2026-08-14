///|
async test "dune workspace discovery returns the outermost workspace" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-workspace-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let inner = @path.Path(root).join(Path("inner")).to_string()
    let nested = @path.Path(inner).join(Path("nested")).to_string()
    @fs.mkdir(nested, recursive=true)
    @fs.write_file(
      @path.Path(root).join(Path("dune-workspace")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      @path.Path(inner).join(Path("dune-workspace")).to_string(),
      b"",
      create_mode=CreateOrTruncate,
    )
    assert_eq(find_dune_workspace_root(start=nested), Some(@fs.realpath(root)))
  })
}
