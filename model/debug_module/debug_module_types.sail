/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

type dmreg = bits(8)

// State of the Hart from the Debug Module's point of view
enum DebugHartState = {NON_EXISTENT, UNAVAILABLE, RUNNING, HALTED}

register debug_hart_state : DebugHartState = RUNNING

union DebugRequest = {
  Resume : unit,
  Halt   : unit,
  Reset  : bool,               // Halt on reset
  ExecuteProgramBuffer : bool, // Resume after
}

register debug_module_active_request : bool = false
register debug_module_request : DebugRequest = Resume()

enum AbstractCommand = {
  ACCESS_REGISTER,
  QUICK_ACCESS,
  ACCESS_MEMORY
}

mapping abstract_command_type : bits(8) <-> AbstractCommand = {
  0x00 <-> ACCESS_REGISTER,
  0x01 <-> QUICK_ACCESS,
  0x02 <-> ACCESS_MEMORY,
}

enum AbstractCommandError = {
  NONE,
  BUSY,
  NOT_SUPPORTED,
  EXCEPTION,
  HALT_RESUME,
  BUS,
  RESERVED,
  OTHER,
}

mapping abstract_command_error : bits(3) <-> AbstractCommandError = {
  0b000 <-> NONE,
  0b001 <-> BUSY,
  0b010 <-> NOT_SUPPORTED,
  0b011 <-> EXCEPTION,
  0b100 <-> HALT_RESUME,
  0b101 <-> BUS,
  0b110 <-> RESERVED,
  0b111 <-> OTHER
}

mapping abstract_command_error_name : AbstractCommandError <-> string = {
  NONE          <-> "NONE",
  BUSY          <-> "BUSY",
  NOT_SUPPORTED <-> "NOT_SUPPORTED",
  EXCEPTION     <-> "EXCEPTION",
  HALT_RESUME   <-> "HALT_RESUME",
  BUS           <-> "BUS",
  RESERVED      <-> "RESERVED",
  OTHER         <-> "OTHER",
}

// Abstract Command Access Type
enum access_type = {
  READ,
  WRITE,
  NO_TRANSFER
}

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

struct debug_module_hart_status = {
  running  : bool,
  halted   : bool,
  havereset: bool,
}

let MAX_DATA_SIZE : bits(4) = to_bits_truncate(config platform.debug_module.num_data_reg : int )
let MAX_PROGBUF_SIZE : bits(5) = to_bits_truncate(config platform.debug_module.num_prog_reg : int)
