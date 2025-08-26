type dmreg = bits(8)

// The `debug_request` argument to the `try_step` function below
// provides a mechanism to the external harness to control entry and
// exit into Debug Mode.  DR_Halt requests the model to enter Debug
// Mode, while DR_Resume requests the model to exit it.  DR_Halt is
// ignored when the model is already in Debug Mode, and DR_Resume is
// ignored when it is not.  DR_None does not request any change to the
// current debug mode.
enum debug_request = {DR_None, DR_Halt, DR_Resume}

register debug_module_pending_request : debug_request = DR_None

struct debug_module_observe_status = {
  allhalted    : bool,
  anyhalted    : bool,
  allrunning   : bool,
  anyrunning   : bool,
  allhavereset : bool,
  anyhavereset : bool,
  success      : bool,
}

// TODO: Not used yet
struct debug_data = {
  // TODO: Make this a config option, we can have more data entries (up to 12)
  data : vector(if xlen == 32 then 1 else 2, bits(32)),
}

// Abstract Command Access Type
enum access_type = {
  READ,
  WRITE,
  NO_TRANSFER
}
