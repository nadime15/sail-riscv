function send_request(request : debug_request) -> debug_module_observe_status = {
  // The global variable below stores the current request from the debug module
  // which is then used in try_step()
  debug_module_pending_request = request;
  let t : debug_module_observe_status = struct { allhalted  = request == DR_Halt,
                                                 anyhalted  = request == DR_Halt,
                                                 allrunning = request == DR_Resume,
                                                 anyrunning = request == DR_Resume,
                                                 // TODO
                                                 allhavereset = false,
                                                 anyhavereset = false,
                                                 success = true };
  t
  }


function determine_access_type(write : bits(1), transfer : bits(1)) -> access_type = {
  match (write, transfer) {
    (0b0, 0b1) => READ,
    (0b1, 0b1) => WRITE,
    (_,   0b0) => NO_TRANSFER
  }
}

// Helper function to split a value into data registers based on xlen
//function store_to_data_regs(value : xlenbits) -> unit = {
//  match xlen {
//    32 => data0 = value,
//    64 => {
//      data0 = value[31 .. 0];
//      data1 = value[63 .. 32];
//    },
//    _ => internal_error(__FILE__, __LINE__, "Unsupported xlen")
//  }
//}

// Helper function to combine data registers into a value based on xlen
//function load_from_data_regs() -> xlenbits = {
// match xlen {
//    32 => data0,
//    64 => data1 @ data0,
//    _ => {
//      internal_error(__FILE__, __LINE__, "Unsupported xlen");
//      zeros()
//    }
//  }
//}
