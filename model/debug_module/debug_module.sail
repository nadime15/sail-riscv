/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

/* Mapping of Debug Module Register addresses to their names. */
val dm_name_map : dmreg <-> string

// Forward declaration so the implementation can be
// defined after all registers have been declared
val reset_debug_module : unit -> unit

// initialize scattered definitions

scattered mapping dm_name_map

val dm_name : dmreg -> string
function dm_name(dm_reg) = dm_name_map(dm_reg)

overload to_str = {dm_name}

/* Returns whether a Debug Module Register exists */
val is_DM_reg_defined : (dmreg) -> bool
scattered function is_DM_reg_defined

/* Returns the value of the Debug Module Register if it is defined */
val read_DM_reg : dmreg -> bits(32)
scattered function read_DM_reg

/* if the Debug Module Register is defined, writes the legalized value to it */
val write_DM_reg : (dmreg, bits(32)) -> unit
scattered function write_DM_reg

///////////////////////////////////////////////////////////////////////

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
    relaxedpriv = 0b1,
    cmderr      = if x[cmderr] == ones() then zeros() else x[cmderr], // R/W1C
    datacount   = MAX_DATA_SIZE,
  ]
}

register abstractcs: Abstractcs = legalize_abstractcs(Mk_Abstractcs(zeros()), zeros())

mapping clause dm_name_map = 0x16  <-> "abstractcs"

function clause is_DM_reg_defined (0x16) = true
function clause write_DM_reg(0x16, value) = { abstractcs = legalize_abstractcs(abstractcs, value); }
function clause read_DM_reg(0x16) = abstractcs.bits

function legalize_data(d: bits(32), x : bits(32)) -> bits(32) = {
  if abstractcs[busy] == 0b1 then {
    abstractcs[cmderr] = abstract_command_error(BUSY);
    d
  }
  else {
    x
  }
}

register data0  : bits(32)
register data1  : bits(32)
register data2  : bits(32)
register data3  : bits(32)
register data4  : bits(32)
register data5  : bits(32)
register data6  : bits(32)
register data7  : bits(32)
register data8  : bits(32)
register data9  : bits(32)
register data10 : bits(32)
register data11 : bits(32)

mapping clause dm_name_map = 0x04  <-> "data0"
mapping clause dm_name_map = 0x05  <-> "data1"
mapping clause dm_name_map = 0x06  <-> "data2"
mapping clause dm_name_map = 0x07  <-> "data3"
mapping clause dm_name_map = 0x08  <-> "data4"
mapping clause dm_name_map = 0x09  <-> "data5"
mapping clause dm_name_map = 0x0a  <-> "data6"
mapping clause dm_name_map = 0x0b  <-> "data7"
mapping clause dm_name_map = 0x0c  <-> "data8"
mapping clause dm_name_map = 0x0d  <-> "data9"
mapping clause dm_name_map = 0x0e  <-> "data10"
mapping clause dm_name_map = 0x0f  <-> "data11"

function clause is_DM_reg_defined (0x04) = unsigned(abstractcs[datacount]) > 0
function clause is_DM_reg_defined (0x05) = unsigned(abstractcs[datacount]) > 1
function clause is_DM_reg_defined (0x06) = unsigned(abstractcs[datacount]) > 2
function clause is_DM_reg_defined (0x07) = unsigned(abstractcs[datacount]) > 3
function clause is_DM_reg_defined (0x08) = unsigned(abstractcs[datacount]) > 4
function clause is_DM_reg_defined (0x09) = unsigned(abstractcs[datacount]) > 5
function clause is_DM_reg_defined (0x0a) = unsigned(abstractcs[datacount]) > 6
function clause is_DM_reg_defined (0x0b) = unsigned(abstractcs[datacount]) > 7
function clause is_DM_reg_defined (0x0c) = unsigned(abstractcs[datacount]) > 8
function clause is_DM_reg_defined (0x0d) = unsigned(abstractcs[datacount]) > 9
function clause is_DM_reg_defined (0x0e) = unsigned(abstractcs[datacount]) > 10
function clause is_DM_reg_defined (0x0f) = unsigned(abstractcs[datacount]) > 11

function clause write_DM_reg(0x04, value) = { data0 = legalize_data(data0, value); }
function clause write_DM_reg(0x05, value) = { data1 = legalize_data(data1, value); }
function clause write_DM_reg(0x06, value) = { data2 = legalize_data(data2, value); }
function clause write_DM_reg(0x07, value) = { data4 = legalize_data(data3, value); }
function clause write_DM_reg(0x08, value) = { data4 = legalize_data(data4, value); }
function clause write_DM_reg(0x09, value) = { data5 = legalize_data(data5, value); }
function clause write_DM_reg(0x0a, value) = { data6 = legalize_data(data6, value); }
function clause write_DM_reg(0x0b, value) = { data7 = legalize_data(data7, value); }
function clause write_DM_reg(0x0c, value) = { data8 = legalize_data(data8, value); }
function clause write_DM_reg(0x0d, value) = { data9 = legalize_data(data9, value); }
function clause write_DM_reg(0x0e, value) = { data10 = legalize_data(data10, value); }
function clause write_DM_reg(0x0f, value) = { data11 = legalize_data(data11, value); }


function clause read_DM_reg(0x04) = data0
function clause read_DM_reg(0x05) = data1
function clause read_DM_reg(0x06) = data2
function clause read_DM_reg(0x07) = data3
function clause read_DM_reg(0x08) = data4
function clause read_DM_reg(0x09) = data5
function clause read_DM_reg(0x0a) = data6
function clause read_DM_reg(0x0b) = data7
function clause read_DM_reg(0x0c) = data8
function clause read_DM_reg(0x0d) = data9
function clause read_DM_reg(0x0e) = data10
function clause read_DM_reg(0x0f) = data11

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

mapping clause dm_name_map = 0x11  <-> "dmstatus"

function clause is_DM_reg_defined (0x11) = true
function clause write_DM_reg(0x11, value) = ()
function clause read_DM_reg(0x11) = dmstatus.bits

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
  let x = if abstractcs[busy] == 0b1 then [x with
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
        set_resumeack(true);
      };
    },

    // Fallback
    _ => (),
  };

  [d with
    // Control bits - preserve written values for pulse-type operations
    haltreq         = if abstractcs[busy] != 0b1 then x[haltreq] else d[haltreq],
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

mapping clause dm_name_map = 0x10  <-> "dmcontrol"

function clause is_DM_reg_defined (0x10) = true
function clause write_DM_reg(0x10, value) = { dmcontrol = legalize_dmcontrol(dmcontrol, value); }
function clause read_DM_reg(0x10) = dmcontrol.bits

function send_hart_status(status : debug_module_hart_status) -> unit = {
  set_running(status.running);
  set_halted(status.halted);
  set_havereset(status.havereset);

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

mapping clause dm_name_map = 0x12  <-> "hartinfo"

function clause is_DM_reg_defined (0x12) = true
function clause write_DM_reg(0x12, value) = ()
function clause read_DM_reg(0x12) = hartinfo.bits

bitfield Haltsum1 : bits(32) = {
  haltsum1: 31 .. 0
}

function legalize_haltsum1(d : Haltsum1, x : bits(32)) -> Haltsum1 = {
  let x = Mk_Haltsum1(x);
  [d with
    // TODO
    haltsum1 = zeros(),
  ]
}
register haltsum1: Haltsum1 = legalize_haltsum1(Mk_Haltsum1(zeros()), zeros())
mapping clause dm_name_map = 0x13  <-> "haltsum1"
function clause is_DM_reg_defined (0x13) = true
// Read Only Register
function clause read_DM_reg(0x13) = haltsum1.bits

bitfield Hawindowsel : bits(32) = {
  hawindowsel : 14 ..0,
}

function legalize_hawindowsel(d : Hawindowsel, x : bits(32)) -> Hawindowsel = {
  let x = Mk_Hawindowsel(x);

  [d with
    // Currently, we only support one hart
    hawindowsel = zeros(),
  ]
}

register hawindowsel: Hawindowsel = legalize_hawindowsel(Mk_Hawindowsel(zeros()), zeros())

mapping clause dm_name_map = 0x14  <-> "hawindowsel"

// Optional Register
function clause is_DM_reg_defined (0x14) = false
function clause write_DM_reg(0x14, value) = { hawindowsel = legalize_hawindowsel(hawindowsel, value); }
function clause read_DM_reg(0x14) = hawindowsel.bits

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

mapping clause dm_name_map = 0x15  <-> "hawindow"

function clause is_DM_reg_defined (0x15) = true
function clause write_DM_reg(0x15, value) = { hawindow = legalize_hawindow(hawindow, value); }
function clause read_DM_reg(0x15) = hawindow.bits

bitfield Command : bits(32) = {
  cmdtype: 31 .. 24,
  control: 23 .. 0
}

function write_data_regs(value: bits(128), aarsize: range(2, 4)) -> unit = {
   match aarsize {
    2 => data0 = value[31..0],
    3 => { data0 = value[31..0];  data1 = value[63..32]; },
    4 => { data0 = value[31..0];  data1 = value[63..32];
           data2 = value[95..64]; data3 = value[127..96]; },
  }
}

function read_data_regs(aarsize: range(2, 4)) -> bits(128) = {
  match aarsize {
    2 => zeros() @ data0,
    3 => zeros() @ data1 @ data0,
    4 => data3 @ data2 @ data1 @ data0,
  }
}

function write_gpr(regidx: regidx, aarsize: range(2, 4)) -> AbstractCommandError = {
  let value = read_data_regs(aarsize);
  match (aarsize, xlen) {
    (2, 32) => { X(regidx) = value[31..0]; NONE },
    (2, 64) => { X(regidx) = zeros() @ value[31..0]; NONE },
    (3, 64) => { X(regidx) = value[63..0]; NONE },
    (_, _)  => NOT_SUPPORTED,
  }
}

function write_fpr(fregidx: fregidx, aarsize: range(2, 4)) -> AbstractCommandError = {
  let value = read_data_regs(aarsize);
  match (aarsize, flen) {
    (2, 32) => { F(fregidx) = value[31..0]; NONE },
    (2, 64) => { F(fregidx) = zeros() @ value[31..0]; NONE },
    (3, 64) => { F(fregidx) = value[63..0]; NONE },
    (_, _)  => NOT_SUPPORTED,
  }
}

function execute_access_register_command(aarsize : bits(3), transfer : bits(1), write : bits(1), regno : bits (16)) -> AbstractCommandError = {
  let access = determine_access_type(write, transfer);
  if access == NO_TRANSFER then return NONE;

  let addr = unsigned(regno);
  let aarsize = unsigned(aarsize);

  if not(1 < aarsize & aarsize < 5) then return NOT_SUPPORTED;

  assert(1 < aarsize & aarsize < 5);

  // NOTE: In theory, we should check whether a register access exceeds the specified aarize value.
  // If it does, the access must fail. The problem is that all CSRs return xlenbits and are
  // zero-extended, so there is no reliable way to distinguish between 32-bit and 64-bit CSRs without
  // additional metadata (e.g., a list tracking register sizes). For now, we allow access to CSRs
  // smaller than aarize, even though this does not fully comply with the spec.
  match addr {
    addr if addr <= unsigned(0x0fff) => {
      // TODO: Ensure CSR access is performed in M-Mode.
      if not(is_CSR_accessible(regno[11 .. 0], Machine, true)) then return EXCEPTION;
      match access {
        READ => write_data_regs(zeros() @ read_CSR(regno[11 .. 0]), aarsize),
        WRITE => {
          let value = read_data_regs(aarsize);
          match write_CSR(regno[11 .. 0], value[xlen - 1 ..  0]) {
            Ok (_) => (),
            Err(_) => return EXCEPTION,
          }
        },
      }
    },
    addr if addr <= unsigned(0x101f) => {
      let regidx = encdec_reg(regno[4 .. 0]);
      if base_E_enabled & unsigned(regno[4 .. 0]) > 15 then return EXCEPTION;
      match access {
        // TODO: Get rid of the zeros()
        READ  => write_data_regs(zeros() @ X(regidx), aarsize),
        WRITE => {let status = write_gpr(regidx, aarsize); return status },
      };
    },
    addr if addr <= unsigned(0x103f) => {
      if mstatus[FS] == 0b00 then return EXCEPTION;
      let fregidx = encdec_freg(regno[4 .. 0]);
      match access {
        READ  => write_data_regs(zeros () @ F(fregidx), aarsize),
        WRITE => { let status = write_fpr(fregidx, aarsize); return status },
      };
    },
    addr => return EXCEPTION
  };
  NONE
}

function execute_abstract_command(command : bits(32)) -> AbstractCommandError = {
  let cmdtype = command[31 .. 24];
  let hart_exists = dmstatus[allnonexistent] == 0b0;
  let hart_available = dmstatus[allunavail] == 0b0;
  let abstract_command_busy = abstractcs[busy] == 0b1;

  let status =
    if not(hart_available) | not(hart_exists) then {
      abstractcs[busy] = 0b0;
      HALT_RESUME
    }
    else if abstract_command_busy then {if abstractcs[cmderr] == abstract_command_error(NONE) then BUSY else NONE}
    else match abstract_command_type(cmdtype) {
      ACCESS_REGISTER => {
        let aarsize          = command[22 .. 20];
        let reserved         = command[23 .. 23];
        let aarpostincrement = command[19 .. 19];
        let postexec         = command[18 .. 18];
        let transfer         = command[17 .. 17];
        let write            = command[16 .. 16];
        let regno            = command[15 .. 0];
        var error = NONE;
        // NOTE: aarpostincrement
        if reserved == 0b1 | aarpostincrement == 0b1 then {
          error = NOT_SUPPORTED;
        } else {
          abstractcs[busy] = 0b1;
          error = execute_access_register_command(aarsize, transfer, write, regno);

          if postexec == 0b1 then {
            if not(config platform.debug_module.program_buffer.supported : bool) then {
              abstractcs[busy] = 0b0;
              error = NOT_SUPPORTED;
            } else {
              // Hart must be halted to execute program buffer (implementation dependent)
              if dmstatus[allhalted] == 0b0 then {
                abstractcs[busy] = 0b0;
                error = HALT_RESUME;
              } else {
                send_debug_request(ExecuteProgramBuffer(false));
                // Hart sets potential error and busy
              };
            }
          } else {
            abstractcs[busy] = 0b0;
          }
        };
        error
      },
      QUICK_ACCESS  => {
        // Check if any reserved bits are set in command[23:0]
        if command[23 .. 0] != zeros() then {
          NOT_SUPPORTED
        } else if dmstatus[allhalted] != 0b1 then {
          // All harts must be halted before quick access
          HALT_RESUME
        } else {
          // Execute program buffer and return success
          send_debug_request(ExecuteProgramBuffer(true));
          NONE
        }
      },
      ACCESS_MEMORY => NOT_SUPPORTED,
    };
  status
}

function legalize_command(d : Command, x : bits(32)) -> unit = {
  abstractcs[cmderr] = abstract_command_error(execute_abstract_command(x))
}

register command: Command = Mk_Command(zeros())

mapping clause dm_name_map = 0x17  <-> "command"

function clause is_DM_reg_defined (0x17) = true
function clause write_DM_reg(0x17, value) = { legalize_command(command, value); }
function clause read_DM_reg(0x17) = zeros()

bitfield Abstractauto : bits(32) = {
  autoexecprogbuf: 31 .. 16,
  autoexecdata:    11 ..  0,
}

function legalize_abstractauto(d : Abstractauto, x : bits(32)) -> Abstractauto = {
  let x = Mk_Abstractauto(x);
  // TODO
  [d with
    autoexecdata = zeros(),
    autoexecdata = zeros(),
  ]
}

register abstractauto: Abstractauto = legalize_abstractauto(Mk_Abstractauto(zeros()), zeros())

mapping clause dm_name_map = 0x18  <-> "abstractauto"

// Optional Register
function clause is_DM_reg_defined (0x18) = false
function clause write_DM_reg(0x18, value) = { abstractauto = legalize_abstractauto(abstractauto, value); }
function clause read_DM_reg(0x18) = abstractauto.bits

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

mapping clause dm_name_map = 0x19  <-> "confstrptr0"

function clause is_DM_reg_defined (0x19) = true
// Read Only Register
function clause read_DM_reg(0x19) = confstrptr0.bits


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

mapping clause dm_name_map = 0x1a  <-> "confstrptr1"

function clause is_DM_reg_defined (0x1a) = true
// Read Only Register
function clause read_DM_reg(0x1a) = confstrptr1.bits

bitfield Confstrptr2 : bits(32) = {
  addr: 31 .. 0
}

function initial_confstrptr2() -> Confstrptr2 = {
  [Mk_Confstrptr2(zeros()) with
    addr = zeros(),
  ]
}

register confstrptr2: Confstrptr2 = initial_confstrptr2()

mapping clause dm_name_map = 0x1b  <-> "confstrptr2"

function clause is_DM_reg_defined (0x1b) = true
// Read Only Register
function clause read_DM_reg(0x1b) = confstrptr2.bits

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

mapping clause dm_name_map = 0x1c  <-> "confstrptr3"

function clause is_DM_reg_defined (0x1c) = true
// Read Only Register
function clause read_DM_reg(0x1c) = confstrptr3.bits

bitfield Nextdm : bits(32) = {
  addr: 31 .. 0
}

// NOT IMPLEMENTED
function initial_nextdm() -> Nextdm = {
  [Mk_Nextdm(zeros()) with
    addr = zeros(),
  ]
}

register nextdm: Nextdm = initial_nextdm()

mapping clause dm_name_map = 0x1d  <-> "nextdm"

function clause is_DM_reg_defined (0x1d) = true
// Read Only Register
function clause read_DM_reg(0x1d) = nextdm.bits

function legalize_progbuf(d: bits(32), x : bits(32)) -> bits(32) = {
  if abstractcs[busy] == 0b1 then {
    abstractcs[cmderr] = abstract_command_error(BUSY);
    d
  }
  else {
    x
  }
}

register progbuf0  : bits(32)
register progbuf1  : bits(32)
register progbuf2  : bits(32)
register progbuf3  : bits(32)
register progbuf4  : bits(32)
register progbuf5  : bits(32)
register progbuf6  : bits(32)
register progbuf7  : bits(32)
register progbuf8  : bits(32)
register progbuf9  : bits(32)
register progbuf10 : bits(32)
register progbuf11 : bits(32)
register progbuf12 : bits(32)
register progbuf13 : bits(32)
register progbuf14 : bits(32)
register progbuf15 : bits(32)

mapping clause dm_name_map = 0x20  <-> "progbuf0"
mapping clause dm_name_map = 0x21  <-> "progbuf1"
mapping clause dm_name_map = 0x22  <-> "progbuf2"
mapping clause dm_name_map = 0x23  <-> "progbuf3"
mapping clause dm_name_map = 0x24  <-> "progbuf4"
mapping clause dm_name_map = 0x25  <-> "progbuf5"
mapping clause dm_name_map = 0x26  <-> "progbuf6"
mapping clause dm_name_map = 0x27  <-> "progbuf7"
mapping clause dm_name_map = 0x28  <-> "progbuf8"
mapping clause dm_name_map = 0x29  <-> "progbuf9"
mapping clause dm_name_map = 0x2a  <-> "progbuf10"
mapping clause dm_name_map = 0x2b  <-> "progbuf11"
mapping clause dm_name_map = 0x2c  <-> "progbuf12"
mapping clause dm_name_map = 0x2d  <-> "progbuf13"
mapping clause dm_name_map = 0x2e  <-> "progbuf14"
mapping clause dm_name_map = 0x2f  <-> "progbuf15"

function clause is_DM_reg_defined (0x20) = unsigned(abstractcs[progbufsize]) > 0
function clause is_DM_reg_defined (0x21) = unsigned(abstractcs[progbufsize]) > 1
function clause is_DM_reg_defined (0x22) = unsigned(abstractcs[progbufsize]) > 2
function clause is_DM_reg_defined (0x23) = unsigned(abstractcs[progbufsize]) > 3
function clause is_DM_reg_defined (0x24) = unsigned(abstractcs[progbufsize]) > 4
function clause is_DM_reg_defined (0x25) = unsigned(abstractcs[progbufsize]) > 5
function clause is_DM_reg_defined (0x26) = unsigned(abstractcs[progbufsize]) > 6
function clause is_DM_reg_defined (0x27) = unsigned(abstractcs[progbufsize]) > 7
function clause is_DM_reg_defined (0x28) = unsigned(abstractcs[progbufsize]) > 8
function clause is_DM_reg_defined (0x29) = unsigned(abstractcs[progbufsize]) > 9
function clause is_DM_reg_defined (0x2a) = unsigned(abstractcs[progbufsize]) > 10
function clause is_DM_reg_defined (0x2b) = unsigned(abstractcs[progbufsize]) > 11
function clause is_DM_reg_defined (0x2c) = unsigned(abstractcs[progbufsize]) > 12
function clause is_DM_reg_defined (0x2d) = unsigned(abstractcs[progbufsize]) > 13
function clause is_DM_reg_defined (0x2e) = unsigned(abstractcs[progbufsize]) > 14
function clause is_DM_reg_defined (0x2f) = unsigned(abstractcs[progbufsize]) > 15

function clause write_DM_reg(0x20, value) = { progbuf0 = legalize_progbuf(progbuf0, value); }
function clause write_DM_reg(0x21, value) = { progbuf1 = legalize_progbuf(progbuf1, value); }
function clause write_DM_reg(0x22, value) = { progbuf2 = legalize_progbuf(progbuf2, value); }
function clause write_DM_reg(0x23, value) = { progbuf3 = legalize_progbuf(progbuf3, value); }
function clause write_DM_reg(0x24, value) = { progbuf4 = legalize_progbuf(progbuf4, value); }
function clause write_DM_reg(0x25, value) = { progbuf5 = legalize_progbuf(progbuf5, value); }
function clause write_DM_reg(0x26, value) = { progbuf6 = legalize_progbuf(progbuf6, value); }
function clause write_DM_reg(0x27, value) = { progbuf7 = legalize_progbuf(progbuf7, value); }
function clause write_DM_reg(0x28, value) = { progbuf8 = legalize_progbuf(progbuf8, value); }
function clause write_DM_reg(0x29, value) = { progbuf9 = legalize_progbuf(progbuf9, value); }
function clause write_DM_reg(0x2a, value) = { progbuf10 = legalize_progbuf(progbuf10, value); }
function clause write_DM_reg(0x2b, value) = { progbuf11 = legalize_progbuf(progbuf11, value); }
function clause write_DM_reg(0x2c, value) = { progbuf12 = legalize_progbuf(progbuf12, value); }
function clause write_DM_reg(0x2d, value) = { progbuf13 = legalize_progbuf(progbuf13, value); }
function clause write_DM_reg(0x2e, value) = { progbuf14 = legalize_progbuf(progbuf14, value); }
function clause write_DM_reg(0x2f, value) = { progbuf15 = legalize_progbuf(progbuf15, value); }

function clause read_DM_reg(0x20) = progbuf0
function clause read_DM_reg(0x21) = progbuf1
function clause read_DM_reg(0x22) = progbuf2
function clause read_DM_reg(0x23) = progbuf3
function clause read_DM_reg(0x24) = progbuf4
function clause read_DM_reg(0x25) = progbuf5
function clause read_DM_reg(0x26) = progbuf6
function clause read_DM_reg(0x27) = progbuf7
function clause read_DM_reg(0x28) = progbuf8
function clause read_DM_reg(0x29) = progbuf9
function clause read_DM_reg(0x2a) = progbuf10
function clause read_DM_reg(0x2b) = progbuf11
function clause read_DM_reg(0x2c) = progbuf12
function clause read_DM_reg(0x2d) = progbuf13
function clause read_DM_reg(0x2e) = progbuf14
function clause read_DM_reg(0x2f) = progbuf15

bitfield Authdata : bits(32) = {
  data: 31 .. 0
}

function legalize_authdata(d : Authdata, x : bits(32)) -> Authdata = {
  let x = Mk_Authdata(x);
  [d with
    data = x[data]
  ]
}

register authdata: Authdata = legalize_authdata(Mk_Authdata(zeros()), zeros())

mapping clause dm_name_map = 0x30  <-> "authdata"

function clause is_DM_reg_defined (0x30) = true
function clause write_DM_reg(0x30, value) = { authdata = legalize_authdata(authdata, value); }
function clause read_DM_reg(0x30) = authdata.bits

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
    // TODO
    // NOTE: Tie it to 0 for now, but can actually be set
    hgselect = 0b0
  ]
}
register dmcs2: Dmcs2 = legalize_dmcs2(Mk_Dmcs2(zeros()), zeros())
mapping clause dm_name_map = 0x32  <-> "dmcs2"
function clause is_DM_reg_defined (0x32) = true
function clause write_DM_reg(0x32, value) = { dmcs2 = legalize_dmcs2(dmcs2, value); }
function clause read_DM_reg(0x32) = dmcs2.bits

bitfield Haltsum2 : bits(32) = {
  haltsum2: 31 .. 0
}

function legalize_haltsum2(d : Haltsum2, x : bits(32)) -> Haltsum2 = {
  let x = Mk_Haltsum2(x);
  [d with
    // TODO
    haltsum2 = zeros(),
  ]
}

register haltsum2: Haltsum2 = legalize_haltsum2(Mk_Haltsum2(zeros()), zeros())

mapping clause dm_name_map = 0x34  <-> "haltsum2"

function clause is_DM_reg_defined (0x34) = true
// Read Only Register
function clause read_DM_reg(0x34) = haltsum2.bits

bitfield Haltsum3 : bits(32) = {
  haltsum3: 31 .. 0
}

function legalize_haltsum3(d : Haltsum3, x : bits(32)) -> Haltsum3 = {
  let x = Mk_Haltsum3(x);
  [d with
    // TODO
    haltsum3 = zeros(),
  ]
}

register haltsum3: Haltsum3 = legalize_haltsum3(Mk_Haltsum3(zeros()), zeros())

mapping clause dm_name_map = 0x35  <-> "haltsum3"

function clause is_DM_reg_defined (0x35) = true
// Read Only Register
function clause read_DM_reg(0x35) = haltsum3.bits

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
    sbbusyerror     = if x[sbbusyerror] == 0b1 then 0b0 else x[sbbusyerror], // R/W1C
    //sbbusy
    sbreadonaddr    = x[sbreadonaddr],
    sbaccess        = x[sbaccess],
    sbautoincrement = x[sbautoincrement],
    sbreadonaddr    = x[sbreadonaddr],
    sberror         = if x[sberror] == ones() then zeros() else x[sberror], //R/W1C
    // No bus access support yet
    sbasize     = zeros(),
    sbaccess128 = 0b0,
    sbaccess64  = 0b0,
    sbaccess32  = 0b0,
    sbaccess16  = 0b0,
    sbaccess8   = 0b0
  ]
}

register sbcs: Sbcs = legalize_sbcs(Mk_Sbcs(zeros()), zeros())

mapping clause dm_name_map = 0x38  <-> "sbcs"

function clause is_DM_reg_defined (0x38) = true
function clause write_DM_reg(0x38, value) = { sbcs = legalize_sbcs(sbcs, value); }
function clause read_DM_reg(0x38) = sbcs.bits

bitfield Sbaddresse0 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddresse0(d : Sbaddresse0, x : bits(32)) -> Sbaddresse0 = {
  let x = Mk_Sbaddresse0(x);
  [d with
    address = x[address]
  ]
}

register sbaddresse0: Sbaddresse0 = legalize_sbaddresse0(Mk_Sbaddresse0(zeros()), zeros())

mapping clause dm_name_map = 0x39  <-> "sbaddresse0"

function clause is_DM_reg_defined (0x39) = sbcs[sbasize] != 0b0000000
function clause write_DM_reg(0x39, value) = { sbaddresse0 = legalize_sbaddresse0(sbaddresse0, value); }
function clause read_DM_reg(0x39) = sbaddresse0.bits

bitfield Sbaddresse1 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddresse1(d : Sbaddresse1, x : bits(32)) -> Sbaddresse1 = {
  let x = Mk_Sbaddresse1(x);
  [d with
    address = x[address]
  ]
}

register sbaddresse1: Sbaddresse1 = legalize_sbaddresse1(Mk_Sbaddresse1(zeros()), zeros())

mapping clause dm_name_map = 0x3a  <-> "sbaddresse1"

function clause is_DM_reg_defined (0x3a) = unsigned(sbcs[sbasize]) >= 33
function clause write_DM_reg(0x3a, value) = { sbaddresse1 = legalize_sbaddresse1(sbaddresse1, value); }
function clause read_DM_reg(0x3a) = sbaddresse1.bits

bitfield Sbaddresse2 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddresse2(d : Sbaddresse2, x : bits(32)) -> Sbaddresse2 = {
  let x = Mk_Sbaddresse2(x);
  [d with
    address = x[address]
  ]
}

register sbaddresse2: Sbaddresse2 = legalize_sbaddresse2(Mk_Sbaddresse2(zeros()), zeros())

mapping clause dm_name_map = 0x3b  <-> "sbaddresse2"

function clause is_DM_reg_defined (0x3b) = unsigned(sbcs[sbasize]) >= 65
function clause write_DM_reg(0x3b, value) = { sbaddresse2 = legalize_sbaddresse2(sbaddresse2, value); }
function clause read_DM_reg(0x3b) = sbaddresse2.bits

bitfield Sbaddresse3 : bits(32) = {
  address: 31 .. 0
}

function legalize_sbaddresse3(d : Sbaddresse3, x : bits(32)) -> Sbaddresse3 = {
  let x = Mk_Sbaddresse3(x);
  [d with
    address = x[address]
  ]
}

register sbaddresse3: Sbaddresse3 = legalize_sbaddresse3(Mk_Sbaddresse3(zeros()), zeros())

mapping clause dm_name_map = 0x37  <-> "sbaddresse3"

function clause is_DM_reg_defined (0x37) = unsigned(sbcs[sbasize]) >= 97
function clause write_DM_reg(0x37, value) = { sbaddresse3 = legalize_sbaddresse3(sbaddresse3, value); }
function clause read_DM_reg(0x37) = sbaddresse3.bits

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

mapping clause dm_name_map = 0x3c  <-> "sbdata0"

function clause is_DM_reg_defined (0x3c) = sbcs[sbaccess] != 0b000
function clause write_DM_reg(0x3c, value) = { sbdata0 = legalize_sbdata0(sbdata0, value); }
function clause read_DM_reg(0x3c) = sbdata0.bits

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
mapping clause dm_name_map = 0x3d  <-> "sbdata1"
function clause is_DM_reg_defined (0x3d) = sbcs[sbaccess64] != 0b0 & sbcs[sbaccess128] != 0b0
function clause write_DM_reg(0x3d, value) = { sbdata1 = legalize_sbdata1(sbdata1, value); }
function clause read_DM_reg(0x3d) = sbdata1.bits

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

mapping clause dm_name_map = 0x3e  <-> "sbdata2"

function clause is_DM_reg_defined (0x3e) = sbcs[sbaccess128] == 0b1
function clause write_DM_reg(0x3e, value) = { sbdata2 = legalize_sbdata2(sbdata2, value); }
function clause read_DM_reg(0x3e) = sbdata2.bits

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

mapping clause dm_name_map = 0x3f  <-> "sbdata3"

function clause is_DM_reg_defined (0x3f) = sbcs[sbaccess128] == 0b1
function clause write_DM_reg(0x3f, value) = { sbdata3 = legalize_sbdata3(sbdata3, value); }
function clause read_DM_reg(0x3f) = sbdata3.bits

bitfield Haltsum0 : bits(32) = {
  haltsum0: 31 .. 0
}

function legalize_haltsum0(d : Haltsum0, x : bits(32)) -> Haltsum0 = {
  let x = Mk_Haltsum0(x);
  [d with
    // NOTE: Hart 0 corresponds to bit 0
    haltsum0 = zeros(31) @ dmstatus[allhalted],
  ]
}

register haltsum0: Haltsum0 = legalize_haltsum0(Mk_Haltsum0(zeros()), zeros())

mapping clause dm_name_map = 0x40  <-> "haltsum0"

function clause is_DM_reg_defined (0x40) = true
// Read Only Register
function clause read_DM_reg(0x40) = haltsum0.bits

// terminate scattered definitions

mapping clause dm_name_map = reg <-> hex_bits_8(reg)
end dm_name_map

function clause is_DM_reg_defined(_) = false
end is_DM_reg_defined

function clause read_DM_reg(dm_reg) = {
   // This should be impossible because is_DM_reg_defined() should have returned false.
   internal_error(__FILE__, __LINE__, "Read from Debug Module Register that does not exist: " ^ bits_str(dm_reg));
}
end read_DM_reg

function clause write_DM_reg(dm_reg, _) = {
   // This should be impossible because is_DM_reg_defined() should have returned false.
   internal_error(__FILE__, __LINE__, "Write to Debug Module Register that does not exist: " ^ bits_str(dm_reg));
}
end write_DM_reg

function reset_debug_module() = {

  // Behavior is undefined if a hart is halted when the
  // debug module resets. For now, we check if the hart
  // is halted and issue a resume request.
  if halted then send_debug_request(Resume());

  haltrequest = false;
  resumeack   = false;
  hartreset   = false;
  haltonreset = false;
  //unavail      = false;
  //keepalive    = false;

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

  sbaddresse0.bits = zeros();
  sbaddresse1.bits = zeros();
  sbaddresse2.bits = zeros();
  sbaddresse3.bits = zeros();

  sbdata0.bits = zeros();
  sbdata1.bits = zeros();
  sbdata2.bits = zeros();
  sbdata3.bits = zeros();
}
