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

function determine_access_type(write : bits(1), transfer : bits(1)) -> access_type = {
  match (write, transfer) {
    (0b0, 0b1) => READ,
    (0b1, 0b1) => WRITE,
    (_,   0b0) => NO_TRANSFER
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
