// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// model context for synchronous exceptions, parameterized for extensions

struct sync_exception = {
  trap    : ExceptionType,
  excinfo : option(xlenbits),
  ext     : option(ext_exception)   // for extensions
}

struct Exception_Context = {
  trap           : ExceptionType,
  excinfo_is_gva : bool,
  excinfo        : xlenbits,
  excinfo2       : option(xlenbits),
  excinst        : option(xlenbits),
  ext            : option(ext_exception)
}

// TODO: Build another wrapper without tval2, is_gstage, most of the exceptions dont use tval2, only the one issues by the hypervisor actually, which can be quite rare...
function exception_context(e : ExceptionType, gva : xlenbits) -> Exception_Context = {
  struct {
    trap           = e,
    excinfo_is_gva = false,
    excinfo        = gva,
    excinfo2       = None(),
    excinst        = None(),
    ext            = None()
  }
}

// TODO: Build another wrapper without tval2, is_gstage, most of the exceptions dont use tval2, only the one issues by the hypervisor actually, which can be quite rare...
function exception_context(e : ExceptionType, gva : xlenbits) -> Exception_Context = {
  struct {
    trap = e,
    tval = gva,
    tval2 = zeros(),
    is_gstage_fault = false,
  }
}
