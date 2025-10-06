// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// The emulator fetch-execute-interrupt dispatch loop.

union Step = {
  Step_Pending_Interrupt  : (InterruptType, Privilege),
  Step_Ext_Fetch_Failure  : ext_fetch_addr_error,
  Step_Fetch_Failure      : (virtaddr, ExceptionType),
  Step_Execute            : (ExecutionResult, instbits),
  Step_Waiting            : WaitReason,
  Step_Halt               : unit,
}

function run_hart_waiting(step_no : int, wr: WaitReason, instbits : instbits, exit_wait : bool) -> Step = {
  // successfully interrupted waits
  if shouldWakeForInterrupt() then {
    if   get_config_print_instr()
    then print_log("interrupt exit from " ^ wait_name(wr) ^ " state at PC " ^ bits_str(PC));

    // The waiting instruction retires successfully.  The
    // pending interrupts will be handled in the next step.
    hart_state = HART_ACTIVE();
    return Step_Execute(Retire_Success(), instbits)
  };

  match (wr, valid_reservation(), exit_wait) {
    (WAIT_WRS_STO, false, _) => {
      if   get_config_print_instr()
      then print_log("reservation invalid exit from " ^ wait_name(WAIT_WRS_STO) ^ " state at PC " ^ bits_str(PC));

      hart_state = HART_ACTIVE();
      Step_Execute(Retire_Success(), instbits)
    },
    (WAIT_WRS_NTO, false, _) => {
      if   get_config_print_instr()
      then print_log("reservation invalid exit from " ^ wait_name(WAIT_WRS_NTO) ^ " state at PC " ^ bits_str(PC));

      hart_state = HART_ACTIVE();
      Step_Execute(Retire_Success(), instbits)
    },
    // Transition out of waiting states as instructed.
    (WAIT_WFI, _, true) => {
      if   get_config_print_instr()
      then print_log("forced exit from " ^ wait_name(WAIT_WFI) ^ " state at PC " ^ bits_str(PC));

      hart_state = HART_ACTIVE();
      // "When TW=1, then if WFI is executed in any
      // less-privileged mode, and it does not complete within an
      // implementation-specific, bounded time limit, the WFI
      // instruction causes an illegal-instruction exception."
      if   (cur_privilege == Machine | mstatus[TW] == 0b0)
      then Step_Execute(Retire_Success(), instbits)
      else Step_Execute(Illegal_Instruction(), instbits)
    },
    (WAIT_WRS_STO, _, true) => {
      if   get_config_print_instr()
      then print_log("timed-out exit from " ^ wait_name(WAIT_WRS_STO) ^ " state at PC " ^ bits_str(PC));

      hart_state = HART_ACTIVE();
      Step_Execute(Retire_Success(), instbits)
    },
    (WAIT_WRS_NTO, _, true) => {
      if   get_config_print_instr()
      then print_log("timed-out exit from " ^ wait_name(WAIT_WRS_NTO) ^ " state at PC " ^ bits_str(PC));

      hart_state = HART_ACTIVE();
      // TODO: This is similar to WFI above for now, but will change to handle
      // VS/VU modes and hstatus.VTW.
      if   (cur_privilege == Machine | mstatus[TW] == 0b0)
      then Step_Execute(Retire_Success(), instbits)
      else Step_Execute(Illegal_Instruction(), instbits)
    },
    // remain waiting
    (_, _, false) => {
      if   get_config_print_instr()
      then print_log("remaining in " ^ wait_name(wr) ^ " state at PC " ^ bits_str(PC));
      Step_Waiting(wr)
    }
  }
}

function run_hart_active(step_no: nat) -> Step = {
  match dispatchInterrupt(cur_privilege) {
    Some(intr, priv) => Step_Pending_Interrupt(intr, priv),
    None() => match ext_fetch_hook(fetch()) {
      // extension error
      F_Ext_Error(e)   => Step_Ext_Fetch_Failure(e),
      // standard error
      F_Error(e, addr) => Step_Fetch_Failure(Virtaddr(addr), e),
      // non-error cases:
      F_RVC(h) => {
        sail_instr_announce(h);
        fetch_callback(h);
        let instbits : instbits = zero_extend(h);
        let instruction = ext_decode_compressed(h);
        if   get_config_print_instr()
        then {
          print_log_instr("[" ^ dec_str(step_no) ^ "] [" ^ to_str(cur_privilege) ^ "]: " ^ bits_str(PC) ^ " (" ^ bits_str(h) ^ ") " ^ to_str(instruction), zero_extend(PC));
        };
        // When ELP is set to LP_EXPECTED, the next instruction needs to be
        // the non-RVC `LPAD` instruction.
        if is_landing_pad_expected() then {
          let r = Trap(cur_privilege, CTL_TRAP(make_landing_pad_exception()), PC);
          Step_Execute(r, instbits)
        }
        // check for RVC once here instead of every RVC execute clause.
        else if currentlyEnabled(Ext_Zca) then {
          nextPC = PC + 2;
          let result : ExecutionResult = match execute(instruction) {
            ExecuteAs(other_inst) => execute(other_inst),
            result => result,
          };
          Step_Execute(result, instbits)
        } else {
          Step_Execute(Illegal_Instruction(), instbits)
        }
      },
      F_Base(w) => {
        sail_instr_announce(w);
        fetch_callback(w);
        let instbits : instbits = zero_extend(w);
        let instruction = ext_decode(w);
        if   get_config_print_instr()
        then {
          print_log_instr("[" ^ dec_str(step_no) ^ "] [" ^ to_str(cur_privilege) ^ "]: " ^ bits_str(PC) ^ " (" ^ bits_str(w) ^ ") " ^ to_str(instruction), zero_extend(PC));
        };
        // When ELP is set to LP_EXPECTED, if the next instruction in
        // the instruction stream is not LPAD, then a software check
        // exception with a landing pad fault code is thrown.
        if is_landing_pad_expected() & not(is_lpad_instruction(instruction)) then {
          let r = Trap(cur_privilege, CTL_TRAP(make_landing_pad_exception()), PC);
          Step_Execute(r, instbits)
        } else {
          nextPC = PC + 4;
          let result : ExecutionResult = match execute(instruction) {
            ExecuteAs(other_inst) => execute(other_inst),
            result => result,
          };
          Step_Execute(result, instbits)
        }
      }
    }
  }
}

function wait_is_nop(wr : WaitReason) -> bool =
  match wr {
    WAIT_WFI     => config platform.wfi_is_nop,
    WAIT_WRS_STO => config extensions.Zawrs.sto.is_nop,
    WAIT_WRS_NTO => config extensions.Zawrs.nto.is_nop,
  }

// `step_result` is the type of the return value of the `try_step`
// function.
// `step_result.in_wait` indicates whether the hart is in a waiting
// state.  It is set to true when the `hart_state` is `HART_WAITING`
// at the end of `try_step`.
// `.in_debug_mode` indicates whether the hart is in Debug Mode at the
// end of `try_step` (i.e. `debug_mode_active` is true).
// `.in_debug_cmd` indicates whether the model is in Debug mode and
// executing an abstract command (such as instructions from a program
// buffer).
// `.debug_cmd_error` indicates whether an exception was encountered
// when executing an abstract command.

struct step_result = {
  in_wait         : bool,
  in_debug_mode   : bool,
  in_debug_cmd    : bool,
  debug_cmd_error : bool,
}

// The `try_step` function is the main internal driver of the Sail
// model. It performs the fetch-decode-execute for an instruction. It
// is also the primary interface to the non-Sail execution harness.
//
// A "step" is a full execution of an instruction, resulting either
// in its retirement or a trap.  It returns a step_result value
// indicating the current model state.
//
// WFI and WRS instructions can cause the model to wait (hart_state is
// HART_WAITING), in which case a step has not happened and
// step_result.in_wait is set to true. Otherwise step_result.in_wait
// is set to false.
//
// step_result.in_debug_mode is set to true when the hart is in Debug Mode.
//
// step_result.in_debug_cmd is set to true when the hart is in Debug
// Mode and executing a debug abstract command.
//
// step_result.debug_cmd_error is set to true if the hart experienced
// an exception when executing a debug abstract command.
//
// * step_no: the current step number; this is maintained by by the
//            non-Sail harness and is incremented when `try_step()`
//            returns true.
// * exit_wait: if true, and the model is waiting (HART_WAITING)
//              then it will wake up (switch to HART_ACTIVE) and
//              complete the WFI/WRS instruction, either successfully
//              retiring it or causing an illegal instruction
//              exception depending on `mstatus[TW]`. `exit_wait`
//              only affects the behaviour if the model is already
//              waiting from a previous WFI/WRS. It doesn't affect
//              WFI/WRS instructions executed in the same call of
//              `try_step()` (but see `wait_is_nop()`).
// * debug_request: controls entry into and exit from Debug Mode as
//              described above. `exit_wait` is ignored when
//              `debug_request` is either `DR_Halt` or `DR_Resume`.
//              When single-stepping is set, DR_Resume should be specified.

function update_debug_module_status(request: DebugRequest, step : bool) -> unit = {
  let resume = request == Resume();
  let halt   = request == Halt();
  let (to_reset, halt_on_reset) : (bool, bool) = match request {
    Reset(hor) => (true, hor),
    _          => (false, false),
  };
  // TODO change name of to_reset
  let status : debug_module_hart_status = struct { halted    = halt     | halt_on_reset | step,
                                                   running   = (to_reset & not(halt_on_reset)) | resume & not(step),
                                                   havereset = to_reset,
                                                 };
  send_hart_status(status);
}

function handle_debug_module_resume_request(request : DebugRequest) -> unit = {
  if debug_mode_active then {
    // TODO: writes to resumereq should be ignored while a abstract command is executed
    // so we should remove the if statement down below.
    // TODO: Lets revisit the line below
    //if in_debug_abstract_command() then end_debug_abstract_command();
    exit_debug_mode();
    update_debug_module_status(request, false)
  };
}

function handle_debug_module_halt_request(request : DebugRequest) -> unit = {
  if not(debug_mode_active) then {
    enter_debug_mode(DBGEntry_HaltReq, zeros(), get_arch_pc());
    update_debug_module_status(request, false)
  };
}

function handle_debug_module_execute_program_buffer(request : DebugRequest) -> unit = {
  PC = trunc(plat_program_buffer_base);
  nextPC = PC;
  progbuf_active = true;

  resume_after_progbuf = match request {
    ExecuteProgramBuffer(resume) => resume,
    _ => false,
  };

  start_debug_abstract_command();
}

val write_data : forall 'width, is_mem_width('width).
  (bits(8 * 'width), int('width)) -> unit

function write_data(data, width) = {
  match width {
    1  => data0 = zeros(24) @ data[7..0],
    2  => data0 = zeros(16) @ data[15..0],
    4  => data0 = data[31..0],
    8  => { data0 = data[31..0]; data1 = data[63..32]; },
    16 => { data0 = data[31..0]; data1 = data[63 .. 32]; data2 = data[95 .. 64]; data3 = data[127 .. 96 ]; },
  }
}

val read_data : forall 'width, is_mem_width('width).
  (int('width)) -> (bits(8 * 'width))

function read_data(width) = match width {
  1  => data0[7..0],
  2  => data0[15..0],
  4  => data0[31..0],
  8  => data1 @ data0,
  16 => data3 @ data2 @ data1 @ data0,
}

val handle_vmem_write : forall 'width, is_mem_width('width).
  (virtaddr, int('width), bits(8 * 'width)) -> unit

function handle_vmem_write(vaddr, width, data) = {
  match vmem_write_addr(vaddr, width, data, Write(Data), false, false, false) {
    Ok(_) => (),
    Err(_) => abstractcs[cmderr] = abstract_command_error(EXCEPTION),
  }
}

val handle_vmem_read : forall 'width, is_mem_width('width).
  (virtaddr, int('width)) -> unit

function handle_vmem_read(vaddr, width) = {
  match vmem_read_addr(vaddr, zeros(), width, Read(Data), false, false, false) {
    Ok(data) => write_data(data, width),
    Err(_) => abstractcs[cmderr] = abstract_command_error(EXCEPTION),
  }
}

function handle_debug_module_memory_access(virtual : bool, write : bool, width : aamsize, addr: xlenbits) -> unit = {
  start_debug_abstract_command();
  debug_physical_access = not(virtual);
  let vaddr : virtaddr = Virtaddr(addr[xlen - 1..0]);
  if write then {
    match width {
      0 => handle_vmem_write(vaddr, 1,  read_data(1)),
      1 => handle_vmem_write(vaddr, 2,  read_data(2)),
      2 => handle_vmem_write(vaddr, 4,  read_data(4)),
      3 => handle_vmem_write(vaddr, 8,  read_data(8)),
      4 => handle_vmem_write(vaddr, 16, read_data(16)),
    }
  } else {
    match width {
      0 => handle_vmem_read(vaddr, 1),
      1 => handle_vmem_read(vaddr, 2),
      2 => handle_vmem_read(vaddr, 4),
      3 => handle_vmem_read(vaddr, 8),
      4 => handle_vmem_read(vaddr, 16),
   }
  };
  abstractcs[busy] = 0b0;
  end_debug_abstract_command();
}

function handle_debug_module_reset_request(request : DebugRequest) -> unit = {
  reset();
  update_debug_module_status(request, false);
  match request {
    Reset(halt_on_reset) => if halt_on_reset then enter_debug_mode(DBGEntry_ResetHaltReq, zeros(), get_arch_pc()),
    _ => (),
  };
}

function handle_debug_module_request_quick_access(request : DebugRequest) -> unit = {
  handle_debug_module_halt_request(Halt());
  print_endline("Execute ProgramBuffer");
  handle_debug_module_execute_program_buffer(ExecuteProgramBuffer(true));
}

function handle_debug_module_request() -> option(DebugRequest) = {
  if debug_module_active_request then {
    if get_config_print_debug()
    then print_log("Hart received request from debug module: " ^ debug_request_to_string(debug_module_request));
    match debug_module_request {
      Halt()                  => handle_debug_module_halt_request(debug_module_request),
      Resume()                => handle_debug_module_resume_request(debug_module_request),
      Reset(_)                => handle_debug_module_reset_request(debug_module_request),
      QuickAccess()           => handle_debug_module_request_quick_access(debug_module_request),
      ExecuteProgramBuffer(_) => handle_debug_module_execute_program_buffer(debug_module_request),
      MemoryAccess(virtual, write, size, addr) => handle_debug_module_memory_access(virtual, write, size, addr),
    };
    debug_module_active_request = false;
    return Some(debug_module_request);
  } else {
    return None()
  }
}

function handle_debug_single_step() -> unit = {
  if in_single_step() & not(debug_mode_active) then {
    print_endline("DEBUG: Entering debug mode via single step");
    update_debug_module_status(Resume(), true);
    enter_debug_mode(DBGEntry_Step, zeros(), get_arch_pc())
  }
}

// This function only handles external requests, there are other ways to enter debug mode, through ebreak etc.
//

function try_step(step_no : nat, exit_wait : bool) -> step_result = {
  /* for step extensions */
  ext_pre_step_hook();

  // handle_debug_module_request() processes external requests from the debug module.
  // Internal debug requests are handled separately in the step_val match construct.

  let debug_request = if hartSupports(Ext_Sdext) then handle_debug_module_request() else None();

  /*
   * This records whether or not minstret should be incremented when
   * the instruction is retired. Since retirement occurs before CSR
   * writes we initialise it based on mcountinhibit here, before it is
   * potentially changed. This is also set to false if minstret is
   * written.  See the note near the minstret declaration for more
   * information.
   */
  minstret_increment = should_inc_minstret(cur_privilege);

  // When halting to enter Debug mode, any waiting instructions should
  // complete execution, but other instructions should not execute.
  let halt_request : bool = match debug_request {
    Some(Halt()) => true,
    _            => false,
  };

  let exit_wait = exit_wait | (hartSupports(Ext_Sdext) & halt_request);
  let step_val : Step = match hart_state {
      HART_WAITING(wr, instbits)         => run_hart_waiting(step_no, wr, instbits, exit_wait),
      HART_ACTIVE() if progbuf_active => run_hart_active(step_no),
      HART_ACTIVE() if debug_mode_active => Step_Halt(),
      HART_ACTIVE()                      => run_hart_active(step_no),
    };

  match step_val {
    Step_Pending_Interrupt(intr, priv) => {
      if   get_config_print_instr()
      then print_bits("Handling interrupt: ", interruptType_bits(intr));
      handle_interrupt(intr, priv)
    },
    Step_Ext_Fetch_Failure(e) => ext_handle_fetch_check_error(e),
    Step_Fetch_Failure(vaddr, e) => handle_exception(bits_of(vaddr), e),
    Step_Waiting(_) => assert(hart_is_waiting(hart_state), "cannot be Waiting in a non-Wait state"),
    Step_Execute(Retire_Success(), _) => assert(hart_is_active(hart_state)),
    // This case was handled above when processing the fetch result.
    Step_Execute(ExecuteAs(_), _) => assert(false),
    // standard errors
    Step_Execute(Trap(priv, ctl, pc), _) => set_next_pc(exception_handler(priv, ctl, pc)),
    Step_Execute(Memory_Exception(vaddr, e), _) => handle_exception(bits_of(vaddr), e),
    Step_Execute(Illegal_Instruction(), instbits) => handle_exception(zero_extend(instbits), E_Illegal_Instr()),
    Step_Execute(Enter_Wait(wr), instbits) =>
      if wait_is_nop(wr) then {
        // This is the same as the RETIRE_OK case.
        assert(hart_is_active(hart_state));
      } else {
        // Transition into the wait state.
        if   get_config_print_instr()
        then print_log("entering " ^ wait_name(wr) ^ " state at PC " ^ bits_str(PC));

        hart_state = HART_WAITING(wr, instbits);
      },
    Step_Execute(Debug(action), _) => {
      match action {
        // When entering Debug via an execution of `ebreak`, DPC is set
        // to the address of the `ebreak`.
        Enter_Debug_Mode(cause)       => {
          enter_debug_mode(cause, zeros(), get_arch_pc());
          update_debug_module_status(Halt(), false)
        },
        Exit_Debug_Abstract_Command() => {
          progbuf_active = false;
          abstractcs[busy] = 0b0;
          end_debug_abstract_command();

          if resume_after_progbuf then {
            handle_debug_module_resume_request(Resume());
            resume_after_progbuf = false;
          };
        },
        // TODO: Check whether this case (Step_Execute(...)) is actually needed and if we pass the right request (DR_Resume)
        Exit_Debug_Mode() => {
          exit_debug_mode();
          update_debug_module_status(Resume(), false)
        },
      };
    },
    // errors from extensions
    Step_Execute(Ext_CSR_Check_Failure(), _) => ext_check_CSR_fail(),
    Step_Execute(Ext_ControlAddr_Check_Failure(e), _) => ext_handle_control_check_error(e),
    Step_Execute(Ext_DataAddr_Check_Failure(e), _) => ext_handle_data_check_error(e),
    Step_Execute(Ext_XRET_Priv_Failure(), _) => ext_fail_xret_priv(),
    Step_Halt() => (),
  };

  let in_wait : bool = match hart_state {
    HART_WAITING(_) => true,
    HART_ACTIVE() => {
      // The hart might have entered Debug mode during this
      // `try_step()`.  The value of the PC on entry is not specified
      // (unlike that of DPC).  For now, we just tick the pc as usual.
      tick_pc();

      let retired : bool = match step_val {
        Step_Execute(Retire_Success(), _) => true,
        // WFI, WRS.{STO, NTO} retire immediately if the model is configured
        // to treat them as a nop.  Otherwise they always wait for at least
        // one call of `try_step()`.
        Step_Execute(Enter_Wait(wr), _) if wait_is_nop(wr) => true,
        _ => false,
      };

      // Increment minstret if we retired an instruction and the
      // update wasn't suppressed by writing to it explicitly or
      // mcountinhibit[IR] or minstretcfg.
      if retired & minstret_increment then minstret = minstret + 1;

      // Record the next PC for RVFI.
      // TODO: Remove this and implement it in C.
      if get_config_rvfi() then {
        rvfi_pc_data[rvfi_pc_wdata] = zero_extend(get_arch_pc())
      };

      // For step extensions
      ext_post_step_hook();
      // Return that we have stepped and are not waiting.
      false
    }
  };

  if hartSupports(Ext_Sdext) then handle_debug_single_step();

  // TODO: We should not increment the instruction code (on the c++ side) if we are in the HALT state
  struct { in_wait,
           in_debug_mode   = debug_mode_active,
           in_debug_cmd    = debug_abstract_command_active,
           debug_cmd_error = debug_abstract_command_error }
}

function loop () : unit -> unit = {
  var i : nat = 0;
  var step_no : nat = 0;
  while not(htif_done) do {
    // This standalone loop always exits immediately out of waiting
    // states.
    let stepped = try_step(step_no, true);
    if not(stepped.in_wait) then {
      step_no = step_no + 1;
      if get_config_print_instr() then {
        print_step()
      };
      sail_end_cycle()
    };

    // check htif exit
    if htif_done then {
      let exit_val = unsigned(htif_exit_code);
      if exit_val == 0 then print("SUCCESS")
      else print_int("FAILURE: ", exit_val);
    } else {
      // update time
      i = i + 1;
      if i == plat_insns_per_tick then {
        tick_clock();
        i = 0;
      }
    }
  }
}
