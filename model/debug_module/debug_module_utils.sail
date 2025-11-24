/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

function send_debug_request(request : DebugRequest) -> unit = {
  debug_module_request = request;
  debug_module_active_request = true;
}

function is_supported_reg_access(aarsize : bits(3), regno : bits(16)) -> bool = {
  let aarsize = unsigned(aarsize);
  // We only support 32-bit and 64-bit access
  if not(aarsize == 2 | aarsize == 3) then false
  else {
    match regno {
      // Cover both CSRs and GPRs
      regno if regno <=_u REGNO_GPR_MAX => not(aarsize == 3 & dxlen == 32),
      // Cover FPRs
      regno if regno <=_u REGNO_FPR_MAX => not(aarsize == 3 & flen == 32),
      _ => false
    };
  }
}

function is_valid_aamsize(aamsize : bits(3)) -> bool = {
  let aamsize = unsigned(aamsize);
  if aamsize > 4 then false
  else match dxlen {
    32 => aamsize <= 2,
    64 => aamsize <= 3,
    _ => false,
  }
}

function aamsize_to_bytes(aamsize : bits(3)) -> word_width = {
  let aamsize = unsigned(aamsize);
  assert(aamsize < 4, "aamsize value exceeds maximum");
  match aamsize {
    0 => 1,
    1 => 2,
    2 => 4,
    3 => 8,
  }
}
