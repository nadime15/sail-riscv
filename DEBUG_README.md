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

## How to talk to the core

Telnet offers a bunch of different commands,

Probably the most important for now are

`halt`, `resume` and `step` (The core must be in the HALT state in order to use step)

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

or you can even specify the register name (as far as I know thats only possible for CSR's)

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

Here are a few usuful commands:

```bash
$ poll off
```

Stops polling even when OpenOCD is in debug mode, greatly reducing unnecessary messages and log output.
