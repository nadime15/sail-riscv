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

enum zvkfunct6 = {ZVK_VAESDFVV, ZVK_VAESDFVS, ZVK_VAESDMVV, ZVK_VAESDMVS, ZVK_VAESEFVV, ZVK_VAESEFVS, ZVK_VAESEMVV, ZVK_VAESEMVS, ZVK_VSHA2CH, ZVK_VSHA2CL}

/*
 * Utility functions for Zvkned
 * ----------------------------------------------------------------------
 */

function aes_rotword(x : bits(32)) -> bits(32) = x[7.. 0] @ x[31..24] @ x[23..16] @ x[15.. 8]
