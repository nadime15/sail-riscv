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
register haltrequest : bool = false
register resumeack   : bool = false
register unavail     : bool = false
register haltonreset : bool = false
register hartreset   : bool = false
register keepalive   : bool = false

// Signals from hart to debug module
// Indicates that the hart is running
register running   : bool = true
// Indicates that the hart is halted
register halted    : bool = false
// Indicates that a hart has experienced a reset
register havereset : bool = false
