//=======================================================================================
//  This Sail RISC-V architecture model, comprising all files and
//  directories except where otherwise noted is subject the BSD
//  two-clause license in the LICENSE file.
//
//  SPDX-License-Identifier: BSD-2-Clause
//=======================================================================================

// Mapping of Debug Module Register addresses to their names.
val debug_module_reg_name_map : debug_module_reg <-> string

// Forward declaration so the implementation can be
// defined after all registers have been declared
val reset_debug_module : unit -> unit

// initialize scattered definitions

scattered mapping debug_module_reg_name_map

val debug_module_reg_name : debug_module_reg -> string
function debug_module_reg_name(addr) = debug_module_reg_name_map(addr)

overload to_str = {debug_module_reg_name}

// Returns whether a Debug Module Register exists
val is_debug_module_reg_defined : (debug_module_reg) -> bool
scattered function is_debug_module_reg_defined

// Returns the value of the Debug Module Register if it is defined
val read_debug_module_reg : debug_module_reg -> bits(32)
scattered function read_debug_module_reg

// if the Debug Module Register is defined, writes the legalized value to it
val write_debug_module_reg : (debug_module_reg, bits(32)) -> unit
scattered function write_debug_module_reg

///////////////////////////////////////////////////////////////////////

bitfield Dmstatus : bits(32) = {
  ndmresetpending: 24,
  stickyunavail:   23,
  impebreak:       22,
  allhavereset:    19,
  anyhavereset:    18,
  allresumeack:    17,
  anyresumeack:    16,
  allnonexistent:  15,
  anynonexistent:  14,
  allunavail:      13,
  anyunavail:      12,
  allrunning:      11,
  anyrunning:      10,
  allhalted:        9,
  anyhalted:        8,
  authenticated:    7,
  authbusy:         6,
  hasresethaltreq:  5,
  confstrptrvalid:  4,
  version:          3 .. 0
}

function initial_dmstatus() -> Dmstatus = {
  [Mk_Dmstatus(zeros()) with
    impebreak = if unsigned(MAX_PROGBUF_SIZE) == 1 | (config platform.debug_module.impebreak : bool) then 0b1 else 0b0,
    // NOTE: By default, the hart is running (riscv-openocd expects it to be either running or halted during initialization).
    allrunning = 0b1,
    anyrunning = 0b1,
    // TODO: For now authentication is not supported
    // but this should be optional
    // NOTE: This needs to be disabled because otherwise
    // OpenOCD will not continue after failed authentication
    authenticated   = 0b1,
    hasresethaltreq = 0b1,
    // Version 1.0
    version         = 0b0011
  ]
}

register dmstatus: Dmstatus = initial_dmstatus()

mapping clause debug_module_reg_name_map = 0x11  <-> "dmstatus"

function clause is_debug_module_reg_defined (0x11) = true
function clause write_debug_module_reg(0x11, value) = ()
function clause read_debug_module_reg(0x11) = dmstatus.bits

// Get the current hart state from dmstatus
function get_hart_state() -> DebugHartState = {
  if dmstatus[allnonexistent]  == 0b1 then NON_EXISTENT
  else if dmstatus[allunavail] == 0b1 then UNAVAILABLE
  else if dmstatus[allhalted]  == 0b1 then HALTED
  else if dmstatus[allrunning] == 0b1 then RUNNING
  else {
    internal_error(__FILE__, __LINE__, "Hart in invalid state");
  }
}

function set_hart_state(state : DebugHartState) -> unit = {
  dmstatus[allnonexistent] = bool_to_bits(state == NON_EXISTENT);
  dmstatus[anynonexistent] = bool_to_bits(state == NON_EXISTENT);
  dmstatus[allunavail]     = bool_to_bits(state == UNAVAILABLE);
  dmstatus[anyunavail]     = bool_to_bits(state == UNAVAILABLE);
  dmstatus[allhalted]      = bool_to_bits(state == HALTED);
  dmstatus[anyhalted]      = bool_to_bits(state == HALTED);
  dmstatus[allrunning]     = bool_to_bits(state == RUNNING);
  dmstatus[anyrunning]     = bool_to_bits(state == RUNNING);
}

bitfield Abstractcs : bits(32) = {
  progbufsize : 28 .. 24,
  busy :        12,
  relaxedpriv:  11,
  cmderr:       10 .. 8,
  datacount:     3 .. 0
}

function legalize_abstractcs(d : Abstractcs, x : bits(32)) -> Abstractcs = {
  let x = Mk_Abstractcs(x);
  [d with
    progbufsize = MAX_PROGBUF_SIZE,
    // TODO: Check if this is the case
    relaxedpriv = 0b1,
    cmderr      = if x[cmderr] == ones() then zeros() else d[cmderr], // R/W1C
    datacount   = MAX_DATA_SIZE,
  ]
}

register abstractcs: Abstractcs = legalize_abstractcs(Mk_Abstractcs(zeros()), zeros())

function set_abstractcs_busy(is_busy : bool) -> unit = {
  abstractcs[busy] = bool_to_bits(is_busy);
}

function is_abstractcs_busy() -> bool = {
  bits_to_bool(abstractcs[busy])
}

mapping clause debug_module_reg_name_map = 0x16  <-> "abstractcs"

function clause is_debug_module_reg_defined (0x16) = true
function clause write_debug_module_reg(0x16, value) = { abstractcs = legalize_abstractcs(abstractcs, value); }
function clause read_debug_module_reg(0x16) = abstractcs.bits

function check_abstract_busy_and_set_error() -> bool = {
  if is_abstractcs_busy() then {
    if abstractcs[cmderr] == abstract_command_error(CMDERR_NONE) then {
      abstractcs[cmderr] = abstract_command_error(CMDERR_BUSY);
    };
    true
  }
  else {
    false
  }
}

function complete_abstract_command(status : AbstractCommandError, cmd : option(AbstractCommand)) -> unit = {
  // Debug Module never clears cmderr, only sets it or preserves it
  // https://github.com/riscv-collab/riscv-openocd/issues/1306#issuecomment-3492075576
  if abstractcs[cmderr] == abstract_command_error(CMDERR_NONE) then {
    abstractcs[cmderr] = abstract_command_error(status)
  };

  set_abstractcs_busy(false);

  //TODO: handle aarmpostincrement etc
  // match cmd {
  //  Some(_)
  //  None() =>
  //}
}

register data_regs : vector(12, bits(32)) = vector_init(zeros())

bitfield Command : bits(32) = {
  cmdtype: 31 .. 24,
  control: 23 .. 0
}

val read_arg : forall 'n, 'n in {32, 64, 128}.
  (range(0, 2), int('n)) -> bits('n)

function read_arg(arg_num, argument_width) = {
  let value : bits('n) = match (arg_num, argument_width) {
    // arg0
    (0, 32)  => data_regs[0],
    (0, 64)  => data_regs[1] @ data_regs[0],
    (0, 128) => data_regs[3] @ data_regs[2] @ data_regs[1] @ data_regs[0],
    // arg1
    (1, 32)  => data_regs[1],
    (1, 64)  => data_regs[3] @ data_regs[2],
    (1, 128) => data_regs[7] @ data_regs[6] @ data_regs[5] @ data_regs[4],
    // arg2
    (2, 32)  => data_regs[2],
    (2, 64)  => data_regs[5] @ data_regs[4],
    (2, 128) => data_regs[11] @ data_regs[10] @ data_regs[9] @ data_regs[8],
  };
  if get_config_print_debug() then
    print_log("DEBUG read_arg: arg_num=" ^ dec_str(arg_num) ^
    " width=" ^ dec_str(argument_width) ^
    " value=" ^ bits_str(value));
  value
}

val write_arg : forall 'n, 'n in {32, 64, 128}.
  (range(0, 2), int('n), bits('n)) -> unit

function write_arg(arg_num, argument_width, value) = {
  if get_config_print_debug() then
    print_log("DEBUG write_arg: arg_num=" ^ dec_str(arg_num) ^
    " width=" ^ dec_str(argument_width) ^
    " value=" ^ bits_str(value));
  match (arg_num, argument_width) {
    // arg0
    (0, 32)  => {
      data_regs[0] = value;
    },
    (0, 64)  => {
      data_regs[0] = value[31..0];
      data_regs[1] = value[63..32];
    },
    (0, 128) => {
      data_regs[0] = value[31..0];
      data_regs[1] = value[63..32];
      data_regs[2] = value[95..64];
      data_regs[3] = value[127..96];
    },
    // arg1
    (1, 32)  => {
      data_regs[1] = value;
    },
    (1, 64)  => {
      data_regs[2] = value[31..0];
      data_regs[3] = value[63..32];
    },
    (1, 128) => {
      data_regs[4] = value[31..0];
      data_regs[5] = value[63..32];
      data_regs[6] = value[95..64];
      data_regs[7] = value[127..96];
    },
    // arg2
    (2, 32)  => {
      data_regs[2] = value;
    },
    (2, 64)  => {
      data_regs[4] = value[31..0];
      data_regs[5] = value[63..32];
    },
    (2, 128) => {
      data_regs[8]  = value[31..0];
      data_regs[9]  = value[63..32];
      data_regs[10] = value[95..64];
      data_regs[11] = value[127..96];
    },
  };
}

// ============================================================================
// Abstract Command Handlers
// ============================================================================

// Extract and validate ACCESS_REGISTER command
function handle_access_register_cmd(cmd : bits(32)) -> AbstractCommandError = {
  let aarsize          = cmd[22 .. 20];
  let reserved         = cmd[23];
  let aarpostincrement = cmd[19];
  let postexec         = cmd[18];
  let transfer         = cmd[17];
  let write            = cmd[16];
  let regno            = cmd[15 .. 0];

  // Validate command format
  if reserved == bitone then CMDERR_NOT_SUPPORTED
  else if aarpostincrement == bitone then CMDERR_NOT_SUPPORTED  // TODO: Add support for aarpostincrement
  else if transfer == bitone & not(is_supported_reg_access(aarsize, regno)) then CMDERR_NOT_SUPPORTED
  else if postexec == bitone & not(config platform.debug_module.program_buffer.supported : bool) then CMDERR_NOT_SUPPORTED
  else match get_hart_state() {
    HALTED => {
      send_debug_request(AbstractCommand(AccessRegister(bit_to_bool(write), regno, aarsize, bit_to_bool(postexec), bit_to_bool(transfer))));
      CMDERR_NONE
    },
    _ => CMDERR_HALT_RESUME,
  };
}

// Extract and validate QUICK_ACCESS command
function handle_quick_access_cmd(cmd : bits(32)) -> AbstractCommandError = {
  if cmd[23 .. 0] != zeros() then CMDERR_NOT_SUPPORTED
  else match get_hart_state() {
    RUNNING => {
      send_debug_request(AbstractCommand(QuickAccess()));
      CMDERR_NONE
    },
    _ => CMDERR_HALT_RESUME,
  }
}

// Extract and validate ACCESS_MEMORY command
function handle_access_memory_cmd(cmd : bits(32)) -> AbstractCommandError = {
  let aamvirtual       = cmd[23];
  let aamsize          = cmd[22 .. 20];
  let aampostincrement = cmd[19];
  let write            = cmd[16];

  // Validate command format
  if cmd[18 .. 17] != zeros() then CMDERR_NOT_SUPPORTED
  else if cmd[13 .. 0] != zeros() then CMDERR_NOT_SUPPORTED
  else if aampostincrement == bitone then CMDERR_NOT_SUPPORTED  // TODO: Add support
  else if not(is_valid_aamsize(aamsize)) then CMDERR_NOT_SUPPORTED
  else match get_hart_state() {
    HALTED => {
      let aamsize_bytes = aamsize_to_bytes(aamsize);
      let addr = read_arg(ARG1, dxlen);

      send_debug_request(AbstractCommand(MemoryAccess(bit_to_bool(aamvirtual), bit_to_bool(write), aamsize_bytes, addr)));
      CMDERR_NONE
    },
    _ => CMDERR_HALT_RESUME,
  }
}

// Main command handler - dispatches to specific command handlers
function handle_abstract_command(cmd : bits(32)) -> AbstractCommandError = {
  let cmdtype = unsigned(cmd[31 .. 24]);

  set_abstractcs_busy(true);

  let status : AbstractCommandError =
    if cmdtype > 2 then CMDERR_NOT_SUPPORTED
    else match abstract_command_type(cmdtype) {
      ACCESS_REGISTER => handle_access_register_cmd(cmd),
      QUICK_ACCESS    => handle_quick_access_cmd(cmd),
      ACCESS_MEMORY   => handle_access_memory_cmd(cmd),
    };

  // Clear busy flag if command failed validation
  if status != CMDERR_NONE then set_abstractcs_busy(false);

  status
}

register command: Command = Mk_Command(zeros())

// NOTE: The command register is WARZ, so the stored value doesn't matter
// for register reads. However, we preserve the command value internally when busy
// to ensure abstractauto re-executes the correct command.
function legalize_command(d : Command, x : bits(32)) -> Command = {
  let busy = is_abstractcs_busy();

  // Determine command error status
  abstractcs[cmderr] =
    if check_abstract_busy_and_set_error() then {
      // Busy flag already set by check function
      abstractcs[cmderr]
    } else {
      match get_hart_state() {
        NON_EXISTENT => abstract_command_error(CMDERR_HALT_RESUME),
        UNAVAILABLE  => abstract_command_error(CMDERR_HALT_RESUME),
        _ => abstract_command_error(handle_abstract_command(x)),
      }
    };

  // Preserve command register value while busy
  if busy then d else Mk_Command(x)
}

mapping clause debug_module_reg_name_map = 0x17  <-> "command"

function clause is_debug_module_reg_defined (0x17) = true
function clause write_debug_module_reg(0x17, value) = { command = legalize_command(command, value); }
function clause read_debug_module_reg(0x17) = zeros()

function handle_register_access(old_value: bits(32), new_value : bits(32), is_write: bool) -> bits(32) = {
  let is_busy = check_abstract_busy_and_set_error();
  if is_busy | not(is_write) then old_value else new_value
}

function trigger_abstractauto_if_enabled(autoexec_enabled: bit) -> unit = {
  // Trigger abstractauto if enabled and not busy
  if bit_to_bool(autoexec_enabled) then {
    // TODO: Improve this, separate validation in legalize_command from actual issuing the abstract command
    let _ = legalize_command(command, command.bits);
  };
}

bitfield Abstractauto : bits(32) = {
  autoexecprogbuf: 31 .. 16,
  autoexecdata:    11 ..  0,
}

// GDB/OpenOCD uses this for burst reads/writes
// This register is optional but openocd just assumes it exists...
function legalize_abstractauto(d : Abstractauto, x : bits(32)) -> Abstractauto = {
  let x = Mk_Abstractauto(x);
  // TODO: This is not really correct yet, we have to monitor the current abstract command:
  // If this register is written while an abstract command is executing then the write is ignored and cmderr
  // becomes 1 (busy) once the command completes (busy becomes 0). (Only if busy was set and transisioned from 1 to 0)
  // Errors could have occurred and we dont wanna overwrite them
  if check_abstract_busy_and_set_error() then {
    d
  } else {
    let DATA_AUTOEXEC_MASK : bits(12) = to_bits_truncate(12, (2 ^ unsigned(MAX_DATA_SIZE)) - 1);
    let PROGBUF_AUTOEXEC_MASK : bits(16) = to_bits_truncate(16, (2 ^ unsigned(MAX_PROGBUF_SIZE)) - 1);

    [d with
      autoexecprogbuf = x[autoexecprogbuf] & PROGBUF_AUTOEXEC_MASK,
      autoexecdata = x[autoexecdata] & DATA_AUTOEXEC_MASK,
    ]
  }
}

register abstractauto: Abstractauto = legalize_abstractauto(Mk_Abstractauto(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x18  <-> "abstractauto"

// Optional Register
function clause is_debug_module_reg_defined (0x18) = true
function clause write_debug_module_reg(0x18, value) = { abstractauto = legalize_abstractauto(abstractauto, value); }
function clause read_debug_module_reg(0x18) = abstractauto.bits

mapping clause debug_module_reg_name_map = 0x04  <-> "data0"
mapping clause debug_module_reg_name_map = 0x05  <-> "data1"
mapping clause debug_module_reg_name_map = 0x06  <-> "data2"
mapping clause debug_module_reg_name_map = 0x07  <-> "data3"
mapping clause debug_module_reg_name_map = 0x08  <-> "data4"
mapping clause debug_module_reg_name_map = 0x09  <-> "data5"
mapping clause debug_module_reg_name_map = 0x0a  <-> "data6"
mapping clause debug_module_reg_name_map = 0x0b  <-> "data7"
mapping clause debug_module_reg_name_map = 0x0c  <-> "data8"
mapping clause debug_module_reg_name_map = 0x0d  <-> "data9"
mapping clause debug_module_reg_name_map = 0x0e  <-> "data10"
mapping clause debug_module_reg_name_map = 0x0f  <-> "data11"

// Single clause with guard for the range
function clause is_debug_module_reg_defined((addr) if DATA_REG_BASE <=_u addr & addr <=_u DATA_REG_END) = {
  unsigned(abstractcs[datacount]) > unsigned(addr - DATA_REG_BASE)
}

function clause write_debug_module_reg((addr, value) if DATA_REG_BASE <=_u addr & addr <=_u DATA_REG_END) = {
  let idx = unsigned(addr - DATA_REG_BASE);
  assert(idx <= 11);
  data_regs[idx] = handle_register_access(data_regs[idx], value, true);
  trigger_abstractauto_if_enabled(abstractauto[autoexecdata][idx]);
}

function clause read_debug_module_reg((addr) if DATA_REG_BASE <=_u addr & addr <=_u DATA_REG_END) = {
  let idx = unsigned(addr - DATA_REG_BASE);
  assert(idx <= 11);
  let _ = handle_register_access(data_regs[idx], zeros(), false);
  trigger_abstractauto_if_enabled(abstractauto[autoexecdata][idx]);
  data_regs[idx]
}

bitfield Dmcontrol : bits(32) = {
  haltreq :        31,
  resumereq:       30,
  hartreset:       29,
  ackhavereset:    28,
  ackunavail:      27,
  hasel:           26,
  hartsello:       25 .. 16,
  hartselhi:       15 ..  6,
  setkeepalive:    5,
  clrkeepalive:    4,
  setresethaltreq: 3,
  clrresethaltreq: 2,
  ndmreset:        1,
  dmactive:        0
}


//function set_nonexistent(ext)

function set_running(r : bool) -> unit = {
  running = r;
  dmstatus[allrunning] = bool_to_bits(running);
  dmstatus[anyrunning] = bool_to_bits(running);
}

function set_halted(h : bool) -> unit = {
  halted = h;
  dmstatus[allhalted] = bool_to_bits(halted);
  dmstatus[anyhalted] = bool_to_bits(halted);
}

function set_havereset(hr : bool) -> unit = {
  havereset = hr;
  dmstatus[allhavereset] = bool_to_bits(havereset);
  dmstatus[anyhavereset] = bool_to_bits(havereset);
}

function set_resumeack(ra : bool) -> unit = {
  resumeack = ra;
  dmstatus[allresumeack] = bool_to_bits(resumeack);
  dmstatus[anyresumeack] = bool_to_bits(resumeack);
}

function set_unavail(un : bool) -> unit = {
  unavail = un;
  dmstatus[allunavail] = bool_to_bits(unavail);
  dmstatus[anyunavail] = bool_to_bits(unavail);
}

function update_halt_on_reset_config(x : Dmcontrol) -> unit = {
  match (x[setresethaltreq], x[clrresethaltreq]) {
    (0b1, 0b0) => haltonreset = true,
    (_,   0b1) => haltonreset = false,
    (_, _)     => ()
  }
}

function handle_halt_or_reset(x : Dmcontrol, halt_on_reset : bool) -> unit = {
  send_debug_request(Reset(x[haltreq] == 0b1 | halt_on_reset));
}

function legalize_active_dmcontrol(d : Dmcontrol, x : Dmcontrol) -> Dmcontrol = {

  // TODO: On any given write, a debugger may only write 1 to at most
  // one of the following bits: resumereq, hartreset, ackhavereset,
  // setresethaltreq, and clrresethaltreq. The others must be written
  // 0.

  // Ignore the bits below if abstract command is executed
  let x = if is_abstractcs_busy() then [x with
    haltreq         = 0b0,
    resumereq       = 0b0,
    ackhavereset    = 0b0,
    hartsello       = zeros(),
    hartselhi       = zeros(),
    setresethaltreq = 0b0,
    clrresethaltreq = 0b0,
  ] else x;

  // Validate hart selection
  let hartsel = x[hartselhi] @ x[hartsello];
  // Only hart 0 exists in minimal implementation
  let hart_exists = hartsel == zeros();

  // Update hart existence status
  dmstatus[allnonexistent] = bool_to_bits(not(hart_exists));
  dmstatus[anynonexistent] = bool_to_bits(not(hart_exists));

  if hart_exists then {
    // Handle halt-on-reset config
    // If haltonreset is set, it takes priority before deciding whether to send HaltOnReset or Reset
    // Example: ndmreset is deasserted while haltonreset is asserted
    update_halt_on_reset_config(x);
    if x[ackhavereset] == 0b1 then set_havereset(false);
    if x[ackunavail]   == 0b1 then set_unavail(false);
  };

  // Handle state transition logic
  match (d[ndmreset], x[ndmreset], d[hartreset], x[hartreset]) {
    // NDM reset deassert
    (0b1, 0b0, _, _) => {
      handle_halt_or_reset(x, haltonreset);
      set_unavail(false);
    },

    // NDM reset assert
    (0b0, 0b1, _, _) => {
      set_unavail(true);
    },

    // Hart reset deassert
    (_, _, 0b1, 0b0) if hart_exists => {
      handle_halt_or_reset(x, haltonreset);
      set_unavail(false);
    },

    // Hart reset assert
    (_, _, 0b0, 0b1) if hart_exists => {
      set_unavail(true);
    },

    // Normal hart operation
    (_, _, _, _) if hart_exists => {
      haltrequest = x[haltreq] == 0b1;

      if haltrequest & not(halted) then {
        haltrequest = true;
        send_debug_request(Halt());
      };

      if x[resumereq] == 0b1 & not(running) then {
        set_resumeack(false);
        send_debug_request(Resume());
        // TODO: resumeack needs to be set after we transition from halt to running
        //set_resumeack(true);
      };
    },

    // Fallback
    _ => (),
  };

  [d with
    // Control bits - preserve written values for pulse-type operations
    haltreq         = if not(is_abstractcs_busy()) then x[haltreq] else d[haltreq],
    hartreset       = x[hartreset],
    // Hart selection - minimal implementation supports only hart 0
    hasel           = 0b0,
    hartsello       = zeros(),
    hartselhi       = zeros(),
    // System control
    ndmreset        = x[ndmreset],
    dmactive        = x[dmactive]
  ]
}

function legalize_dmcontrol(d : Dmcontrol, x : bits(32)) -> Dmcontrol = {
  let x = Mk_Dmcontrol(x);
  match (d[dmactive], x[dmactive]) {
    // Debug Module inactive, can only write dmactive
    (0b0, _) => [d with dmactive = x[dmactive]],
    // Reset Debug Module
    (0b1, 0b0) => {
      reset_debug_module();
      Mk_Dmcontrol(zeros())
    },
    // Debug Module active
    (0b1, 0b1) => legalize_active_dmcontrol(d, x),
  }
}

register dmcontrol: Dmcontrol = legalize_dmcontrol(Mk_Dmcontrol(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x10  <-> "dmcontrol"

function clause is_debug_module_reg_defined (0x10) = true
function clause write_debug_module_reg(0x10, value) = { dmcontrol = legalize_dmcontrol(dmcontrol, value); }
function clause read_debug_module_reg(0x10) = dmcontrol.bits

function send_hart_status(status : debug_module_hart_status) -> unit = {
  set_running(status.running);
  set_halted(status.halted);
  // Only set, never clear havereset
  if status.havereset then
    set_havereset(true);


  // NOTE: Is resumeack at some point cleared? Besides sending a resumereeq
  //if status.halted & halted then {
  //  set_resumeack(false);
 // };

 // Set resumeack when hart successfully resumes
    if running & status.running then {
      set_resumeack(true);
    };

  assert((halted & not(running)) | (not(halted) & running), "Hart cannot be both halted and running at the same time");
}

bitfield Hartinfo : bits(32) = {
  nscratch:   23 .. 20,
  dataaccess: 16,
  datasize:   15 .. 12,
  dataaddr:   11 .. 0
}

function initial_hartinfo() -> Hartinfo = {
  [Mk_Hartinfo(zeros()) with
    nscratch   = zeros(),
    dataaccess = zeros(),
    datasize   = zeros(),
    dataaddr   = zeros(),
  ]
}

register hartinfo: Hartinfo = initial_hartinfo()

mapping clause debug_module_reg_name_map = 0x12  <-> "hartinfo"

function clause is_debug_module_reg_defined (0x12) = true
function clause write_debug_module_reg(0x12, value) = ()
function clause read_debug_module_reg(0x12) = hartinfo.bits

bitfield Haltsum1 : bits(32) = {
  haltsum1: 31 .. 0
}

register haltsum1: Haltsum1 = Mk_Haltsum1(zeros())

mapping clause debug_module_reg_name_map = 0x13  <-> "haltsum1"

function clause is_debug_module_reg_defined (0x13) = false

function clause write_debug_module_reg(0x13, value) = ()

function clause read_debug_module_reg(0x13) = haltsum1.bits

bitfield Hawindowsel : bits(32) = {
  hawindowsel : 14 ..0,
}

register hawindowsel: Hawindowsel = Mk_Hawindowsel(zeros())

mapping clause debug_module_reg_name_map = 0x14  <-> "hawindowsel"

// Optional Register
function clause is_debug_module_reg_defined (0x14) = false
function clause write_debug_module_reg(0x14, value) = ()
function clause read_debug_module_reg(0x14) = hawindowsel.bits

bitfield Hawindow : bits(32) = {
  maskdata : 31 ..0,
}

function legalize_hawindow(d : Hawindow, x : bits(32)) -> Hawindow = {
  let x = Mk_Hawindow(x);

  [d with
    // Currently, we only support one hart
    maskdata = zeros()
  ]
}
register hawindow: Hawindow = legalize_hawindow(Mk_Hawindow(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x15  <-> "hawindow"

function clause is_debug_module_reg_defined (0x15) = true
function clause write_debug_module_reg(0x15, value) = { hawindow = legalize_hawindow(hawindow, value); }
function clause read_debug_module_reg(0x15) = hawindow.bits

bitfield Confstrptr0 : bits(32) = {
  addr : 31 .. 0
}

function initial_confstrptr0() -> Confstrptr0 = {
  [Mk_Confstrptr0(zeros()) with
    // TODO
    // NOTE: Part of System Bus Access
    addr = zeros()
  ]
}

register confstrptr0: Confstrptr0 = initial_confstrptr0()

mapping clause debug_module_reg_name_map = 0x19  <-> "confstrptr0"

function clause is_debug_module_reg_defined (0x19) = true
function clause write_debug_module_reg(0x19, value) = ()
function clause read_debug_module_reg(0x19) = confstrptr0.bits


bitfield Confstrptr1 : bits(32) = {
  addr: 31 .. 0
}

function initial_confstrptr1() -> Confstrptr1 = {
  [Mk_Confstrptr1(zeros()) with
    // TODO
    // NOTE: Part of System Bus Access
    addr = zeros(),
  ]
}

register confstrptr1: Confstrptr1 = initial_confstrptr1()

mapping clause debug_module_reg_name_map = 0x1a  <-> "confstrptr1"

function clause is_debug_module_reg_defined (0x1a) = true
// Read Only Register
function clause write_debug_module_reg(0x1a, value) = ()
function clause read_debug_module_reg(0x1a) = confstrptr1.bits

bitfield Confstrptr2 : bits(32) = {
  addr: 31 .. 0
}

function initial_confstrptr2() -> Confstrptr2 = {
  [Mk_Confstrptr2(zeros()) with
    addr = zeros(),
  ]
}

register confstrptr2: Confstrptr2 = initial_confstrptr2()

mapping clause debug_module_reg_name_map = 0x1b  <-> "confstrptr2"

function clause is_debug_module_reg_defined (0x1b) = true
// Read Only Register
function clause write_debug_module_reg(0x1b, value) = ()
function clause read_debug_module_reg(0x1b) = confstrptr2.bits

bitfield Confstrptr3 : bits(32) = {
  addr: 31 .. 0
}

function initial_confstrptr3() -> Confstrptr3 = {
  [Mk_Confstrptr3(zeros()) with
    // TODO
    // NOTE: Part of System Bus Access
    addr = zeros(),
  ]
}

register confstrptr3: Confstrptr3 = initial_confstrptr3()

mapping clause debug_module_reg_name_map = 0x1c  <-> "confstrptr3"

function clause is_debug_module_reg_defined (0x1c) = true
// Read Only Register
function clause write_debug_module_reg(0x1c, value) = ()
function clause read_debug_module_reg(0x1c) = confstrptr3.bits

bitfield Nextdm : bits(32) = {
  addr: 31 .. 0
}

function initial_nextdm() -> Nextdm = {
  [Mk_Nextdm(zeros()) with
    addr = zeros(),
  ]
}

register nextdm: Nextdm = initial_nextdm()

mapping clause debug_module_reg_name_map = 0x1d  <-> "nextdm"

function clause is_debug_module_reg_defined (0x1d) = true

function clause write_debug_module_reg(0x1d, value) = ()

function clause read_debug_module_reg(0x1d) = nextdm.bits

// Program buffer registers, initialized with EBREAK (0x00100073)
// Ensures the hart safely exits debug mode even if the program buffer
// is not fully populated by the debugger
// TODO: Reinitialize after reset
register progbuf_regs : vector(16, bits(32)) = vector_init(EBREAK_INSTRUCTION)

mapping clause debug_module_reg_name_map = 0x20  <-> "progbuf0"
mapping clause debug_module_reg_name_map = 0x21  <-> "progbuf1"
mapping clause debug_module_reg_name_map = 0x22  <-> "progbuf2"
mapping clause debug_module_reg_name_map = 0x23  <-> "progbuf3"
mapping clause debug_module_reg_name_map = 0x24  <-> "progbuf4"
mapping clause debug_module_reg_name_map = 0x25  <-> "progbuf5"
mapping clause debug_module_reg_name_map = 0x26  <-> "progbuf6"
mapping clause debug_module_reg_name_map = 0x27  <-> "progbuf7"
mapping clause debug_module_reg_name_map = 0x28  <-> "progbuf8"
mapping clause debug_module_reg_name_map = 0x29  <-> "progbuf9"
mapping clause debug_module_reg_name_map = 0x2a  <-> "progbuf10"
mapping clause debug_module_reg_name_map = 0x2b  <-> "progbuf11"
mapping clause debug_module_reg_name_map = 0x2c  <-> "progbuf12"
mapping clause debug_module_reg_name_map = 0x2d  <-> "progbuf13"
mapping clause debug_module_reg_name_map = 0x2e  <-> "progbuf14"
mapping clause debug_module_reg_name_map = 0x2f  <-> "progbuf15"

// Single clause with guard for the range 0x20-0x2f
function clause is_debug_module_reg_defined((addr) if 0x20 <=_u addr & addr <=_u 0x2f) = {
  unsigned(abstractcs[progbufsize]) > unsigned(addr - 0x20)
}

function clause write_debug_module_reg((addr, value) if 0x20 <=_u addr & addr <=_u 0x2f) = {
  let idx = unsigned(addr - 0x20);
  assert(idx <= 15);
  progbuf_regs[idx] = handle_register_access(progbuf_regs[idx], value, true);
  trigger_abstractauto_if_enabled(abstractauto[autoexecprogbuf][idx]);
}

function clause read_debug_module_reg((addr) if 0x20 <=_u addr & addr <=_u 0x2f) = {
  let idx  = unsigned(addr - 0x20);
  assert(idx <= 15);
  let _ = handle_register_access(progbuf_regs[idx], zeros(), false);
  trigger_abstractauto_if_enabled(abstractauto[autoexecprogbuf][idx]);
  progbuf_regs[idx]
}

bitfield Authdata : bits(32) = {
  data: 31 .. 0
}

function legalize_authdata(d : Authdata, x : bits(32)) -> Authdata = Mk_Authdata(x)

register authdata: Authdata = legalize_authdata(Mk_Authdata(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x30  <-> "authdata"

function clause is_debug_module_reg_defined (0x30) = true
function clause write_debug_module_reg(0x30, value) = { authdata = legalize_authdata(authdata, value); }
function clause read_debug_module_reg(0x30) = authdata.bits

bitfield Dmcs2 : bits(32) = {
  grouptype:    1,
  dmexttrigger: 10 .. 7,
  group:        6  .. 2,
  hgwrite:      1,
  hgselect:     0
}

function legalize_dmcs2(d : Dmcs2, x : bits(32)) -> Dmcs2 = {
  let x = Mk_Dmcs2(x);
  [d with
    grouptype = x[grouptype],
    dmexttrigger = x[dmexttrigger],
    // TODO: Can be preset
    group = x[group],
    hgwrite = 0b0,
    hgselect = 0b0
  ]
}
register dmcs2: Dmcs2 = legalize_dmcs2(Mk_Dmcs2(zeros()), zeros())
mapping clause debug_module_reg_name_map = 0x32  <-> "dmcs2"
function clause is_debug_module_reg_defined (0x32) = true
function clause write_debug_module_reg(0x32, value) = { dmcs2 = legalize_dmcs2(dmcs2, value); }
function clause read_debug_module_reg(0x32) = dmcs2.bits

bitfield Haltsum2 : bits(32) = {
  haltsum2: 31 .. 0
}

register haltsum2: Haltsum2 = Mk_Haltsum2(zeros())

mapping clause debug_module_reg_name_map = 0x34  <-> "haltsum2"

function clause is_debug_module_reg_defined (0x34) = false

function clause write_debug_module_reg(0x34, value) = ()

function clause read_debug_module_reg(0x34) = haltsum2.bits

bitfield Haltsum3 : bits(32) = {
  haltsum3: 31 .. 0
}

register haltsum3: Haltsum3 = Mk_Haltsum3(zeros())

mapping clause debug_module_reg_name_map = 0x35  <-> "haltsum3"

function clause is_debug_module_reg_defined (0x35) = false

function clause write_debug_module_reg(0x35, value) = ()

function clause read_debug_module_reg(0x35) = haltsum3.bits

bitfield Sbcs : bits(32) = {
  sbversion:       31 .. 29,
  sbbusyerror:     22,
  sbbusy:          21,
  sbreadonaddr:    20,
  sbaccess:        19 .. 17,
  sbautoincrement: 16,
  sbreadondata:    15,
  sberror:         14 .. 12,
  sbasize:         11 .. 5,
  sbaccess128:     4,
  sbaccess64:      3,
  sbaccess32:      2,
  sbaccess16:      1,
  sbaccess8 :      0
}

function legalize_sbcs(d : Sbcs, x : bits(32)) -> Sbcs = {
  let x = Mk_Sbcs(x);
  [d with
    sbversion       = 0b001,
    sbbusyerror     = if x[sbbusyerror] == ones() then zeros() else d[sbbusyerror], // R/W1C
    sbreadonaddr    = x[sbreadonaddr],
    sbaccess        = x[sbaccess],
    sbautoincrement = x[sbautoincrement],
    sberror         = if x[sberror] == ones() then zeros() else d[sberror], // R/W1C
    // TODO: No system bus access support yet
    sbasize     = zeros(),
    sbaccess128 = 0b0,
    sbaccess64  = 0b0,
    sbaccess32  = 0b0,
    sbaccess16  = 0b0,
    sbaccess8   = 0b0
  ]
}

register sbcs: Sbcs = legalize_sbcs(Mk_Sbcs(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x38  <-> "sbcs"

function clause is_debug_module_reg_defined (0x38) = true
function clause write_debug_module_reg(0x38, value) = { sbcs = legalize_sbcs(sbcs, value); }
function clause read_debug_module_reg(0x38) = sbcs.bits

bitfield Sbaddress0 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddress0(d : Sbaddress0, x : bits(32)) -> Sbaddress0 = {
  let x = Mk_Sbaddress0(x);
  [d with
    address = x[address]
  ]
}

register sbaddress0: Sbaddress0 = legalize_sbaddress0(Mk_Sbaddress0(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x39  <-> "sbaddress0"

function clause is_debug_module_reg_defined (0x39) = sbcs[sbasize] != zeros()
function clause write_debug_module_reg(0x39, value) = { sbaddress0 = legalize_sbaddress0(sbaddress0, value); }
function clause read_debug_module_reg(0x39) = sbaddress0.bits

bitfield Sbaddress1 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddress1(d : Sbaddress1, x : bits(32)) -> Sbaddress1 = {
  let x = Mk_Sbaddress1(x);
  [d with
    address = x[address]
  ]
}

register sbaddress1: Sbaddress1 = legalize_sbaddress1(Mk_Sbaddress1(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x3a  <-> "sbaddress1"

function clause is_debug_module_reg_defined (0x3a) = unsigned(sbcs[sbasize]) >= 33
function clause write_debug_module_reg(0x3a, value) = { sbaddress1 = legalize_sbaddress1(sbaddress1, value); }
function clause read_debug_module_reg(0x3a) = sbaddress1.bits

bitfield Sbaddress2 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddress2(d : Sbaddress2, x : bits(32)) -> Sbaddress2 = {
  let x = Mk_Sbaddress2(x);
  [d with
    address = x[address]
  ]
}

register sbaddress2: Sbaddress2 = legalize_sbaddress2(Mk_Sbaddress2(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x3b  <-> "sbaddress2"

function clause is_debug_module_reg_defined (0x3b) = unsigned(sbcs[sbasize]) >= 65
function clause write_debug_module_reg(0x3b, value) = { sbaddress2 = legalize_sbaddress2(sbaddress2, value); }
function clause read_debug_module_reg(0x3b) = sbaddress2.bits

bitfield Sbaddress3 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddress3(d : Sbaddress3, x : bits(32)) -> Sbaddress3 = {
  let x = Mk_Sbaddress3(x);
  [d with
    address = x[address]
  ]
}

register sbaddress3: Sbaddress3 = legalize_sbaddress3(Mk_Sbaddress3(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x37  <-> "sbaddress3"

function clause is_debug_module_reg_defined (0x37) = unsigned(sbcs[sbasize]) >= 97
function clause write_debug_module_reg(0x37, value) = { sbaddress3 = legalize_sbaddress3(sbaddress3, value); }
function clause read_debug_module_reg(0x37) = sbaddress3.bits

bitfield Sbdata0 : bits(32) = {
  data: 31 .. 0
}

function legalize_sbdata0(d : Sbdata0, x : bits(32)) -> Sbdata0 = {
  let x = Mk_Sbdata0(x);
  [d with
    data = x[data]
  ]
}

register sbdata0: Sbdata0 = legalize_sbdata0(Mk_Sbdata0(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x3c  <-> "sbdata0"

function clause is_debug_module_reg_defined (0x3c) = sbcs[sbaccess] != zeros()
function clause write_debug_module_reg(0x3c, value) = { sbdata0 = legalize_sbdata0(sbdata0, value); }
function clause read_debug_module_reg(0x3c) = sbdata0.bits

bitfield Sbdata1 : bits(32) = {
  data: 31 .. 0
}

function legalize_sbdata1(d : Sbdata1, x : bits(32)) -> Sbdata1 = {
  let x = Mk_Sbdata1(x);
  [d with
    data = x[data]
  ]
}

register sbdata1: Sbdata1 = legalize_sbdata1(Mk_Sbdata1(zeros()), zeros())
mapping clause debug_module_reg_name_map = 0x3d  <-> "sbdata1"
function clause is_debug_module_reg_defined (0x3d) = sbcs[sbaccess64] == 0b1 | sbcs[sbaccess128] == 0b1
function clause write_debug_module_reg(0x3d, value) = { sbdata1 = legalize_sbdata1(sbdata1, value); }
function clause read_debug_module_reg(0x3d) = sbdata1.bits

bitfield Sbdata2 : bits(32) = {
  data: 31 .. 0
}

function legalize_sbdata2(d : Sbdata2, x : bits(32)) -> Sbdata2 = {
  let x = Mk_Sbdata2(x);
  [d with
    data = x[data]
  ]
}

register sbdata2: Sbdata2 = legalize_sbdata2(Mk_Sbdata2(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x3e  <-> "sbdata2"

function clause is_debug_module_reg_defined (0x3e) = sbcs[sbaccess128] == 0b1
function clause write_debug_module_reg(0x3e, value) = { sbdata2 = legalize_sbdata2(sbdata2, value); }
function clause read_debug_module_reg(0x3e) = sbdata2.bits

bitfield Sbdata3 : bits(32) = {
  data: 31 .. 0
}

function legalize_sbdata3(d : Sbdata3, x : bits(32)) -> Sbdata3 = {
  let x = Mk_Sbdata3(x);
  [d with
    data = x[data]
  ]
}

register sbdata3: Sbdata3 = legalize_sbdata3(Mk_Sbdata3(zeros()), zeros())

mapping clause debug_module_reg_name_map = 0x3f  <-> "sbdata3"

function clause is_debug_module_reg_defined (0x3f) = sbcs[sbaccess128] == 0b1
function clause write_debug_module_reg(0x3f, value) = { sbdata3 = legalize_sbdata3(sbdata3, value); }
function clause read_debug_module_reg(0x3f) = sbdata3.bits

bitfield Haltsum0 : bits(32) = {
  haltsum0: 31 .. 0
}

register haltsum0: Haltsum0 = Mk_Haltsum0(zeros())

mapping clause debug_module_reg_name_map = 0x40  <-> "haltsum0"

function clause is_debug_module_reg_defined (0x40) = true

function clause write_debug_module_reg(0x40, value) = ()

function clause read_debug_module_reg(0x40) = zeros(31) @ dmstatus[allhalted]

// terminate scattered definitions

mapping clause debug_module_reg_name_map = reg <-> hex_bits_8(reg)
end debug_module_reg_name_map

function clause is_debug_module_reg_defined(_) = false
end is_debug_module_reg_defined

function clause read_debug_module_reg(addr) = {
   // This should be impossible because is_debug_module_reg_defined() should have returned false.
   internal_error(__FILE__, __LINE__, "Read from Debug Module Register that does not exist: " ^ bits_str(addr));
}
end read_debug_module_reg

function clause write_debug_module_reg(addr, _) = {
   // This should be impossible because is_debug_module_reg_defined() should have returned false.
   internal_error(__FILE__, __LINE__, "Write to Debug Module Register that does not exist: " ^ bits_str(addr));
}
end write_debug_module_reg

function reset_debug_module() = {
  if get_config_print_debug()
  then print_log("Reset Debug Module");
  // Behavior is undefined if a hart is halted when the
  // debug module resets. For now, we check if the hart
  // is halted and issue a resume request.
  if halted then send_debug_request(Resume());

  progbuf_regs = vector_init(EBREAK_INSTRUCTION);

  haltrequest = false;
  resumeack   = false;
  hartreset   = false;
  haltonreset = false;
  //unavail      = false;
  //keepalive    = false;

  // NOTE: We dont set anyrunning or allrunning yet
  // TODO: Check if we can just call initialize_dmstatus()
  dmstatus = [Mk_Dmstatus(zeros()) with
    impebreak       = if unsigned(MAX_PROGBUF_SIZE) == 1 | (config platform.debug_module.impebreak : bool) then 0b1 else 0b0,
    authenticated   = 0b1,
    authbusy        = 0b0,
    hasresethaltreq = 0b1,
    version         = 0b0011,
  ];

  dmcontrol.bits = zeros();

  hawindowsel.bits = zeros();

  abstractcs = [Mk_Abstractcs(zeros()) with
    progbufsize = MAX_PROGBUF_SIZE,
    busy        = 0b0,
    relaxedpriv = 0b1,
    cmderr      = zeros(),
    datacount   = MAX_DATA_SIZE,
  ];

  command.bits = zeros();

  abstractauto = [Mk_Abstractauto(zeros()) with
    autoexecprogbuf = zeros(),
    autoexecdata    = zeros(),
  ];

  dmcs2 = [Mk_Dmcs2(zeros()) with
    grouptype    = zeros(),
    dmexttrigger = zeros(),
    group        = zeros(),
    hgselect     = zeros(),
  ];

  sbcs = [Mk_Sbcs(zeros()) with
    sbversion = 0b001,
    sbaccess  = 0b010,
    sbasize   = zeros(),
  ];

  sbaddress0.bits = zeros();
  sbaddress1.bits = zeros();
  sbaddress2.bits = zeros();
  sbaddress3.bits = zeros();

  sbdata0.bits = zeros();
  sbdata1.bits = zeros();
  sbdata2.bits = zeros();
  sbdata3.bits = zeros();
}
