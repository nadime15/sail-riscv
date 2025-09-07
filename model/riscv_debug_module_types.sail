/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

type dmreg = bits(8)

// The `debug_request` argument to the `try_step` function below
// provides a mechanism to the external harness to control entry and
// exit into Debug Mode.  DR_Halt requests the model to enter Debug
// Mode, while DR_Resume requests the model to exit it.  DR_Halt is
// ignored when the model is already in Debug Mode, and DR_Resume is
// ignored when it is not.  DR_None does not request any change to the
// current debug mode.
enum debug_request = {DR_None, DR_Halt, DR_Resume, DR_Reset}

register debug_module_active_request : bool
register debug_module_request : debug_request = DR_None

// Conceptual bits of state
// NOTE: In theory, we should have unique bits for each hart.
register haltrequest : bool = false
register resumeack   : bool = false
// Optional
register haltonreset  : bool = false
register hartreset    : bool = false
register resethaltreq : bool = false
register keepalive    : bool = false

// "The DM receives halted, running and havereset from each hart"
// Indicates that the hart is running
register running   : bool = true
// Indicates that the hart is halted
register halted    : bool = false
// Indicates that a hart has experienced a reset
register havereset : bool = false

struct dm_status_bits = {
  allhavereset   : bool,
  anyhavereset   : bool,
  allresumeack   : bool,
  anyresumeack   : bool,
  allnonexistent : bool,
  anynonexistent : bool,
  allunavail     : bool,
  anyunavail     : bool,
  allrunning     : bool,
  anyrunning     : bool,
  allhalted      : bool,
  anyhalted      : bool,
  success        : bool,
}

struct dm_hart_status = {
  running  : bool,
  halted   : bool,
  havereset: bool,
  // The 'resume' bit is not part of the spec but helps us
  // to know whether the hart received a resume request
  resume : bool,
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
