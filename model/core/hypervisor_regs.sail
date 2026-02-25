// =======================================================================================
// This Sail RISC-V architecture model, comprising all files and
// directories except where otherwise noted is subject the BSD
// two-clause license in the LICENSE file.
//
// SPDX-License-Identifier: BSD-2-Clause
// =======================================================================================

// HS-Mode register

// Hypervisor Interrupt Registers

function legalize_hvip(h : Minterrupts, v : xlenbits) -> Minterrupts = {
  let v = Mk_Minterrupts(v);
  [h with
    VSEI = v[VSEI],
    VSTI = v[VSTI],
    VSSI = v[VSSI],
  ]
}

function legalize_hie(m : Minterrupts, v : xlenbits) -> Minterrupts = {
  let v = Mk_Minterrupts(v);
  [m with
    SGEI = v[SGEI],
    VSEI = v[VSEI],
    VSTI = v[VSTI],
    VSSI = v[VSSI],
  ]
}

// NOTE: Only VSSI is writable in hip (SGEI, VSEI, VSTI are read-only)
function legalize_hip(m : Minterrupts, v : xlenbits) -> Minterrupts = {
  let v = Mk_Minterrupts(v);
  [m with VSSI = v[VSSI]]
}

// NOTE: hvip.vssi is an alias of mip.vssi, so always read the
// actual value from mip. The remaining bits come from hvip.
function lower_mip_to_hvip(m : Minterrupts, h : Minterrupts) -> Minterrupts = {
  [h with VSSI = m[VSSI]]
}

function lower_mie_to_hie(m : Minterrupts) -> Minterrupts = {
  [Mk_Minterrupts(zeros()) with
    SGEI = m[SGEI],
    VSEI = m[VSEI],
    VSTI = m[VSTI],
    VSSI = m[VSSI],
  ]
}

function lower_mip_to_hip(m : Minterrupts) -> Minterrupts = {
  [Mk_Minterrupts(zeros()) with
    SGEI = m[SGEI],
    VSEI = m[VSEI],
    VSTI = m[VSTI],
    VSSI = m[VSSI],
  ]
}

mapping clause csr_name_map = 0x645 <-> "hvip"
mapping clause csr_name_map = 0x604 <-> "hie"
mapping clause csr_name_map = 0x644 <-> "hip"

function clause is_CSR_accessible(0x645, _, _) = currentlyEnabled(Ext_H) // hvip
function clause is_CSR_accessible(0x604, _, _) = currentlyEnabled(Ext_H) // hie
function clause is_CSR_accessible(0x644, _, _) = currentlyEnabled(Ext_H) // hip

function clause read_CSR(0x645) = lower_mip_to_hvip(mip, hvip).bits
function clause read_CSR(0x604) = lower_mie_to_hie(mie).bits
function clause read_CSR(0x644) = lower_mip_to_hip(mip).bits

function clause write_CSR(0x645, value) = { hvip = legalize_hvip(hvip, value); mip[VSSI] = hvip[VSSI]; Ok(hvip.bits) }
function clause write_CSR(0x604, value) = { mie = legalize_hie(mie, value); Ok(lower_mie_to_hie(mie).bits) }
function clause write_CSR(0x644, value) = { mip = legalize_hip(mip, value); Ok(lower_mip_to_hip(mip).bits) }

// Hypervisor Time Delta

register htimedelta : bits(64)

mapping clause csr_name_map = 0x605 <-> "htimedelta"
mapping clause csr_name_map = 0x615 <-> "htimedeltah"

// TODO: Should raise virtual instruction exception if accessed by VU/VS-Mode.
// Needs refactoring of CSR access logic.
function clause is_CSR_accessible(0x605, _, _) = currentlyEnabled(Ext_H) // htimedelta
function clause is_CSR_accessible(0x615, _, _) = currentlyEnabled(Ext_H) & xlen == 32 // htimedeltah

function clause read_CSR(0x605) = htimedelta[xlen - 1 .. 0]
function clause read_CSR(0x615 if xlen == 32) = htimedelta[63 .. 32]

function clause write_CSR(0x605, value) = { htimedelta[xlen - 1 .. 0] = value; Ok(htimedelta[xlen - 1 .. 0]) }
function clause write_CSR((0x615, value) if xlen == 32) = { htimedelta[63 .. 32] = value; Ok(htimedelta[63 .. 32]) }

// Hypervisor Trap Handling

register htval  : xlenbits
register htinst : xlenbits

mapping clause csr_name_map = 0x643 <-> "htval"
mapping clause csr_name_map = 0x64A <-> "htinst"

function clause is_CSR_accessible(0x643, _, _) = currentlyEnabled(Ext_H) // htval
function clause is_CSR_accessible(0x64A, _, _) = currentlyEnabled(Ext_H) // htinst

function clause read_CSR(0x643) = htval
function clause read_CSR(0x64A) = htinst

function clause write_CSR(0x643, value) = { htval = value; Ok(htval) }
function clause write_CSR(0x64A, value) = { htinst = value; Ok(htinst) }

// Hypervisor Guest Address Translation and Protection

// TODO: Consolidate with SATPMode to get rid of HBare
type hgatp_mode = bits(4)
enum HGATPMode = {HBare, Sv32x4, Sv39x4, Sv48x4, Sv57x4}

function hgatpMode_of_bits(a : Architecture, m : hgatp_mode) -> option(HGATPMode) =
  match (a, m) {
    (_,    0x0) => Some(HBare),
    (RV32, 0x1) => Some(Sv32x4),
    (RV64, 0x8) => Some(Sv39x4),
    (RV64, 0x9) => Some(Sv48x4),
    (RV64, 0xA) => Some(Sv57x4),
    (_, _)      => None()
  }

bitfield Hgatp64 : bits(64) = {
  Mode : 63 .. 60,
  VMID : 57 .. 44,
  PPN  : 43 .. 0
}

bitfield Hgatp32 : bits(32) = {
  Mode : 31,
  VMID : 28 .. 22,
  PPN  : 21 .. 0
}

// TODO: Add these options to config file once Hypervisor supported is added
let HBare_supported  : bool = true
let Sv32x4_supported : bool = HBare_supported  & xlen == 32
let Sv39x4_supported : bool = HBare_supported  & xlen == 64
let Sv48x4_supported : bool = Sv39x4_supported & xlen == 64
let Sv57x4_supported : bool = Sv48x4_supported & xlen == 64

// TODO: Consolidate with legalize_satp
// TODO: Add VMIDLEN config option and mask VMID field to implemented width
function legalize_hgatp(
  arch : Architecture,
  prev_value : xlenbits,
  written_value : xlenbits,
) -> xlenbits = {
  if xlen == 32 then {
    let v = Mk_Hgatp32(written_value);
    // Force 16 KiB alignment with PPN[1:0] = 0b00
    let h = Mk_Hgatp32(v[Mode] @ 0b00 @ v[VMID] @ v[PPN][21 .. 2] @ 0b00);
    match hgatpMode_of_bits(arch, 0b000 @ h[Mode]) {
      None() => prev_value,
      Some(mode) => match mode {
        HBare  if HBare_supported  => h.bits,
        Sv32x4 if Sv32x4_supported => h.bits,
        _ => prev_value,
      }
    }
  } else if xlen == 64 then {
    let v = Mk_Hgatp64(written_value);
    // Force 16 KiB alignment with PPN[1:0] = 0b00
    let h = Mk_Hgatp64(v[Mode] @ 0b00 @ v[VMID] @ v[PPN][43 .. 2] @ 0b00);
    match hgatpMode_of_bits(arch, h[Mode]) {
      None() => prev_value,
      Some(mode) => match mode {
        HBare  if HBare_supported  => h.bits,
        Sv39x4 if Sv39x4_supported => h.bits,
        Sv48x4 if Sv48x4_supported => h.bits,
        Sv57x4 if Sv57x4_supported => h.bits,
        _ => prev_value,
      }
    }
  } else {
    internal_error(__FILE__, __LINE__, "Unsupported xlen " ^ dec_str(xlen))
  }
}

register hgatp : xlenbits

mapping clause csr_name_map = 0x680 <-> "hgatp"

// TODO: Should raise virtual instruction exception if accessed by VU/VS-Mode.
// Needs refactoring of CSR access logic.
function clause is_CSR_accessible(0x680, priv, _) = currentlyEnabled(Ext_H) & (priv == Machine | (priv == Supervisor & mstatus[TVM] == 0b0))
function clause read_CSR(0x680) = hgatp
function clause write_CSR(0x680, value) = { hgatp = legalize_hgatp(architecture(cur_privilege), hgatp, value); Ok(hgatp) }

// Virtual Supervisor Registers

register vsatp : xlenbits

mapping clause csr_name_map = 0x280 <-> "vsatp"
function clause is_CSR_accessible(0x280, _, _) = currentlyEnabled(Ext_H)
function clause read_CSR(0x280) = vsatp
function clause write_CSR(0x280, value) = { vsatp = legalize_satp(architecture(cur_privilege), vsatp, value); Ok(vsatp) }

register vstvec : Mtvec
register vsepc  : xlenbits
