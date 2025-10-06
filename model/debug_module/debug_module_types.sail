/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// Debug module uses same XLEN as the hart
type dxlen : Int = xlen

type log2_dxlen  : Int = if dxlen == 32 then 5 else 6
type dxlen_bytes : Int = if dxlen == 32 then 5 else 6

let log2_dxlen = sizeof(log2_dxlen)
let dxlen_bytes = sizeof(dxlen_bytes)
let dxlen = sizeof(dxlen)
type dxlenbits = bits(dxlen)

type dmreg = bits(8)

// State of the Hart from the Debug Module's point of view
enum DebugHartState = {NON_EXISTENT, UNAVAILABLE, RUNNING, HALTED}

type aamsize = {0, 1, 2, 3}

union DebugRequest = {
  Resume : unit,
  Halt   : unit,
  Reset  : bool,               // Halt on reset
  ExecuteProgramBuffer : bool, // Resume after
  QuickAccess : unit,
  MemoryAccess : (bool, bool, aamsize, xlenbits)  // Virtual (true) or Physical (false) and Write (true) or read (false), Size. Data
}

// TODO Improve formatting
// TODO Define new type AbstractCommand for ProgramBuffer and MemoryAccess
function debug_request_to_string(request : DebugRequest) -> string = {
  match request {
    Resume()                     => "Resume()",
    Halt()                       => "Halt()",
    Reset(halt_on_reset)         => "Reset(haltonreset=" ^ (if halt_on_reset then "true" else "false") ^ ")",
    ExecuteProgramBuffer(resume) => "ExecuteProgramBuffer(resume=" ^ (if resume then "true" else "false") ^ ")",
    QuickAccess()                => "QuickAccess()",
    MemoryAccess(virtual, write, width, addr) => "MemoryAccess(virtual=" ^ (if virtual then "true" else "false") ^
                                              ", write=" ^ (if write then "true" else "false") ^
                                              ", width=" ^ dec_str(width) ^
                                              ", addr="  ^ bits_str(addr) ^ ")"
  }
}

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

struct debug_module_hart_status = {
  running  : bool,
  halted   : bool,
  havereset: bool,
}

let MAX_DATA_SIZE : bits(4) = to_bits_truncate(config platform.debug_module.num_data_reg : int )
let MAX_PROGBUF_SIZE : bits(5) = to_bits_truncate(config platform.debug_module.num_prog_reg : int)
