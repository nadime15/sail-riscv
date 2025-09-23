# How to launch external Debugger and communicate with Sail

## Getting started

We are going to launch 3 different processes:

### 1.

We have to launch the Debug Transport Hardware which communicates via the bitbang protocol (over network sockets) with openocd.

The following command launches the the jtag modules which opens and listens on port 9842:

```bash
$ ./sail_riscv_sim --debug 9824 ../test/2025-07-16/riscv-tests/rv64uf-p-fcvt_w --trace-instr
```

### 2.

```bash
$ openocd -f sail.cfg
```

Or optional to enable debugging:

```bash
$ openocd -f sail.cfg -d
```

### 3.

```bash
$ telnet localhost 4444
```

Once launched you should see the following:

```bash
$ Trying 127.0.0.1...
$ Connected to localhost.
$ Escape character is '^]'.
$ Open On-Chip Debugger
```

Note: Currently, the core starts executing immediately and does not wait for an OpenOCD connection to halt it. To enter debug mode, you must issue the OpenOCD command before Sail finishes execution.

## How to talk to the core

Telnet offers a bunch of different commands,

Probably the most important for now are

`halt`, `resume` and `step` (The core must be in the HALT state in order to use step)

### Halt and Reset (Enter Debug Mode right after Reset)

According to the specification, it is also possible to enter debug mode immediately after reset is deasserted, provided that either `hartreset` or `haltonreset` is set.

One way to achieve this is by using `hartreset` (`ndmreset` works as well but with different encoding). First, we initiate a reset by setting hartreset = 1 (while keeping dmactive set):

```bash
0x20000001
```

At this point, the debugger asserts the reset signal and the hart becomes unavailable. Next, we deassert `hartreset` and assert haltreq:

```bash
0x80000001
```

When `hartreset` is deasserted, the reset process completes. Execution begins at the reset vector, but before the first instruction is executed, the hart enters debug mode.

### Halt-On-Request (Enter Debug Mode right after Reset)

It’s possible to enter debug mode immediately after resetting the hart. Normally, when a hart is reset, it continues execution automatically, which makes it harder to step at the exact instruction you want.

By setting `setresethaltreq` in dmstatus, we can instruct the hart to enter debug mode right after a reset. To use this feature, first set `setresethaltreq` by running the following telnet command:

```bash
riscv dmi_write 0x10 0x9
```

This writes the value 0x9 to `dmcontrol` (0x10), which sets `dmactive` (we need to write 1 here to avoid triggering a reset by writing 0) and `setresethaltreq` to 1.

Now you can do:

```bash
reset
```

This will trigger a reset and immediately enter debug mode.

To clear `setresethaltreq` (set it back to 0), write 1 to `clrresethaltreq`:

```bash
riscv dmi_write 0x10 0x5
```

This clears `setresethaltreq` and restores normal hart behavior.

### Read and Write Registers

In order to read and write to registers you either do for a write

```bash
$ reg 1 0x23
ra (/64): 0x0000000000000023
```

which writes the value 0x23 into 0x1.

or if you just want to read the register:

```bash
$ reg 1
$ ra (/64): 0x0000000000000023
```

or you can even specify the register name (as far as I know that's only possible for CSR's)

```bash
$ reg mstatus
$ mstatus (/64): 0x0000000a00001800
```

By typing into the command line:

```bash
$ riscv
```

You should get an overview of many riscv specific commands:

```bash
> riscv
riscv
  riscv authdata_read [index]
  riscv authdata_write [index] value
  riscv dmi_read address
  riscv dmi_write address value
  riscv expose_csrs n0[-m0|=name0][,n1[-m1|=name1]]...
  riscv expose_custom n0[-m0|=name0][,n1[-m1|=name1]]...
  riscv info
  riscv reset_delays [wait]
  riscv resume_order normal|reversed
  riscv set_command_timeout_sec [sec]
  riscv set_ebreakm on|off
  riscv set_ebreaks on|off
  riscv set_ebreaku on|off
  riscv set_enable_virt2phys on|off
  riscv set_enable_virtual on|off
  riscv set_ir [idcode|dtmcs|dmi] value
  riscv set_mem_access method1 [method2] [method3]
  riscv set_reset_timeout_sec [sec]
  riscv use_bscan_tunnel value [type]
riscv.cpu
  riscv.cpu arm
    riscv.cpu arm semihosting ['enable'|'disable']
    riscv.cpu arm semihosting_basedir [dir]
    riscv.cpu arm semihosting_cmdline arguments
    riscv.cpu arm semihosting_fileio ['enable'|'disable']
    riscv.cpu arm semihosting_read_user_param
    riscv.cpu arm semihosting_redirect (disable | tcp <port>
              ['debug'|'stdio'|'all'])
    riscv.cpu arm semihosting_resexit ['enable'|'disable']
  riscv.cpu arp_examine ['allow-defer']
  riscv.cpu arp_halt
  riscv.cpu arp_halt_gdb
  riscv.cpu arp_poll
  riscv.cpu arp_reset 'assert'|'deassert' halt
  riscv.cpu arp_waitstate statename timeoutmsecs
  riscv.cpu cget target_attribute
  riscv.cpu configure [target_attribute ...]
  riscv.cpu curstate
  riscv.cpu debug_reason
  riscv.cpu eventlist
  riscv.cpu examine_deferred
  riscv.cpu get_reg [-force] list
  riscv.cpu invoke-event event_name
  riscv.cpu mdb address [count]
  riscv.cpu mdd address [count]
  riscv.cpu mdh address [count]
  riscv.cpu mdw address [count]
  riscv.cpu mwb address data [count]
  riscv.cpu mwd address data [count]
  riscv.cpu mwh address data [count]
  riscv.cpu mww address data [count]
  riscv.cpu read_memory address width count ['phys']
  riscv.cpu riscv
    riscv.cpu riscv authdata_read [index]
    riscv.cpu riscv authdata_write [index] value
    riscv.cpu riscv dmi_read address
    riscv.cpu riscv dmi_write address value
    riscv.cpu riscv expose_csrs n0[-m0|=name0][,n1[-m1|=name1]]...
    riscv.cpu riscv expose_custom n0[-m0|=name0][,n1[-m1|=name1]]...
    riscv.cpu riscv info
    riscv.cpu riscv reset_delays [wait]
    riscv.cpu riscv resume_order normal|reversed
    riscv.cpu riscv set_command_timeout_sec [sec]
    riscv.cpu riscv set_ebreakm on|off
    riscv.cpu riscv set_ebreaks on|off
    riscv.cpu riscv set_ebreaku on|off
    riscv.cpu riscv set_enable_virt2phys on|off
    riscv.cpu riscv set_enable_virtual on|off
    riscv.cpu riscv set_ir [idcode|dtmcs|dmi] value
    riscv.cpu riscv set_mem_access method1 [method2] [method3]
    riscv.cpu riscv set_reset_timeout_sec [sec]
    riscv.cpu riscv use_bscan_tunnel value [type]
  riscv.cpu set_reg dict
  riscv.cpu smp [on|off]
  riscv.cpu smp_gdb
  riscv.cpu was_examined
  riscv.cpu write_memory address width data ['phys']
```

## Helpful commands (Telnet)

Here are a few useful commands:

Stops polling even when OpenOCD is in debug mode, greatly reducing unnecessary messages and log output.

```bash
$ poll off
```

Shows information about all available harts

```bash
$ targets
    TargetName         Type       Endian TapName            State
--  ------------------ ---------- ------ ------------------ ------------
 0* riscv.cpu          riscv      little riscv.cpu          halted
```

## What happens under the hood (Telnet Commands)

### Step

Telnet sets the `step` bit in `dcsr`, causing the core to enter debug mode and halt at the end of the next instruction. When the Telnet command `step` is used, the external debugger sends a resume request, the core executes a single instruction, and then halts again. This process can be repeated by using `step` multiple times. To exit single step mode, simply use the `resume` command, which clears the stepper mode and continues normal execution.

Note: To halt must be halted in order to use `step`

# Program Buffer

The Debug Module registers `progbuf0`–`progbuf15` are accessed by the hart through memory, since they are memory-mapped. They reside at:

```bash
"debug_module:" {
  ...
  "num_prog_reg": 16,
  program_buffer: {
    "supported" true,
    "base": 8192,
    "size": 64
  }
}
```

Right after the ROM. In total, there are 16 registers available, which can be programmed via the debug module. For now the hart has only read access to these Registers (the debugger can still read/write these registers).

`size` specifies the number of bytes allocated for the program buffer (`progbuf0-progbuf15`) memory-mapped registers. Valid values range from 0 to 64, and must be multiples of 4.

The `num_prog_buf` parameter defines how many progbuf registers are implemented in total (up to 16). It is possible to implement all 16 registers but expose only a subset through memory mapping, for example, setting num_prog_buf = 16 but size = 32 maps only 8 registers to memory. Which means the debugger has access to all `progbuf*` registers but the hart only can access `probuf0` - `progbuf7`

It is recommended to keep the number of available progbuf registers consistent with the number of memory-mapped registers.

OpenOCD will print out the number of available `progbuf` registers:

```bash
Info : datacount=12 progbufsize=16
```

## OpenOCD and the Program Buffer

It seems like that OpenOCD makes use of the program buffer and writes into progbuf0 and progbuf1 the following code:

```bash
[265] [M]: 0x0000000000002000 (0xC2202473) csrrs x8, vlenb, x0
[266] [M]: 0x0000000000002004 (0x00100073) ebreak
```

The code above is part of OpenOCD's initialization step and determines VLEN in bytes.

```bash
Info : Vector support with vlenb=32
```

The Program Buffer can executed by setting `command[postexec]` to 1 as part of an abstract command.

Stepping through the code via `step` will trigger every time the following series of instructions:

```bash
DEBUG: Entering debug mode via single step
entering Debug mode from U
Start Abstract Command
[302244] [M]: 0x0000000000002000 (0x0000100F) fence.i
[302245] [M]: 0x0000000000002004 (0x0000000F) fence 0, 0
[302246] [M]: 0x0000000000002008 (0x00100073) ebreak
End Abstract Command
exiting Debug mode to U
```
