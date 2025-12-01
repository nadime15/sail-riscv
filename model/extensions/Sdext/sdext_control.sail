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
  assert(not(in_debug_mode()), "enter_debug_mode: already in Debug mode.");
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

  //debug_mode_active = true;
  debug_state = Debug_Active();

  if get_config_print_debug()
  then print_log("entering Debug mode from " ^ to_str(privLevel_bits(dcsr[Prv], bitzero)) ^ " Cause: " ^ debug_entry_cause_to_str(cause));
}

// The specification denotes a hart's exit from Debug mode as the hart "resuming".
function exit_debug_mode() -> unit = {
  assert(in_debug_mode(), "exit_debug_mode: not in Debug mode.");
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

//  debug_mode_active = false;
  debug_state = Debug_Inactive();

  if get_config_print_debug()
  then print_log("exiting Debug mode to " ^ to_str(cur_privilege));
}

function trigger_bug() -> unit = {
  debug_state = Debug_Active();
  print_endline("What is in_debug_mode() " ^ (if in_debug_mode() then "true" else "false"));
  print_endline("What is debug_state == Debug_Active()" ^ (if debug_state == Debug_Active() then "true" else "false"));
  assert((debug_state == Debug_Active()) == in_debug_mode(), "This should never fail")
}

// This function must be called by the debugger/external-harness
// before executing any instructions from a Debug program buffer.
function start_debug_abstract_command() -> unit = {
  trigger_bug();
  assert(currentlyEnabled(Ext_Sdext), "Cannot start Debug abstract command: Sdext is not currently enabled");
  if get_config_print_debug() then print_log("Start Abstract Command");
  debug_abstract_command_active = true
}

function end_debug_abstract_command(status : AbstractCommandError) -> unit = {
  assert(currentlyEnabled(Ext_Sdext), "Cannot end Debug abstract command: Sdext is not currently enabled");
  if get_config_print_debug() then print_log("End Abstract Command: Status(" ^ abstract_command_error_name(status) ^ ")");
  debug_abstract_command_active = false;
  progbuf_active = false;
  complete_abstract_command(status, debug_command);
}

// This is called internally.
function set_debug_abstract_command_error() -> unit = {
  assert(currentlyEnabled(Ext_Sdext), "Cannot set Debug abstract command error: Sdext is not currently enabled");
  debug_abstract_command_error = true
}

// This is called from the external harness, so there is no assert.
function clear_debug_abstract_command_error() -> unit = {
  debug_abstract_command_error = false
}

function reset_sdext() -> unit = {
  dcsr = reset_Dcsr();
}

// This is independent of the Sdext spec, we use this
// function when the hart is reset from the debug module
function reset_debug() -> unit = {
  debug_abstract_command_active = false;
  debug_abstract_command_error = false;
//  debug_mode_active = false;

  debug_state = Debug_Inactive();
}
