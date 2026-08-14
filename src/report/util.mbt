///|
/// Return the outermost ancestor containing a `dune-workspace` file.
/// TODO: Support moon.mod
async fn find_dune_workspace_root(start? : StringView = ".") -> String? {
  let ancestors = []
  for current = @path.Path(@fs.realpath(start)) {
    ancestors.push(current)
    let parent = current.dirname()
    if parent == current || !parent.is_absolute() {
      break
    } else {
      continue parent
    }
  }
  for ancestor in ancestors.rev() {
    let workspace_file = ancestor.join(Path("dune-workspace")).to_string()
    if @fs.exists(workspace_file) {
      break Some(ancestor.to_string())
    }
  } nobreak {
    None
  }
}
