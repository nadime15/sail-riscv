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

// The `debug_request` argument to the `try_step` function below
// provides a mechanism to the external harness to control entry and
// exit into Debug Mode.  DR_Halt requests the model to enter Debug
// Mode, while DR_Resume requests the model to exit it.  DR_Halt is
// ignored when the model is already in Debug Mode, and DR_Resume is
// ignored when it is not. DR_None does not request any change to the
// current debug mode.
enum debug_request = {DR_None, DR_Halt, DR_Resume, DR_Reset, DR_HaltOnReset}

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

register debug_module_active_request : bool
register debug_module_request : debug_request = DR_None

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

register platform_reset : bool = false
register hart_reset : bool = false

struct dm_hart_status = {
  running  : bool,
  halted   : bool,
  havereset: bool,
}

// Abstract Command Access Type
enum access_type = {
  READ,
  WRITE,
  NO_TRANSFER
}

type data_count = range(0, 12)
type progbuf_size = range(0, 16)

let MAX_DATA_SIZE : data_count = 12
let MAX_PROGBUF_SIZE : progbuf_size = 16

// TODO: Not used yet
struct debug_data = {
  // TODO: Make this a config option, we can have more data entries (up to 12)
  data : vector(if xlen == 32 then 1 else 2, bits(32)),
}

struct program_buffer = {
  // TODO
  //program : vector(MAX_PROGBUF_SIZE, bits(32)),
  program : vector(16, bits(32)),
}
