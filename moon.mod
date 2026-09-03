// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "moonbitlang/moon_cove"

version = "0.3.0"

readme = "README.mbt.md"

repository = "https://github.com/moonbitlang/coverage"

license = "Apache-2.0"

keywords = [ "coverage", "bisect" ]

preferred_target = "native"

description = "Coverage report generation from MoonBit compiler artifacts"

import {
  "moonbitlang/async@0.20.4",
  "moonbitlang/lexer@0.3.15",
  "moonbitlang/parser@0.3.19",
  "moonbitlang/x@0.5.1",
}
