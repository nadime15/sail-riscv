//=======================================================================================
//  This Sail RISC-V architecture model, comprising all files and
//  directories except where otherwise noted is subject the BSD
//  two-clause license in the LICENSE file.
//
//  SPDX-License-Identifier: BSD-2-Clause
//=======================================================================================

// Debug mode extension Sdext: control

// The specification denotes a hart's entry into Debug mode as the hart "halting".
function enter_debug_mode(cause : debug_entry_cause, extcause : bits(3), pc : xlenbits) -> unit = {
  assert(not(debug_mode_active()), "enter_debug_mode: already in Debug mode.");
  dpc = pc;
  dcsr = [dcsr with
           Prv = privLevel_to_bits(cur_privilege),
           PELP = elp,
           // TODO: V from hypervisor mode
           // TODO: intra-instruction interruption, e.g. vstart for vector instructions
           Cause    = debug_cause_bits(cause),
           ExtCause = extcause,
         ];
  cur_privilege = Machine;
  cancel_reservation(); // TODO: Make this configurable?

  // Store the time of entry into Debug mode.
  dtime = mtime;

  // Set elp to NO_LP_EXPECTED
  reset_elp();

  debug_state = Debug_Active(None());

  if get_config_print_debug()
  then print_log("entering Debug mode from " ^ to_str(privLevel_bits(dcsr[Prv], bitzero)) ^ " Cause: " ^ debug_entry_cause_to_str(cause));
}

// The specification denotes a hart's exit from Debug mode as the hart "resuming".
function exit_debug_mode() -> unit = {
  assert(debug_mode_active(), "exit_debug_mode: not in Debug mode.");
  set_next_pc(dpc);
  tick_pc();

  // Restore elp from pelp or clear it if unsupported
  elp = if hartSupports(Ext_Zicfilp) then dcsr[PELP] else landing_pad_bits(NO_LP_EXPECTED);
  dcsr[PELP] = landing_pad_bits(NO_LP_EXPECTED);

  cur_privilege = privLevel_bits(dcsr[Prv], bitzero);
  if cur_privilege != Machine then {
    mstatus[MPRV] = 0b0;
    // TODO: If Smdbltrp is enabled, clear mstatus.MDT
    // and adjust sstatus.SDT and (for hypervisor) vsstatus.SDT.
  };
  // TODO: V from hypervisor mode

  debug_state = Debug_Inactive();

  if get_config_print_debug()
  then print_log("exiting Debug mode to " ^ to_str(cur_privilege));
}

function is_executing_progbuf() -> bool = {
  match debug_state {
    Debug_Active(Some(ac)) => ac.run_progbuf,
    _ => false
  };
}

function debug_uses_virtual_addressing() -> bool =
  match debug_state {
    Debug_Active(Some(ac)) => match ac.cmd {
      MemoryAccess(virtual, _, _, _) => virtual,
      _ => false
    },
    _ => false
  }

function start_debug_abstract_command(cmd : AbstractCommand, run_progbuf : bool) -> unit = {
  assert(currentlyEnabled(Ext_Sdext), "Cannot start Debug abstract command: Sdext is not currently enabled");
  if get_config_print_debug() then print_log("Start Abstract Command");

 debug_state = Debug_Active(Some(struct RunningAbstractCommand {
    cmd = cmd,
    error = CMDERR_NONE,
    run_progbuf = run_progbuf,
  }));
}

function end_debug_abstract_command(status : AbstractCommandError) -> unit = {
  assert(currentlyEnabled(Ext_Sdext), "Cannot end Debug abstract command: Sdext is not currently enabled");
  if get_config_print_debug() then print_log("End Abstract Command: Status(" ^ abstract_command_error_name(status) ^ ")");

  complete_abstract_command(status);
  debug_state = Debug_Active(None());
}

function get_abstract_command() -> AbstractCommand = match debug_state {
  Debug_Active(Some(ac)) => ac.cmd,
  _ => internal_error(__FILE__, __LINE__, "no active abstract command"),
}

// This is called internally.

function reset_sdext() -> unit = {
  init_sdext();
  dcsr = reset_Dcsr();
}

// This is independent of the Sdext spec, we use this
// function when the hart is reset from the debug module
function reset_debug() -> unit = debug_state = Debug_Inactive()
