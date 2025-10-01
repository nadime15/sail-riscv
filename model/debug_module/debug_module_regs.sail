// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

register debug_hart_state : DebugHartState = RUNNING

// TODO this should be part of the hart or at least debug extension
register debug_physical_access : bool = false

register debug_module_active_request : bool = false
register debug_module_request : DebugRequest = Resume()

// Conceptual bits of hart state
// NOTE: In theory, we should have individual bits for each hart.
register haltrequest : bool = false
register resumeack   : bool = false
register unavail     : bool = false
// Optional
// Halt-On-Request == Resethaltreq
// See: https://github.com/riscv/riscv-debug-spec/issues/1142
register haltonreset  : bool = false
// NOTE: The bit is defined but not discussed anywhere
register hartreset    : bool = false
register keepalive    : bool = false

// Signals from hart to debug module
// Indicates that the hart is running
register running   : bool = true
// Indicates that the hart is halted
register halted    : bool = false
// Indicates that a hart has experienced a reset
register havereset : bool = false
