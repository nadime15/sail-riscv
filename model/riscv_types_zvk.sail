/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

val zvk_valid_reg_overlap : (vregidx, vregidx, int) -> bool
function zvk_valid_reg_overlap(rs, rd, emul_pow) = {
  let reg_group_size = if emul_pow > 0 then 2 ^ emul_pow else 1;
  let rs_int = unsigned(vregidx_bits(rs));
  let rd_int = unsigned(vregidx_bits(rd));

  (rs_int + reg_group_size <= rd_int) | (rd_int + reg_group_size <= rs_int)
}

function zvk_check_encdec(EGW: int, EGS: int) -> bool = (unsigned(vl) % EGS == 0) & (unsigned(vstart) % EGS == 0) & (2 ^ get_lmul_pow() * VLEN) >= EGW

/*
 * Utility functions for Zvknh[ab]
 * ----------------------------------------------------------------------
 */

enum zvkfunct6 = {VV_VSHA2CH, VV_VSHA2CL}

function zvknhab_check_encdec(vs2: vregidx, vs1: vregidx, vd: vregidx) -> bool = {
  let SEW      = get_sew();
  let LMUL_pow = get_lmul_pow();
  let reg_overlap = zvk_valid_reg_overlap(vs1, vd, LMUL_pow) & zvk_valid_reg_overlap(vs2, vd, LMUL_pow);

  zvk_check_encdec(SEW, 4) & zvk_valid_reg_overlap(vs1, vd, LMUL_pow) & zvk_valid_reg_overlap(vs2, vd, LMUL_pow);
}

val ROTR : forall 'n 'm, 'm >= 0. (bits('n), bits('m), bits('m)) -> bits('n)
function ROTR (x, n, SEW) = (x >> n) | (x << (SEW - n))

val SHR : forall 'n 'm, 'm >= 0. (bits('n), bits('m)) -> bits('n)
function SHR (x, n) = x >> n

val sig0 : forall 'n 'm, 'n >= 0 & ('m == 32 | 'm == 64). (bits('n), int('m)) -> bits('n)
function sig0 (x, SEW) = {
  let sew_bits = to_bits('n, SEW);
  match SEW {
    32 => (ROTR(x, to_bits('n, 7), sew_bits) ^ ROTR(x, to_bits('n, 18), sew_bits) ^ SHR(x, to_bits('n, 3))),
    64 => (ROTR(x, to_bits('n, 1), sew_bits) ^ ROTR(x, to_bits('n, 8),  sew_bits) ^ SHR(x, to_bits('n, 7))),
  }
}

val sig1 : forall 'n 'm, 'n >= 0 & ('m == 32 | 'm == 64). (bits('n), int('m)) -> bits('n)
function sig1 (x, SEW) = {
  let sew_bits = to_bits('n, SEW);
  match SEW {
    32 => (ROTR(x, to_bits('n, 17), sew_bits) ^ ROTR(x, to_bits('n, 19), sew_bits) ^ SHR(x, to_bits('n, 10))),
    64 => (ROTR(x, to_bits('n, 19), sew_bits) ^ ROTR(x, to_bits('n, 61), sew_bits) ^ SHR(x, to_bits('n, 6 ))),
  }
}

val sum0 : forall 'n 'm, 'n >= 0 & ('m == 32 | 'm == 64). (bits('n), int('m)) -> bits('n)
function sum0 (x, SEW) = {
  let sew_bits : bits('n) = to_bits('n, SEW);
  match SEW {
    32 => (ROTR(x, to_bits('n, 2), sew_bits)  ^ ROTR(x, to_bits('n, 13), sew_bits) ^ ROTR(x, to_bits('n, 22), sew_bits)),
    64 => (ROTR(x, to_bits('n, 28), sew_bits) ^ ROTR(x, to_bits('n, 34), sew_bits) ^ ROTR(x, to_bits('n, 39), sew_bits)),
  }
}

val sum1 : forall 'n 'm, 'n >= 0 & ('m == 32 | 'm == 64). (bits('n), int('m)) -> bits('n)
function sum1 (x, SEW) = {
  let sew_bits : bits('n) = to_bits('n, SEW);
  match SEW {
    32 => (ROTR(x, to_bits('n, 6), sew_bits)  ^ ROTR(x, to_bits('n, 11), sew_bits) ^ ROTR(x, to_bits('n, 25), sew_bits)),
    64 => (ROTR(x, to_bits('n, 14), sew_bits) ^ ROTR(x, to_bits('n, 18), sew_bits) ^ ROTR(x, to_bits('n, 41), sew_bits)),
  }
}

val ch : forall 'n, 'n >= 0. (bits('n), bits('n), bits('n)) -> bits('n)
function ch (x, y, z) = ((x & y) ^ (~(x) & z))

val maj : forall 'n, 'n >= 0. (bits('n), bits('n), bits('n)) -> bits('n)
function maj (x, y, z) = ((x & y) ^ (x & z) ^ (y & z))
