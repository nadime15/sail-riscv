// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

register pending_debug_request : option(DebugRequest) = None()

// Conceptual bits of hart state
// NOTE: In theory, we should have individual bits for each hart.
//register resumeack   : bool = false
register haltonreset : bool = false
