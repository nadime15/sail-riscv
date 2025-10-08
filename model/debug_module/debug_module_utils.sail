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

function is_unsupported_reg_access(aarsize : bits(3), addr : bits(16)) -> bool = {
  let width = unsigned(aarsize);
  match addr {
    addr if 0x1000 <=_u addr & addr <=_u 0x101f => width == 3 & dxlen == 32,
    addr if 0x1020 <=_u addr & addr <=_u 0x103f => width == 3 & flen == 32,
    _ => false
  };
}

function is_valid_aarsize(aarsize : bits(3)) -> bool = {
  let size = unsigned(aarsize);
  if size < 2 | size > 4 then false
  else match dxlen {
    32 => size == 2,
    64 => size == 2 | size == 3,
    _ => false,
  }
}

function is_valid_aamsize(aamsize : bits(3)) -> bool = {
  let size = unsigned(aamsize);
  if size > 4 then false
  else match dxlen {
    32 => size <= 2,
    64 => size <= 3,
    _ => false,
  }
}

function aamsize_to_bytes(aamsize : bits(3)) -> word_width = {
  let size = unsigned(aamsize);
  assert(size < 4, "aamsize value exceeds maximum");
  match size {
    0 => 1,
    1 => 2,
    2 => 4,
    3 => 8,
  }
}
