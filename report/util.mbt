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
    // TODO: Support moon.mod
    let workspace_file = ancestor.join(Path("dune-workspace")).to_string()
    if @fs.exists(workspace_file) {
      break Some(ancestor.to_string())
    }
  } nobreak {
    None
  }
}

///|
/// Mirror OCaml's `Filename.is_implicit` using the active platform's path rules.
fn is_implicit_filename(filename : String) -> Bool {
  guard !@path.Path(filename).is_absolute() else { false }
  let explicit_from_current = filename.has_prefix("./") ||
    (@path.sep == '\\' && filename.has_prefix(".\\"))
  let explicit_from_parent = filename.has_prefix("../") ||
    (@path.sep == '\\' && filename.has_prefix("..\\"))
  let drive_relative = @path.sep == '\\' && filename[:] is [_, ':', ..]
  !explicit_from_current && !explicit_from_parent && !drive_relative
}

///|
/// Find a source file using Bisect's source-root lookup rules.
pub async fn find_source_file(
  source_roots~ : ArrayView[String],
  ignore_missing_files~ : Bool,
  filename~ : String,
) -> String? {
  if is_implicit_filename(filename) {
    for source_root in source_roots {
      let candidate = @path.Path(source_root).join(Path(filename)).to_string()
      if @fs.exists(candidate) {
        return Some(candidate)
      }
    }
  } else if @fs.exists(filename) {
    return Some(filename)
  }
  guard !ignore_missing_files else { None }
  let header = "cannot find source file '\{filename}' in:"
  let roots = source_roots.map(root => "  - \{root}").join("\n")
  let message = if roots.is_empty() { header } else { "\{header}\n\{roots}" }
  fail("\{message}\nHint: consider passing --ignore-missing-files.")
}
