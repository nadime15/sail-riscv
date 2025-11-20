// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// ============================================================================
// Debug Module Interface
// ============================================================================
// These functions handle external debug requests from the Debug Module (DM)
// and execute abstract commands. The main entry point is
// handle_debug_module_request(), which dispatches to specific handlers based
// on the request type.

function update_debug_module_status(request : DebugRequest, step : bool) -> unit = {
  let (is_reset, halt_on_reset) : (bool, bool) = match request {
    Reset(hor) => (true, hor),
    _          => (false, false),
  };

  let is_halt   = request == Halt();
  let is_resume = request == Resume();

  let status : debug_module_hart_status = struct {
    halted    = is_halt | halt_on_reset | step,
    running   = is_reset & not(halt_on_reset) | is_resume & not(step),
    havereset = is_reset,
  };

  send_hart_status(status);
}


// ----------------------------------------------------------------------------
// Basic Debug Operations
// ----------------------------------------------------------------------------

function handle_debug_resume(request : DebugRequest) -> unit = {
  if debug_mode_active then {
    exit_debug_mode();
    update_debug_module_status(request, false);
  };
}

function handle_debug_halt(request : DebugRequest) -> unit = {
  if not(debug_mode_active) then {
    enter_debug_mode(DBGEntry_HaltReq, zeros(), get_arch_pc());
    update_debug_module_status(request, false);
  };
}

function handle_debug_reset(request : DebugRequest) -> unit = {
  reset();
  match request {
    Reset(halt_on_reset) => if halt_on_reset then enter_debug_mode(DBGEntry_ResetHaltReq, zeros(), get_arch_pc()),
    _ => (),
  };
  update_debug_module_status(request, false);
}

function execute_program_buffer() -> unit = {
  assert(debug_abstract_command_active, "Need to be in debug mode in order to execute program buffer");
  PC = trunc(plat_program_buffer_base);
  nextPC = PC;
  progbuf_active = true;
}

// ----------------------------------------------------------------------------
// Abstract Command Handlers
// ----------------------------------------------------------------------------

function access_csr(write : bool, regno : bits(12)) -> AbstractCommandError = {
  if is_CSR_accessible(regno, Machine, write) & check_CSR_access(regno, write) then {
    if write then {
      match write_CSR(regno, read_arg(ARG0, dxlen)[dxlen - 1 .. 0]) {
        Ok(_)  => CMDERR_NONE,
        Err(_) => CMDERR_EXCEPTION,
      }
    } else {
      write_arg(ARG0, dxlen, read_CSR(regno));
      CMDERR_NONE
    }
  } else {
    CMDERR_EXCEPTION
  }
}

function access_gpr(write : bool, regno : bits(5), width : range(2, 3)) -> AbstractCommandError = {
  // Check for RV32E: only x0-x15 are valid
  if base_E_enabled & unsigned(regno) > 15 then {
    CMDERR_EXCEPTION
  } else {
    let regidx = encdec_reg(regno);
    if write then {
      // width==2 means 32-bit access, on 64-bit systems, only read 32 bits
      let effective_width = if width == 2 & dxlen == 64 then 32 else dxlen;
      X(regidx) = zero_extend(read_arg(ARG0, effective_width))
    } else {
      write_arg(ARG0, dxlen, X(regidx))
    };
    CMDERR_NONE
  }
}

function access_fpr(write : bool, regno : bits(5), width : range(2, 3)) -> AbstractCommandError = {
  // Check if FPU is enabled
  if mstatus[FS] == 0b00 then {
    CMDERR_EXCEPTION
  } else {
    let fregidx = encdec_freg(regno);
    if write then {
      // width==2 means 32-bit accessm on 64-bit FPU, only read 32 bits
      let effective_width = if width == 2 & flen == 64 then 32 else flen;
      F(fregidx) = zero_extend(read_arg(ARG0, effective_width))
    } else {
      write_arg(ARG0, flen, F(fregidx))
    };
    CMDERR_NONE
  }
}

function handle_abstract_register_access(write : bool, regno : bits(16), width: range(2, 3), postexec : bool, transfer : bool) -> unit = {
  start_debug_abstract_command();
  // NOTE: In theory, we should check whether a register access exceeds the specified aarsize value.
  // If it does, the access must fail. The problem is that all CSRs return xlenbits and are
  // zero-extended, so there is no reliable way to distinguish between 32-bit and 64-bit CSRs without
  // additional metadata (e.g., a list tracking register sizes). For now, we allow access to CSRs
  // smaller than aarsize, even though this does not fully comply with the spec.
  let status : AbstractCommandError =
    if transfer then
      match regno {
        // Control Status Registers (0x0000-0x0fff)
        regno if regno <=_u REGNO_CSR_MAX => access_csr(write, regno[11 .. 0]),

        // General Purpose Registers (0x1000-0x101f)
        regno if REGNO_GPR_BASE <=_u regno & regno <=_u REGNO_GPR_MAX => access_gpr(write, regno[4 .. 0], width),

        // Floating Point Registers (0x1020-0x103f)
        regno if REGNO_FPR_BASE <=_u regno & regno <=_u REGNO_FPR_MAX => access_fpr(write, regno[4 .. 0], width),

        _ => CMDERR_EXCEPTION
      }
      else
        CMDERR_NONE;

  if postexec & status == CMDERR_NONE then
    execute_program_buffer()
  else
    end_debug_abstract_command(status);
}

function handle_abstract_quick_access() -> unit = {
  handle_debug_halt(Halt());
  start_debug_abstract_command();
  execute_program_buffer();
}

function handle_abstract_memory_access(virtual : bool, write : bool, width : word_width, addr: xlenbits) -> unit = {
  start_debug_abstract_command();

  assert(width <= dxlen_bytes);

  let vaddr : virtaddr = Virtaddr(addr[dxlen - 1..0]);

  let status : AbstractCommandError =
    if write then {
      let data = read_arg(ARG0, dxlen)[width * 8 - 1 .. 0];
      match vmem_write_addr(vaddr, width, data, Write(Data), false, false, false) {
        Ok(_)  => CMDERR_NONE,
        Err(_) => CMDERR_EXCEPTION,
      }
    } else {
      match vmem_read_addr(vaddr, zeros(), width, Read(Data), false, false, false) {
        Ok(data) => {
          write_arg(ARG0, dxlen, zero_extend(data));
          CMDERR_NONE
        },
        Err(_) => CMDERR_EXCEPTION,
      }
    };

  end_debug_abstract_command(status);
}

// ----------------------------------------------------------------------------
// Debug Request Dispatcher
// ----------------------------------------------------------------------------

// This function only handles external debug requests, there are other ways to enter debug mode, through ebreak etc.
function handle_debug_module_request() -> option(DebugRequest) = {
  if debug_module_active_request then {
    if get_config_print_debug()
    then print_log("Hart received request from debug module: " ^ debug_request_to_string(debug_module_request));

    match debug_module_request {
      Halt()   => handle_debug_halt(debug_module_request),
      Resume() => handle_debug_resume(debug_module_request),
      Reset(_) => handle_debug_reset(debug_module_request),
      AbstractCommand(cmd) => {
        debug_active_command = Some(cmd);
        match cmd {
          AccessRegister(write, regno, width, postexec, transfer) =>
            handle_abstract_register_access(write, regno, width, postexec, transfer),
          QuickAccess() =>
            handle_abstract_quick_access(),
          MemoryAccess(virtual, write, size, addr) =>
            handle_abstract_memory_access(virtual, write, size, addr),
        }
      },
    };

    debug_module_active_request = false;
    Some(debug_module_request)
  } else {
    None()
  }
}

function handle_debug_single_step() -> unit = {
  if in_single_step() & not(debug_mode_active) then {
    if get_config_print_debug() then print_log("Entering debug mode via single step");
    update_debug_module_status(Resume(), true);
    enter_debug_mode(DBGEntry_Step, zeros(), get_arch_pc())
  }
}
