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

function debug_request_to_string(request : DebugRequest) -> string = {
  match request {
    Resume()                     => "Resume()",
    Halt()                       => "Halt()",
    Reset(halt_on_reset)         => "Reset(haltonreset=" ^ (if halt_on_reset then "true" else "false") ^ ")",
    AbstractCommand(command) => {
      match command {
        AccessRegister(write, regno, aarsize, postexec, transfer) => "RegisterAccess(write=" ^ (if write then "true" else "false") ^
                                                              ", regno=" ^ bits_str(regno) ^
                                                              ", aarsize=" ^ bits_str(aarsize)  ^
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

struct debug_module_hart_status = {
  running  : bool,
  halted   : bool,
  havereset: bool,
}

let MAX_DATA_SIZE : bits(4) = to_bits_truncate(config platform.debug_module.num_data_reg : int )
let MAX_PROGBUF_SIZE : bits(5) = to_bits_truncate(config platform.debug_module.num_prog_reg : int)
