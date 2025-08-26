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
