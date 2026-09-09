#!/usr/bin/python

import os, sys, json, copy, pathlib, argparse

def define_build_matrix_entries() -> list[dict]:
    entries : list[dict] = []

    entries.append({
        "os": "ubuntu-22.04",
        "cmake_version": "3.20.0",
        "first_party_tests": "true",
    })
    entries.append({
        "os": "ubuntu-22.04",
        "cmake_version": "4.1.2",
        "first_party_tests": "true",
        "run_all_steps": "true",
    })
    entries.append({
        "os": "ubuntu-24.04-arm",
        "cmake_version": "3.20.0",
        "first_party_tests": "true",
    })
    entries.append({
        "os": "ubuntu-24.04-arm",
        "cmake_version": "4.1.2",
        "first_party_tests": "true",
        "clang_tidy": "true",
    })
    entries.append({
        "os": "macos-latest",
        "cmake_version": "3.20.0",
        "first_party_tests": "true",
    })
    entries.append({
        "os": "macos-latest",
        "cmake_version": "4.1.2",
        "first_party_tests": "true",
    })
    entries.append({
        "os": "ubuntu-latest",
        "container": "rockylinux:8.9.20231119",
        "cmake_version": "3.20.0",
        "first_party_tests": "false",
    })
    entries.append({
        "os": "ubuntu-24.04-arm",
        "container": "rockylinux:8.9.20231119",
        "cmake_version": "3.20.0",
        "first_party_tests": "false",
    })

    return entries

def all_vector_tests() -> list[str]:
    # Match the combinations in `test/CMakeLists.txt`.
    return [f"riscv-vector-tests-v{vlen}x{elen}" for vlen in [64, 128, 256, 512] for elen in [32, 64] if vlen != 512 or elen != 32]

def default_vector_tests() -> list[str]:
    return ["riscv-vector-tests-v64x64", "riscv-vector-tests-v128x32" ]

def sail_riscv_tests(all: bool) -> list[str]:
    vector_tests = all_vector_tests() if all else default_vector_tests()
    tests = ["riscv-tests", "riscv-arch-tests", "damo-tests"]
    tests.extend(vector_tests)
    return tests

def make_test_names(tests: list[str]) -> list[str]:
    tests = [t.upper().replace('-', '_') for t in tests]
    return tests

def one_build_per_platform(build_entries: list[dict]) -> list[dict]:
    # Run the test suites once per platform (os + container), not once
    # per CMake version.
    groups : dict = {}
    for e in build_entries:
        key = (e["os"], e.get("container"))
        groups.setdefault(key, []).append(e)
    picked : list[dict] = []
    for entries in groups.values():
        best = next((e for e in entries if e.get("run_all_steps") == "true"), entries[-1])
        picked.append(best)
    return picked

def test_matrix_include(build_entries: list[dict], all: bool) -> list[dict]:
    entries : list[dict] = []
    tests = sail_riscv_tests(all)

    for e in one_build_per_platform(build_entries):
        for t in tests:
            t_ent = copy.deepcopy(e)
            t_ent["test"] = t
            entries.append(t_ent)

    return entries

def gen_output(opts, entries):
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        # eliminate whitespace in json
        json_output = json.dumps(entries, separators=(",", ":"))
        tag = None
        if opts.build:
            tag = "build_include"
        elif opts.test:
            tag = "test_include"
        elif opts.names:
            tag = "test_names"
        elif opts.all_names:
            tag = "all_test_names"
        assert(tag != None)
        with pathlib.Path(github_output).open("a") as f:
            f.write(f"{tag}={json_output}\n")
    else:
        print(json.dumps(entries, indent=2))

def show_build_matrix(opts):
    build_include  = define_build_matrix_entries()
    gen_output(opts, build_include)

def show_test_matrix(opts):
    build_include = define_build_matrix_entries()
    test_include = test_matrix_include(build_include, False)
    gen_output(opts, test_include)

def show_test_names(opts):
    all : bool = True if opts.all_names else False
    names = make_test_names(sail_riscv_tests(all))
    gen_output(opts, names)

def cli_parser():
    parser = argparse.ArgumentParser(description="Generate CI matrix entries")
    parser.add_argument('-b', '--build', action='store_const', const=True, help="generate build matrix")
    parser.add_argument('-t', '--test', action='store_const', const=True, help="generate test matrix")
    parser.add_argument('-n', '--names', action='store_const', const=True, help="generate default test suite names")
    parser.add_argument('-a', '--all-names', action='store_const', const=True, help="generate all test suite names")
    return parser

def main() -> int:
    parser = cli_parser()
    cliopts = sys.argv[1:]
    if len(cliopts) == 0:
        parser.print_help()
        sys.exit(0)

    opts = parser.parse_args(cliopts)
    if opts.build:
        show_build_matrix(opts)
    elif opts.test:
        show_test_matrix(opts)
    elif opts.names or opts.all_names:
        show_test_names(opts)

    return 0

if __name__ == "__main__":
  sys.exit(main())
