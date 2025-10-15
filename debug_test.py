import telnetlib
import re
import time

HOST = "localhost"
PORT = 4444
PROMPT = b"> "
HEX_RE = re.compile(r"0x[0-9a-fA-F]+")

tn = telnetlib.Telnet(HOST, PORT, timeout=5)
tn.read_until(PROMPT)  # skip the banner until first prompt

def send_cmd(cmd):
    tn.write(cmd.encode() + b"\n")
    out = tn.read_until(PROMPT)
    return out.decode(errors="ignore")

def get_reg_abstract(regno, aarsize=3):
    """
    Force abstract register access by writing DMI registers directly
    regno: register number (0x103C for ft8)
    aarsize: 2=32-bit, 3=64-bit
    """
    # Build the command register value
    cmdtype = 0x00
    transfer = 1
    write = 0

    cmd = (cmdtype << 24) | (aarsize << 20) | (transfer << 17) | (write << 16) | regno

    # Write to command register (DMI address 0x17)
    send_cmd(f"riscv.cpu riscv dmi_write 0x17 0x{cmd:08x}")

    if aarsize == 3:  # 64-bit
        # Read data0 (lower 32 bits) - DMI address 0x04
        data0_str = send_cmd("riscv.cpu riscv dmi_read 0x04")
        lines = data0_str.splitlines()
        data0 = int(lines[1], 16)

        # Read data1 (upper 32 bits) - DMI address 0x05
        data1_str = send_cmd("riscv.cpu riscv dmi_read 0x05")
        lines = data1_str.splitlines()
        data1 = int(lines[1], 16)
        # Combine into 64-bit value: upper 32 bits | lower 32 bits
        value = (data1 << 32) | data0

        return value
    else:  # 32-bit
        data_str = send_cmd("riscv.cpu riscv dmi_read 0x04")
        value = int(HEX_RE.search(data_str).group(0), 16)
        return value

def get_reg(name):
    """
    reg 0x1
    NOTE: This will use the program buffer to load from and store to the regs!
    """
    out = send_cmd(f"reg {name}")
    m = HEX_RE.search(out)
    if not m:
        return None, out
    return int(m.group(0), 16), out

def get_cmderr(log=False):
    out = send_cmd("riscv.cpu riscv dmi_read 0x16")
    print(out)
    # 1. Extract the second line
    lines = out.splitlines()
    value_line = lines[1]

    # 2. Convert hex string to int
    val = int(value_line, 16)

    # 3. Extract bits 10-8
    bits_10_8 = (val >> 8) & 0b111
    #print(f"Hex: {value_line}, int: {val}, bits 10-8: {bits_10_8}")
    return bits_10_8

def get_hart_state():
    resp = send_cmd("riscv.cpu riscv dmi_read 0x11")
    lines = resp.splitlines()
    print(lines)
    if len(lines) < 2:
        return "unknown", resp
    try:
        val = int(lines[1], 16)
    except ValueError:
        # TODO
        return "unknown"
    halted = (val >> 8) & 1    # bit 8
    running = (val >> 11) & 1  # bit 11
    if halted:
        print("halted")
        return "halted"
    elif running:
        print("running")
        return "running"
    else:
        print("unknown")
        return "unknown"

def get_hart_have_reset():
    resp = send_cmd("riscv.cpu riscv dmi_read 0x11")
    lines = resp.splitlines()
    if len(lines) < 2:
        return "unknown", resp
    try:
        val = int(lines[1], 16)
    except ValueError:
        return "unknown", resp

    havereset = (val >> 19) & 1

    if havereset:
        return "havereset"
    else:
        return ""

def read_mem(cmd: str, addr: str):
    """
    Read memory via OpenOCD telnet using mdb/mdh/mdw/mdd.

    Args:
        cmd  : 'mdb', 'mdh', 'mdw', or 'mdd'
        addr : address to read (int)

    Returns:
        (address, value) tuple as integers
    """
    resp = send_cmd(f"riscv.cpu {cmd} {addr}")
    lines = resp.splitlines()
    if len(lines) < 2:
        raise ValueError(f"Unexpected response: {resp}")

    line = lines[1].strip()   # e.g. "0xf0000000: 00000008"
    if ":" not in line:
        raise ValueError(f"Malformed line: {line}")

    addr_str, val_str = line.split(":")
    a = int(addr_str.strip(), 16)
    v = int(val_str.strip(), 16)
    return a, v

def program_program_buffer():
    print(send_cmd("riscv.cpu riscv dmi_write 0x20 0x0000100F"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x21 0x0000000F"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x22 0x00100073"))

def test_halt_reset_resume():
    print(send_cmd("resume"))
    assert get_hart_state() == "running", "Hart is not running"

    print(send_cmd("halt"))
    assert get_hart_state() == "halted", "Hart is not halted"

    print(send_cmd("resume"))
    assert get_hart_state() == "running", "Hart is not running"

    print(send_cmd("halt"))
    assert get_hart_state() == "halted", "Hart is not halted"

    print(send_cmd("step"))
    assert get_hart_state() == "halted", "Hart is not halted"

    print(send_cmd("step"))
    assert get_hart_state() == "halted", "Hart is not halted"

    print(send_cmd("resume"))
    assert get_hart_state() == "running", "Hart is not running"

    # NOTE: Dont use the `reset` command because OpenOCD uses
    # ndmreset which resets all dmstatus bits as well (implementation defined behaviour)
    # To check whether the right status bits have been set we use hartreset and halt when
    # the reset bit is deasserted
    print(send_cmd("reset"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x10 0x20000001"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x10 0x80000001"))
    assert get_hart_state() == "halted", "Hart is not running"
    assert get_hart_have_reset() == "havereset", "Hart has not reset"


    # NOTE: Same as above but resume instead of halt
    print(send_cmd("resume"))
    assert get_hart_state() == "running", "Hart is not running"
    print(send_cmd("riscv.cpu riscv dmi_write 0x10 0x20000001"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x10 0x40000001"))
    assert get_hart_state() == "running", "Hart is not running"
    assert get_hart_have_reset() == "havereset", "Hart has not reset"

    # NOTE: Set setresethaltreq and halt after reset
    print(send_cmd("riscv.cpu riscv dmi_write 0x10 0x9"))
    print(send_cmd("reset"))
    assert get_hart_state() == "halted", "Hart is not halted"

def test_register_access():
    """
    Test register access cases through abstract commands:

    1.1 Read the `misa` register and confirm the expected value.
    1.2 Write a value to register `t6` and verify the write/read-back behavior.
    1.3 Attempt an unsupported access (aarsize = 0) and check that cmderr = 2.
    1.4 Attempt an out-of-range access and check that cmderr = 2.
    1.5 Access floating-point register `ft8` and validate error behavior depending on mstatus.FS.
    1.6 Execute the Program Buffer and confirm cmderr = 0.

    NOTE: These tests cannot be called repeatedly without first resetting the hart to its initial state,
    including the data* and progbuf* registers. Failing to do so may cause test failures.

    NOTE: These tests assume a RV64 system
    """

    print((send_cmd("halt")))
    assert get_hart_state() == "halted", "hart is not halted"

    ### 1.1 ###
    misa = get_reg_abstract(0x301) # misa
    assert misa == 0x800000000034112f, "Unexpected value"

    ### 1,2 ###
    value = 0x80000000
    # TODO: Replace get_reg with a function that writes values to data* and uses the abstract register access command
    get_reg(f"t6 {value}")
    assert get_cmderr() == 0, "cmderr is not 0"
    t6 = get_reg_abstract(0x101F) # t6
    assert t6 == value, "Unexpected value"
    assert get_cmderr() == 0, "cmderr is not 0"

    ### 1.3 ###
    print((send_cmd("riscv.cpu riscv dmi_write 0x17 0x0002ffff")))
    assert get_cmderr() == 2, "cmderr is not not supported"

    ### 1.4 ###
    print((send_cmd("riscv.cpu riscv dmi_write 0x17 0x0032ffff")))
    assert get_cmderr() == 2, "cmderr is not supported"

    ### 1.5 ###
    mstatus = get_reg_abstract(0x300) # mstatus
    FS = (mstatus >> 13) & 0b11
    get_reg_abstract(0x103C) # ft8
    if FS == 0:
       assert get_cmderr() == 3, "cmderr is not exception"
    else:
        assert get_cmderr() == 0, "cmderr is not 0"

    ### 1.6 ###
    program_program_buffer()
    print(send_cmd("riscv dmi_write 0x17 0x00240300"))
    assert get_cmderr() == 0, "cmderr is not 0"

    assert get_hart_state() == "halted", "hart is not halted"

def test_quick_access():
    """
    Test three cases:

    1.1 Execute the Program Buffer and verify that the hart is running afterward.
    1.2 Write 0x0 to probuf0 to trigger an exception, and confirm that the hart remains halted.

    2.0 Ensure the Debug Module sets CMDERR if the hart is not halted, using the quick access test case.
    """
    ### TEST 1.1 ###
    print(send_cmd("resume"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x17 0x01000000"))
    assert get_cmderr() == 0, "cmderr is not 0"
    assert get_hart_state() == "running", "Hart is not running"

    ### TEST 1.2 ###
    print(send_cmd("resume"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x20 0x0"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x17 0x01000000"))
    assert get_cmderr() == 3, "cmderr is not 3"
    assert get_hart_state() == "halted", "Hart is not halted"

    ### Test 2 ###
    print(send_cmd("resume"))
    print(send_cmd("halt"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x17 0x01000000"))
    assert get_cmderr() == 4, "cmderr is not 4"
    assert get_hart_state() == "halted", "Hart is not halted"

def test_access_memory():
    """
    NOTE: Using OpenOCD memory access commands like mwd, mdd, etc. is convenient,
    but OpenOCD performs additional internal operations beyond simply writing to the data*
    and command registers. For instance, if a memory access fails, OpenOCD automatically clears cmderr.
    If we need to verify that error codes are set correctly, we should manually perform the access.
    For example, write the data* registers and issue the abstract command yourself.
    """

    print(send_cmd("riscv.cpu riscv set_mem_access abstract"))

    # Test 1.1
    print(send_cmd("riscv.cpu mwd 0xF0000000 0x7654321076543210"))
    assert get_cmderr() == 0, "cmderr is not 0"

    # Test 1.2
    addr, value = read_mem("mdd", "0xf0000000")
    assert addr == 0xf0000000, "Unexpected memory address"
    assert value == 0x7654321076543210, "Unexpected memory address"
    assert get_cmderr() == 0, "cmderr is not 0"

    # Test 1.3
    print(send_cmd("riscv.cpu mwb 0xf0000004 0xfed"))
    assert get_cmderr() == 0, "cmderr is not 0"
    addr, value = read_mem("mdb", "0xf0000004")
    assert addr == 0xf0000004
    assert value == 0xed
    assert get_cmderr() == 0, "cmderr is not 0"

    # Test 1.4
    print(send_cmd("riscv.cpu mwh 0xf0000008 0xfedcba"))
    assert get_cmderr() == 0, "cmderr is not 0"
    addr, value = read_mem("mdh", "0xf0000008")
    assert addr == 0xf0000008
    assert value == 0xdcba
    assert get_cmderr() == 0, "cmderr is not 0"

    # Test 1.5
    print(send_cmd("riscv.cpu mwh 0xf0000008 0xfedcba"))
    assert get_cmderr() == 0, "cmderr is not 0"
    addr, value = read_mem("mdh", "0xf0000008")
    assert addr == 0xf0000008
    assert value == 0xdcba
    assert get_cmderr() == 0, "cmderr is not 0"

    # Test 1.5
    print(send_cmd("riscv.cpu mww 0xf000000C 0xaaaabcde"))
    assert get_cmderr() == 0, "cmderr is not 0"
    addr, value = read_mem("mdw", "0xf000000C")
    assert addr == 0xf000000c
    assert value == 0xaaaabcde
    assert get_cmderr() == 0, "cmderr is not 0"

    # Test 1.6
    print(send_cmd("riscv.cpu riscv dmi_write 0x17 0x02000001"))
    assert get_cmderr() == 2, "cmderr is not not supported"

    # Test 1.7
    print(send_cmd("riscv.cpu riscv dmi_write 0x6 0x0"))
    print(send_cmd("riscv.cpu riscv dmi_write 0x7 0x0"))
    # Execute: cmdtype=2, aamvirtual=0, aamsize=3, write=1
    print(send_cmd("riscv.cpu riscv dmi_write 0x17 0x02310000"))
    assert get_cmderr() == 3, "cmderr is not exception"

test_halt_reset_resume()
test_register_access()
test_quick_access()
test_access_memory()

print(send_cmd("resume"))

tn.close()

# NOTE: These tests cannot be called repeatedly without first resetting the hart to its initial state,
#       including the data* and progbuf* registers. Failing to do so may cause test failures.
#
# NOTE: Some tests might work while the hart is in M-Mode while some fail in S-Mode (this requires more testing)
#
# NOTE: Memory Access using the Access Memory command DOES NOT work in S-Mode at this point
#
# NOTE: Successfully tests with
# ./sail_riscv_sim --debug 9824 ../test/2025-07-16/riscv-tests/rv64um-p-mul --trace-instr --trace-debug --trace-mem
# ./sail_riscv_sim --debug 9824 ../test/2025-07-16/riscv-tests/rv64um-p-divw --trace-instr --trace-debug --trace-mem
# ./sail_riscv_sim --debug 9824 ../test/2025-07-16/riscv-tests/rv64ui-p-bge --trace-instr --trace-debug --trace-mem

# STEPS
# 1. Run Sail
# 2. Run OpenOCD (which needs to halt)
# 3. Run this script
