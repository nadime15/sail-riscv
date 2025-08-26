
/* Mapping of Debug Module Register addresses to their names. */
val dm_name_map : dmreg <-> string

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

/* Returns new value (after legalisation) if the Debug Module Register is defined */
val write_DM_reg : (dmreg, bits(32)) -> bits(32)
scattered function write_DM_reg
