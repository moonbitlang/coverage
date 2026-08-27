///|
/// Render coverage using the detailed or declaration-grouped caret layout.
///
/// The returned text is deterministic and is never written to stdout.
pub async fn render(
  coverage~ : @common.Coverage,
  style~ : Style,
  source_paths~ : ArrayView[String],
  ignore_missing_files~ : Bool,
) -> String {
  match style {
    Detailed => render_detailed(coverage, source_paths, ignore_missing_files)
    Simplified =>
      render_simplified(coverage, source_paths, ignore_missing_files)
  }
}
