/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

// The DMI read/write interfaces connect the Debug Transport Module to the Debug Module,
// bridging external debuggers like GDB (via OpenOCD) with internal components.
// These interfaces are just one of many options and can be replaced by simple handshake
// protocols or more complex bus protocols like AMBA to simulate hardware behavior.





// Debug module interface read
// Returns success status and 32-bit data read from the given 32-bit address
function dmi_read(address : nat) -> (bool, nat) = {
  // TODO
  let bits_address = to_bits_truncate(8, address);
  let read = read_DM_reg(bits_address);
  print_log("DMI Read: Address = " ^ bits_str(bits_address) ^ " Read = " ^ bits_str(read) ^ ", Register = " ^ dm_name_map(bits_address));
  (true, unsigned(read))
}

// Debug module interface write
// Returns success status after writing 32-bit value to the given 32-bit address
function dmi_write(address : nat, value : nat) -> bool = {
  // TODO
  let bits_address = to_bits_truncate(8, address);
  let bits_value = to_bits_truncate(32, value);
  print_log("DMI Write: Address = " ^ bits_str(bits_address) ^ ", Write = " ^ bits_str(bits_value) ^ ", Register = " ^ dm_name_map(bits_address));
  let a = write_DM_reg(bits_address, bits_value);
  true
}


///////////////////////////////////////////////////////////////////////

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
