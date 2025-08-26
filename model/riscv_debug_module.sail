/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// State of the Hart from the Debug Module's POV (? Double check this)
enum DMHartState = {NON_EXISTENT, UNAVAILABLE, RUNNING, HALTED}
// Request from the DM to the Hart
// TODO: Add RESET etc.
register dm_hart_state : DMHartState = RUNNING

///////////////////////////////////////////////////////////////////////

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

function clause is_DM_reg_defined (0x04) = true
function clause is_DM_reg_defined (0x05) = true
function clause is_DM_reg_defined (0x06) = true
function clause is_DM_reg_defined (0x07) = true
function clause is_DM_reg_defined (0x08) = true
function clause is_DM_reg_defined (0x09) = true
function clause is_DM_reg_defined (0x0a) = true
function clause is_DM_reg_defined (0x0b) = true
function clause is_DM_reg_defined (0x0c) = true
function clause is_DM_reg_defined (0x0d) = true
function clause is_DM_reg_defined (0x0e) = true
function clause is_DM_reg_defined (0x0f) = true

function clause write_DM_reg(0x04, value) = { data0 = value; data0 }
function clause write_DM_reg(0x05, value) = { data1 = value; data1 }
function clause write_DM_reg(0x06, value) = { data2 = value; data2 }
function clause write_DM_reg(0x07, value) = { data3 = value; data3 }
function clause write_DM_reg(0x08, value) = { data4 = value; data4 }
function clause write_DM_reg(0x09, value) = { data5 = value; data5 }
function clause write_DM_reg(0x0a, value) = { data6 = value; data6 }
function clause write_DM_reg(0x0b, value) = { data7 = value; data7 }
function clause write_DM_reg(0x0c, value) = { data8 = value; data8 }
function clause write_DM_reg(0x0d, value) = { data9 = value; data9 }
function clause write_DM_reg(0x0e, value) = { data10 = value; data10 }
function clause write_DM_reg(0x0f, value) = { data11 = value; data11 }

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
  allhalted:         9,
  anyhalted:        8,
  authenticated:    7,
  authbusy:         6,
  hasresethaltreq:  5,
  confstrptrvalid:  4,
  version:          3 .. 0
}

// NOTE: This whole register cannot be written from outside
function legalize_dmstatus(d : Dmstatus) -> Dmstatus = {
  [d with
    // TODO: For now authentification is not supported
    // but this should be optional
    // NOTE: This needs to be disabled because otherwise
    // OpenOCD will not continue after failed authentification
    authenticated = 0b1,
    // Version 1.0
    version       = 0b0011
  ]
}

register dmstatus: Dmstatus = legalize_dmstatus(Mk_Dmstatus(zeros()))

mapping clause dm_name_map = 0x11  <-> "dmstatus"

function clause is_DM_reg_defined (0x11) = true
function clause write_DM_reg(0x11, value) = { dmstatus.bits }
function clause read_DM_reg(0x11) = dmstatus.bits

bitfield Dmcontrol : bits(32) = {
  haltreq :        31,
  resumereq:       30,
  haltreset:       29,
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

function request_hart(request : debug_request) -> bool = {
  let s : debug_module_observe_status = match request {
    DR_Halt   => send_request(DR_Halt),
    DR_Resume => send_request(DR_Resume),
    // TODO: Remove this or at least handle differently
    DR_None => send_request(DR_None),
    };
  // TODO
    dmstatus[allhalted]    = [bool_to_bit(s.allhalted)];
    dmstatus[anyhalted]    = [bool_to_bit(s.anyhalted)];
    dmstatus[allrunning]   = [bool_to_bit(s.allrunning)];
    dmstatus[anyrunning]   = [bool_to_bit(s.anyrunning)];
    dmstatus[allhavereset] = [bool_to_bit(s.allhavereset)];
    dmstatus[anyhavereset] = [bool_to_bit(s.anyhavereset)];

    s.success
}

function legalize_dmcontrol(d : Dmcontrol, x : bits(32)) -> Dmcontrol = {
  let x = Mk_Dmcontrol(x);

  if x[ndmreset] == 0b1 then {
    // TODO
    print_endline("Reset Hard Platform");
  };

  if x[haltreq] == 0b1 then {
    print_log("Received halt request");
    let status = request_hart(DR_Halt);
  };

  if (x[resumereq] == 0b1) then {
    print_log("Received resume request");
    let status = request_hart(DR_Resume);
  };

  [d with
    // TODO: Writing clears halt request bit for all currently selected harts.
    // This may (!) cancel outstanding halt requests for those harts.
    // NOTE: Call end_debug_abstract_command(?)
    // TODO: Writes to this bit should be ignored while
    // an abstract command is executing
    haltreq         = x[haltreq],
    resumereq       = if x[resumereq] == 0b1 then 0b1 else x[resumereq],
    haltreset       = 0b0,
    ackhavereset    = if x[ackhavereset] == 0b1 then 0b1 else x[ackhavereset],
    ackunavail      = if x[ackunavail] == 0b1 then 0b1 else x[ackunavail],
    // Currently, we only support 1 hart
    hasel           = 0b0,
    hartsello       = 0b0000000000,
    hartselhi       = 0b0000000000,
    setkeepalive    = 0b0,
    clrkeepalive    = 0b0,
    setresethaltreq = 0b0,
    clrresethaltreq = 0b0,
    ndmreset        = x[ndmreset],
    dmactive        = x[dmactive]
  ]
}

register dmcontrol: Dmcontrol = legalize_dmcontrol(Mk_Dmcontrol(zeros()), zeros())

mapping clause dm_name_map = 0x10  <-> "dmcontrol"

function clause is_DM_reg_defined (0x10) = true
function clause write_DM_reg(0x10, value) = { dmcontrol = legalize_dmcontrol(dmcontrol, value); dmcontrol.bits }
function clause read_DM_reg(0x10) = dmcontrol.bits

bitfield Hartinfo : bits(32) = {
  nscratch:   23 .. 20,
  dataaccess: 16,
  datasize:   15 .. 12,
  dataaddr:   11 .. 0
}

function legalize_hartinfo(d : Hartinfo) -> Hartinfo = {
  [d with
    // TODO: Needs to be set
    nscratch   = 0b0000,
    // TODO: I dont know what this really means yet
    dataaccess = 0b0,
    // TODO: I dont know what this really means yet
    datasize   = 0b0000,
    // TODO: I dont know what this really means yet
    dataaddr   = 0b000000000000
  ]
}

register hartinfo: Hartinfo = legalize_hartinfo(Mk_Hartinfo(zeros()))

mapping clause dm_name_map = 0x12  <-> "hartinfo"

function clause is_DM_reg_defined (0x12) = true
function clause write_DM_reg(0x12, value) = { hartinfo.bits }
function clause read_DM_reg(0x12) = hartinfo.bits

bitfield Haltsum1 : bits(32) = {
  haltsum1: 31 .. 0
}

function legalize_haltsum1(d : Haltsum1, x : bits(32)) -> Haltsum1 = {
  let x = Mk_Haltsum1(x);
  [d with
    // TODO
    haltsum1 = 0x00000000
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
      // TODO: This is bit is writable but we tie it to 0 for now
      hawindowsel = 0b000000000000000
  ]
}

register hawindowsel: Hawindowsel = legalize_hawindowsel(Mk_Hawindowsel(zeros()), zeros())

mapping clause dm_name_map = 0x14  <-> "hawindowsel"

// Optional Register
function clause is_DM_reg_defined (0x14) = false
function clause write_DM_reg(0x14, value) = { hawindowsel = legalize_hawindowsel(hawindowsel, value); hawindowsel.bits }
function clause read_DM_reg(0x14) = hawindowsel.bits

bitfield Hawindow : bits(32) = {
  maskdata : 31 ..0,
}

function legalize_hawindow(d : Hawindow, x : bits(32)) -> Hawindow = {
    let x = Mk_Hawindow(x);

    [d with
      maskdata = x[maskdata]
    ]
}
register hawindow: Hawindow = legalize_hawindow(Mk_Hawindow(zeros()), zeros())

mapping clause dm_name_map = 0x15  <-> "hawindow"

function clause is_DM_reg_defined (0x15) = true
function clause write_DM_reg(0x15, value) = { hawindow = legalize_hawindow(hawindow, value); hawindow.bits }
function clause read_DM_reg(0x15) = hawindow.bits

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
      progbufsize = 0b00000,
      relaxedpriv = 0b0,
      // NOTE: R/W1C
      cmderr = if x[cmderr] == 0b001 then 0b000 else x[cmderr],
      // NOTE: I think, in theory we could enable even
      // more data* regs regardless of the value of xlen
      datacount = if xlen == 32 then 0b0001 else 0b0010

    ]
}

register abstractcs: Abstractcs = legalize_abstractcs(Mk_Abstractcs(zeros()), zeros())

mapping clause dm_name_map = 0x16  <-> "abstractcs"

function clause is_DM_reg_defined (0x16) = true
function clause write_DM_reg(0x16, value) = { abstractcs = legalize_abstractcs(abstractcs, value); abstractcs.bits }
function clause read_DM_reg(0x16) = abstractcs.bits

bitfield Command : bits(32) = {
  cmdtype: 31 .. 24,
  control: 23 .. 0
}

function access_reg(write : access_type, data : bits(32), regno: bits(16)) -> bool = {
  let addr = unsigned(regno);

  // TODO: We need to simplify this!
  match addr {
    addr if addr <= unsigned(0x0fff) => {
      print_endline("Access CSR");
      // TODO/NOTE: We have to read/write as we were in M-Mode.
      match write {
        READ => {
          let regvalue = read_CSR(regno[11 .. 0]);
          match xlen {
            32 => data0 = regvalue,
            64 => {
              data0 = regvalue[31 .. 0];
              data1 = regvalue[63 .. 32];
            },
            _ => internal_error(__FILE__, __LINE__, "Unsupported xlen"),
          };
        },
        WRITE => {
          match xlen {
            32 => {
              match write_CSR(regno[11 .. 0], data0) {
                Ok(_) => (),
                Err(_) => internal_error(__FILE__, __LINE__, "Error ")
              }
            },
            64 => {
              match write_CSR(regno[11 .. 0], data1 @ data0) {
                Ok(_) => (),
                Err(_) => (),
              }
            },
            _ => internal_error(__FILE__, __LINE__, "Unsupported xlen"),
          };
        },
      }

    },      //CSR,
    addr if addr <= unsigned(0x101f) => {
      // NOTE/TODO: For me its not obvious whether writes from data0 to regs are always 32 bit.
      // what happens with the remaining bits in case the reg is 64bit width?
      // for now sign extend
      // NOTE: What happens if E-Extension is enabled?!?
      //let a = addr - unsigned(0x1000);
      //assert(a >= 0 & a <=31);
      print_endline("Access GPR");
      let regidx = encdec_reg(regno[4 .. 0]);
      match write {
        READ => {
        let regvalue = X(regidx);
          match xlen {
          32 => data0 = regvalue,
          64 => {
            data0 = regvalue[31 .. 0];
            data1 = regvalue[63 .. 32];
          },
          _ => internal_error(__FILE__, __LINE__, "Unsupported xlen"),
         };
        },
        WRITE => {
          match xlen {
            32 => X(regidx) = data0,
            64 => X(regidx) = data1 @ data0,
            _ => internal_error(__FILE__, __LINE__, "Unsupported xlen"),
          };
        }
      };
      print_endline("GPR")
    },      //GPR,
    // TODO: Add READ/WRITE for floating point regs
    addr if addr <= unsigned(0x103f) => print_endline("FPR"),      //FPR,
    addr if addr >= unsigned(0xc000) & addr <= unsigned(0xffff) => print_endline("RESERVED"), //RESERVED,
    addr => print_endline("INVALID"),                              //INVALID
  };
  // TODO
  true
}
function execute_abstract_command(aarsize : bits(3), aarpostincrement : bits(1), postexec : bits(1), transfer : bits(1), write : bits(1), regno : bits (16)) -> bool = {

  let res : bool = match determine_access_type(write, transfer) {
    READ       => access_reg(READ, data0, regno),
    WRITE      => access_reg(WRITE, data0, regno),
    NO_TRANFER => true,
  };
  res
}

function legalize_command(d : Command, x : bits(32)) -> Command = {

  // TODO check if abstract command is being executed
  // NOTE: We only support cmdtype 0 (Access Register Command)
  let cmdtype          = x[31 .. 24];
  let aarsize          = x[22 .. 20];
  let aarpostincrement = x[19 .. 19];
  let postexec         = x[18 .. 18];
  let transfer         = x[17 .. 17];
  let write            = x[16 .. 16];
  let regno            = x[15 .. 0];

  //abstractcs[busy] = 0b1;
  let status = execute_abstract_command(aarsize, aarpostincrement, postexec, transfer, write, regno);
  //abstracts[busy] = 0b0;

  let x = Mk_Command(x);

  [d with
    cmdtype = x[cmdtype],
    control = x[control],
  ]
}

register command: Command = legalize_command(Mk_Command(zeros()), zeros())

mapping clause dm_name_map = 0x17  <-> "command"

function clause is_DM_reg_defined (0x17) = true
function clause write_DM_reg(0x17, value) = { command = legalize_command(command, value); zeros() }
function clause read_DM_reg(0x17) = zeros()

bitfield Abstractauto : bits(32) = {
  autoexecprogbuf: 31 .. 16,
  autoexecdata:    11 ..  0,
}

function legalize_abstractauto(d : Abstractauto, x : bits(32)) -> Abstractauto = {
  let x = Mk_Abstractauto(x);
  [d with
    // TODO
    autoexecdata = 0b000000000000,
    // TODO
    autoexecdata = 0b000000000000
  ]
}

register abstractauto: Abstractauto = legalize_abstractauto(Mk_Abstractauto(zeros()), zeros())

mapping clause dm_name_map = 0x18  <-> "abstractauto"

// Optional Register
function clause is_DM_reg_defined (0x18) = false
function clause write_DM_reg(0x18, value) = { abstractauto = legalize_abstractauto(abstractauto, value); abstractauto.bits }
function clause read_DM_reg(0x18) = abstractauto.bits

bitfield Confstrptr0 : bits(32) = {
  addr : 31 .. 0
}

function legalize_confstrptr0(d : Confstrptr0, x : bits(32)) -> Confstrptr0 = {
  let x = Mk_Confstrptr0(x);
  [d with
    // TODO
    // NOTE: Part of System Bus Access
    addr = 0x00000000
  ]
}

register confstrptr0: Confstrptr0 = legalize_confstrptr0(Mk_Confstrptr0(zeros()), zeros())

mapping clause dm_name_map = 0x19  <-> "confstrptr0"

function clause is_DM_reg_defined (0x19) = true
// Read Only Register
function clause read_DM_reg(0x19) = confstrptr0.bits


bitfield Confstrptr1 : bits(32) = {
  addr: 31 .. 0
}

function legalize_confstrptr1(d : Confstrptr1, x : bits(32)) -> Confstrptr1 = {
  let x = Mk_Confstrptr1(x);
  [d with
    // TODO
    // NOTE: Part of System Bus Access
    addr = 0x00000000
  ]
}

register confstrptr1: Confstrptr1 = legalize_confstrptr1(Mk_Confstrptr1(zeros()), zeros())

mapping clause dm_name_map = 0x1a  <-> "confstrptr1"

function clause is_DM_reg_defined (0x1a) = true
// Read Only Register
function clause read_DM_reg(0x1a) = confstrptr1.bits

bitfield Confstrptr2 : bits(32) = {
  addr: 31 .. 0
}

function legalize_confstrptr2(d : Confstrptr2, x : bits(32)) -> Confstrptr2 = {
  let x = Mk_Confstrptr2(x);
  [d with
    addr = 0x00000000
  ]
}

register confstrptr2: Confstrptr2 = legalize_confstrptr2(Mk_Confstrptr2(zeros()), zeros())

mapping clause dm_name_map = 0x1b  <-> "confstrptr2"

function clause is_DM_reg_defined (0x1b) = true
// Read Only Register
function clause read_DM_reg(0x1b) = confstrptr2.bits

bitfield Confstrptr3 : bits(32) = {
  addr: 31 .. 0
}

function legalize_confstrptr3(d : Confstrptr3, x : bits(32)) -> Confstrptr3 = {
  let x = Mk_Confstrptr3(x);
  [d with
    // TODO
    // NOTE: Part of System Bus Access
    addr = 0x00000000
  ]
}

register confstrptr3: Confstrptr3 = legalize_confstrptr3(Mk_Confstrptr3(zeros()), zeros())

mapping clause dm_name_map = 0x1c  <-> "confstrptr3"

function clause is_DM_reg_defined (0x1c) = true
// Read Only Register
function clause read_DM_reg(0x1c) = confstrptr3.bits

bitfield Nextdm : bits(32) = {
  addr: 31 .. 0
}

function legalize_nextdm(d : Nextdm, x : bits(32)) -> Nextdm = {
  let x = Mk_Nextdm(x);
  [d with
    // TODO
    addr = 0x00000000
  ]
}

register nextdm: Nextdm = legalize_nextdm(Mk_Nextdm(zeros()), zeros())

mapping clause dm_name_map = 0x1d  <-> "nextdm"

function clause is_DM_reg_defined (0x1d) = true
// Read Only Register
function clause read_DM_reg(0x1d) = nextdm.bits

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

function clause is_DM_reg_defined (0x20) = true
function clause is_DM_reg_defined (0x21) = true
function clause is_DM_reg_defined (0x22) = true
function clause is_DM_reg_defined (0x23) = true
function clause is_DM_reg_defined (0x24) = true
function clause is_DM_reg_defined (0x25) = true
function clause is_DM_reg_defined (0x26) = true
function clause is_DM_reg_defined (0x27) = true
function clause is_DM_reg_defined (0x28) = true
function clause is_DM_reg_defined (0x29) = true
function clause is_DM_reg_defined (0x2a) = true
function clause is_DM_reg_defined (0x2b) = true
function clause is_DM_reg_defined (0x2c) = true
function clause is_DM_reg_defined (0x2d) = true
function clause is_DM_reg_defined (0x2e) = true
function clause is_DM_reg_defined (0x2f) = true

function clause write_DM_reg(0x20, value) = { progbuf0 = value; progbuf0 }
function clause write_DM_reg(0x21, value) = { progbuf1 = value; progbuf1 }
function clause write_DM_reg(0x22, value) = { progbuf2 = value; progbuf2 }
function clause write_DM_reg(0x23, value) = { progbuf3 = value; progbuf3 }
function clause write_DM_reg(0x24, value) = { progbuf4 = value; progbuf4 }
function clause write_DM_reg(0x25, value) = { progbuf5 = value; progbuf5 }
function clause write_DM_reg(0x26, value) = { progbuf6 = value; progbuf6 }
function clause write_DM_reg(0x27, value) = { progbuf7 = value; progbuf7 }
function clause write_DM_reg(0x28, value) = { progbuf8 = value; progbuf8 }
function clause write_DM_reg(0x29, value) = { progbuf9 = value; progbuf9 }
function clause write_DM_reg(0x2a, value) = { progbuf10 = value; progbuf10 }
function clause write_DM_reg(0x2b, value) = { progbuf11 = value; progbuf11 }
function clause write_DM_reg(0x2c, value) = { progbuf12 = value; progbuf12 }
function clause write_DM_reg(0x2d, value) = { progbuf13 = value; progbuf13 }
function clause write_DM_reg(0x2e, value) = { progbuf14 = value; progbuf14 }
function clause write_DM_reg(0x2f, value) = { progbuf15 = value; progbuf15 }

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
function clause write_DM_reg(0x30, value) = { authdata = legalize_authdata(authdata, value); authdata.bits }
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
    hgwrite = if x[hgwrite] == 0b0 then 0b1 else x[hgwrite],
    // TODO
    // NOTE: Tie it to 0 for now, but can actually be set
    hgselect = 0b0
  ]
}
register dmcs2: Dmcs2 = legalize_dmcs2(Mk_Dmcs2(zeros()), zeros())
mapping clause dm_name_map = 0x32  <-> "dmcs2"
function clause is_DM_reg_defined (0x32) = true
function clause write_DM_reg(0x32, value) = { dmcs2 = legalize_dmcs2(dmcs2, value); dmcs2.bits }
function clause read_DM_reg(0x32) = dmcs2.bits

bitfield Haltsum2 : bits(32) = {
  haltsum2: 31 .. 0
}

function legalize_haltsum2(d : Haltsum2, x : bits(32)) -> Haltsum2 = {
  let x = Mk_Haltsum2(x);
  [d with
    // TODO
    haltsum2 = 0x00000000
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
    haltsum3 = 0x00000000
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
    sbbusyerror     = if x[sbbusyerror] == 0b1 then 0b0 else x[sbbusyerror],
    //sbbusy
    sbreadonaddr    = x[sbreadonaddr],
    sbaccess        = x[sbaccess],
    sbautoincrement = x[sbautoincrement],
    sbreadonaddr    = x[sbreadonaddr],
    sberror         = if x[sberror] == 0b001 then 0b000 else x[sberror],
    // No bus access support yet
    sbasize     = 0b0000000,
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
function clause write_DM_reg(0x38, value) = { sbcs = legalize_sbcs(sbcs, value); sbcs.bits }
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
function clause write_DM_reg(0x39, value) = { sbaddresse0 = legalize_sbaddresse0(sbaddresse0, value); sbaddresse0.bits }
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
function clause write_DM_reg(0x3a, value) = { sbaddresse1 = legalize_sbaddresse1(sbaddresse1, value); sbaddresse1.bits }
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
function clause write_DM_reg(0x3b, value) = { sbaddresse2 = legalize_sbaddresse2(sbaddresse2, value); sbaddresse2.bits }
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
function clause write_DM_reg(0x37, value) = { sbaddresse3 = legalize_sbaddresse3(sbaddresse3, value); sbaddresse3.bits }
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
function clause write_DM_reg(0x3c, value) = { sbdata0 = legalize_sbdata0(sbdata0, value); sbdata0.bits }
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
function clause write_DM_reg(0x3d, value) = { sbdata1 = legalize_sbdata1(sbdata1, value); sbdata1.bits }
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
function clause write_DM_reg(0x3e, value) = { sbdata2 = legalize_sbdata2(sbdata2, value); sbdata2.bits }
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
function clause write_DM_reg(0x3f, value) = { sbdata3 = legalize_sbdata3(sbdata3, value); sbdata3.bits }
function clause read_DM_reg(0x3f) = sbdata3.bits

bitfield Haltsum0 : bits(32) = {
  haltsum0: 31 .. 0
}

function legalize_haltsum0(d : Haltsum0, x : bits(32)) -> Haltsum0 = {
  let x = Mk_Haltsum0(x);
  [d with
    // TODO
    haltsum0 = 0x00000000
  ]
}

register haltsum0: Haltsum0 = legalize_haltsum0(Mk_Haltsum0(zeros()), zeros())

mapping clause dm_name_map = 0x40  <-> "haltsum0"

function clause is_DM_reg_defined (0x40) = true
// Read Only Register
function clause read_DM_reg(0x40) = haltsum0.bits
