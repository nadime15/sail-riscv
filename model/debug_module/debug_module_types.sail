//=======================================================================================
//  This Sail RISC-V architecture model, comprising all files and
//  directories except where otherwise noted is subject the BSD
//  two-clause license in the LICENSE file.
//
//  SPDX-License-Identifier: BSD-2-Clause
//=======================================================================================

// Debug module uses same XLEN as the hart
type dxlen : Int = xlen

type log2_dxlen  : Int = if dxlen == 32 then 5 else 6
type dxlen_bytes : Int = if dxlen == 32 then 4 else 8

let log2_dxlen = sizeof(log2_dxlen)
let dxlen_bytes = sizeof(dxlen_bytes)
let dxlen = sizeof(dxlen)
type dxlenbits = bits(dxlen)

type dmreg = bits(8)

// State of the Hart from the Debug Module's point of view
enum DebugHartState = {NON_EXISTENT, UNAVAILABLE, RUNNING, HALTED}

union AbstractCommand = {
  AccessRegister : (bool, bits(16), range(2, 3), bool, bool),
  QuickAccess    : unit,
  MemoryAccess   : (bool, bool, word_width, xlenbits),
}

union DebugRequest = {
  Resume : unit,
  Halt   : unit,
  Reset  : bool, // Halt on reset
  AbstractCommand : AbstractCommand,
}

function debug_request_to_string(request : DebugRequest) -> string = {
  match request {
    Resume()                     => "Resume()",
    Halt()                       => "Halt()",
    Reset(halt_on_reset)         => "Reset(haltonreset=" ^ (if halt_on_reset then "true" else "false") ^ ")",
    AbstractCommand(command) => {
      match command {
        AccessRegister(write, regno, width, postexec, transfer) => "RegisterAccess(write=" ^ (if write then "true" else "false") ^
                                                              ", regno=" ^ bits_str(regno) ^
                                                              ", width=" ^ dec_str(width)  ^
                                                              ", postexec=" ^ (if postexec then "true" else "false") ^
                                                              ", transfer=" ^ (if transfer then "true" else "false") ^ ")",
        QuickAccess() => "QuickAccess()",
        MemoryAccess(virtual, write, width, addr) => "MemoryAccess(virtual=" ^ (if virtual then "true" else "false") ^
                                              ", write=" ^ (if write then "true" else "false") ^
                                              ", width=" ^ dec_str(width) ^
                                              ", addr="  ^ bits_str(addr) ^ ")",
      };
    },
  }
}

enum AbstractCommandType = {
  ACCESS_REGISTER,
  QUICK_ACCESS,
  ACCESS_MEMORY
}

mapping abstract_command_type : int <-> AbstractCommandType = {
  0 <-> ACCESS_REGISTER,
  1 <-> QUICK_ACCESS,
  2 <-> ACCESS_MEMORY,
}

enum AbstractCommandError = {
  CMDERR_NONE,
  CMDERR_BUSY,
  CMDERR_NOT_SUPPORTED,
  CMDERR_EXCEPTION,
  CMDERR_HALT_RESUME,
  CMDERR_BUS,
  CMDERR_RESERVED,
  CMDERR_OTHER,
}

mapping abstract_command_error : bits(3) <-> AbstractCommandError = {
  0b000 <-> CMDERR_NONE,
  0b001 <-> CMDERR_BUSY,
  0b010 <-> CMDERR_NOT_SUPPORTED,
  0b011 <-> CMDERR_EXCEPTION,
  0b100 <-> CMDERR_HALT_RESUME,
  0b101 <-> CMDERR_BUS,
  0b110 <-> CMDERR_RESERVED,
  0b111 <-> CMDERR_OTHER
}

mapping abstract_command_error_name : AbstractCommandError <-> string = {
  CMDERR_NONE          <-> "NONE",
  CMDERR_BUSY          <-> "BUSY",
  CMDERR_NOT_SUPPORTED <-> "NOT_SUPPORTED",
  CMDERR_EXCEPTION     <-> "EXCEPTION",
  CMDERR_HALT_RESUME   <-> "HALT_RESUME",
  CMDERR_BUS           <-> "BUS",
  CMDERR_RESERVED      <-> "RESERVED",
  CMDERR_OTHER         <-> "OTHER",
}

// Register number ranges
let REGNO_CSR_MAX   : bits(16) = 0x0fff
let REGNO_GPR_BASE  : bits(16) = 0x1000
let REGNO_GPR_MAX   : bits(16) = 0x101f
let REGNO_FPR_BASE  : bits(16) = 0x1020
let REGNO_FPR_MAX   : bits(16) = 0x103f

// Abstract command argument indices
let ARG0 : range(0, 2) = 0
let ARG1 : range(0, 2) = 1
let ARG2 : range(0, 2) = 2

let EBREAK_INSTRUCTION : bits(32) = 0x00100073
let C_EBREAK_INSTRUCTION : bits(16) = 0x9002

function abstract_command_error_to_string(error : bits(3)) -> string = abstract_command_error_name(abstract_command_error(error))

struct debug_module_hart_status = {
  running  : bool,
  halted   : bool,
  havereset: bool,
}

let MAX_DATA_SIZE : bits(4) = to_bits_truncate(config platform.debug_module.num_data_reg : int )
let MAX_PROGBUF_SIZE : bits(5) = to_bits_truncate(config platform.debug_module.num_prog_reg : int)

register debug_active_command : option(AbstractCommand) = None()

function debug_uses_virtual_addressing() -> bool = {
  match debug_active_command {
    Some(MemoryAccess(virtual, _, _, _)) => virtual,
    _ => false,
  }
}

register progbuf_active : bool = false
