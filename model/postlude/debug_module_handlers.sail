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

function update_debug_module_status(request: DebugRequest, step : bool) -> unit = {
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
    update_debug_module_status(request, false)
  };
}

function handle_debug_halt(request : DebugRequest) -> unit = {
  if not(debug_mode_active) then {
    enter_debug_mode(DBGEntry_HaltReq, zeros(), get_arch_pc());
    update_debug_module_status(request, false)
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

function handle_abstract_register_access(write : bool, regno : bits(16), width: range(2, 3), postexec : bool, transfer : bool) -> unit = {
  start_debug_abstract_command();
  // NOTE: In theory, we should check whether a register access exceeds the specified aarsize value.
  // If it does, the access must fail. The problem is that all CSRs return xlenbits and are
  // zero-extended, so there is no reliable way to distinguish between 32-bit and 64-bit CSRs without
  // additional metadata (e.g., a list tracking register sizes). For now, we allow access to CSRs
  // smaller than aarsize, even though this does not fully comply with the spec.
  let status : AbstractCommandError = if transfer then {
    let regidx  = encdec_reg(regno[4 .. 0]);
    let fregidx = encdec_freg(regno[4 .. 0]);

    match regno {
      // Control Status Registers (0x0000-0x0fff)
      regno if regno <=_u 0x0fff & is_CSR_accessible(regno[11 .. 0], Machine, true) => {
        if write then {
          match write_CSR(regno[11 .. 0], read_arg(0, dxlen)[dxlen - 1 .. 0]) {
            Ok(_)  => (),
            Err(_) => (),
          }
        } else {
          write_arg(0, dxlen, read_CSR(regno[11 .. 0]))
        };
        CMDERR_NONE
      },

      // General Purpose Registers (0x1000-0x101f)
      regno if 0x1000 <=_u regno & regno <=_u 0x101f & not(base_E_enabled & unsigned(regno[4 .. 0]) > 15) => {
        if write then
          X(regidx) = zero_extend(read_arg(0, if width == 2 & dxlen == 64 then 32 else dxlen))
        else
          write_arg(0, dxlen, X(regidx));
        CMDERR_NONE
      },

      // Floating Point Registers (0x1020-0x103f)
      regno if 0x1020 <=_u regno & regno <=_u 0x103f & mstatus[FS] != 0b00 => {
        if write then
          F(fregidx) = zero_extend(read_arg(0, if width == 2 & flen == 64 then 32 else flen))
        else
          write_arg(0, flen, F(fregidx));
        CMDERR_NONE
      },

      _ => CMDERR_EXCEPTION
    }
  } else {
    CMDERR_NONE
  };

  if postexec & status == CMDERR_NONE then {
    execute_program_buffer();
  } else {
    end_debug_abstract_command(status);
  };
}

function handle_abstract_quick_access(request : DebugRequest) -> unit = {
  handle_debug_halt(Halt());
  start_debug_abstract_command();
  execute_program_buffer();
}

function handle_abstract_memory_access(virtual : bool, write : bool, width : word_width, addr: xlenbits) -> unit = {
  start_debug_abstract_command();
  let vaddr : virtaddr = Virtaddr(addr[dxlen - 1..0]);
  assert(width <= dxlen_bytes);

  let success : bool = if write then {
    let data = read_arg(0, dxlen)[width * 8 - 1 .. 0];
    match vmem_write_addr(vaddr, width, data, Write(Data), false, false, false) {
      Ok(_)  => true,
      Err(_) => false,
    }
  } else {
    match vmem_read_addr(vaddr, zeros(), width, Read(Data), false, false, false) {
      Ok(data) => { write_arg(0, dxlen, zero_extend(data)); true },
      Err(_)   => false,
    }
  };

  end_debug_abstract_command(if not(success) then CMDERR_EXCEPTION else CMDERR_NONE);
}

// ----------------------------------------------------------------------------
// Debug Request Dispatcher
// ----------------------------------------------------------------------------

// This function only handles external requests, there are other ways to enter debug mode, through ebreak etc.
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
            handle_abstract_quick_access(debug_module_request),
          MemoryAccess(virtual, write, size, addr) =>
            handle_abstract_memory_access(virtual, write, size, addr),
        }
      },
    };

    debug_module_active_request = false;
    return Some(debug_module_request);
  } else {
    return None()
  }
}

function handle_debug_single_step() -> unit = {
  if in_single_step() & not(debug_mode_active) then {
    if get_config_print_debug() then
    print_log("Entering debug mode via single step");

    update_debug_module_status(Resume(), true);
    enter_debug_mode(DBGEntry_Step, zeros(), get_arch_pc())
  }
}
