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

version = "0.1.0"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = [ "coverage", "bisect" ]

preferred_target = "native"

description = "Bisect coverage format decoding and reporting for MoonBit"

import {
  "moonbitlang/async@0.20.4",
  "moonbitlang/x@0.4.48",
}
