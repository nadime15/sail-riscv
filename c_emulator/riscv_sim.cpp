#include <chrono>
#include <cinttypes>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "CLI11.hpp"
#include "config_utils.h"
#include "elf_loader.h"
#include "file_utils.h"
#include "jsoncons/config/version.hpp"
#include "jsoncons/json.hpp"
#include "riscv_model_impl.h"
#include "riscv_sim_utils.h"
#include "sail.h"
#include "sail_config.h"
#include "sail_riscv_version.h"
#include "simulator.h"

#ifdef SAILCOV
#include "sail_coverage.h"
#endif

namespace {

#ifdef SAILCOV
std::string sailcov_file;
#endif

} // namespace

static void print_dts(ModelImpl &model) {
  char *dts = nullptr;
  model.zgenerate_dts(&dts, UNIT);
  fprintf(stdout, "%s", dts);
  KILL(sail_string)(&dts);
}

static void print_isa(ModelImpl &model) {
  char *isa = nullptr;
  model.zgenerate_canonical_isa_string(&isa, UNIT);
  fprintf(stdout, "%s\n", isa);
  KILL(sail_string)(&isa);
}

static void print_build_info() {
  std::cout << "Sail RISC-V release: " << version_info::release_version << std::endl;
  std::cout << "Sail RISC-V git: " << version_info::git_version << std::endl;
  std::cout << "Sail: " << version_info::sail_version << std::endl;
  std::cout << "C++ compiler: " << version_info::cxx_compiler_version << std::endl;
  std::cout << "CLI11: " << CLI11_VERSION << std::endl;
  std::cout << "ELFIO: " << ELFIO_VERSION << std::endl;
  std::cout << "JSONCONS: " << jsoncons::version() << std::endl;
}

static jsoncons::json parse_json_or_exit(const std::string &json_text, const std::string &source_desc) {
  try {
    return jsoncons::json::parse(json_text);
  } catch (const jsoncons::json_exception &e) {
    std::cerr << "JSON parse error in " << source_desc << ":\n" << e.what() << "\n\n";
    exit(EXIT_FAILURE);
  }
}

void deep_merge_json(jsoncons::json &base, const jsoncons::json &json_override) {
  for (const auto &entry : json_override.object_range()) {
    const auto &key = entry.key();
    const auto &value = entry.value();
    if (base.contains(key) && base[key].is_object() && value.is_object()) {
      deep_merge_json(base[key], value);
    } else {
      base[key] = value;
    }
  }
}

struct CLIOptions {
  // Print-and-exit modes
  bool do_show_times = false;
  bool do_print_version = false;
  bool do_print_build_info = false;
  bool do_print_default_config = false;
  bool do_print_config_schema = false;
  bool do_print_dts = false;
  bool do_validate_config = false;
  bool do_print_isa = false;

  // Config / inputs
  bool use_rv32_default = false;
  std::string config_file;
  std::vector<std::string> config_overrides;
  std::string dtb_file;
  std::vector<std::string> elfs;

  // Model-side flags (passed to model.set_config_*, NOT to Simulator)
  bool config_print_instr = false;
  bool config_print_clint = false;
  bool config_print_exception = false;
  bool config_print_interrupt = false;
  bool config_print_htif = false;
  bool config_print_pma = false;
  bool config_print_step = false; // also mirrored into sim_cfg.trace_step
  bool config_enable_experimental_extensions = false;

  // Everything that flows into Simulator goes directly into this.
  riscv_sim::SimulatorConfig sim;
};

static CLIOptions parse_cli(int argc, char **argv) {
  CLI::App app("Sail RISC-V Model");
  argv = app.ensure_utf8(argv);

  CLIOptions opts;
  auto &sim = opts.sim;

  // --- Print-and-exit / mode flags ---
  app.add_flag("--show-times", sim.show_times, "Show execution times");
  app.add_flag("--version", opts.do_print_version, "Print model version");
  app.add_flag("--build-info", opts.do_print_build_info, "Print build information");
  app.add_flag("--print-default-config", opts.do_print_default_config, "Print default configuration");
  app.add_flag("--print-config-schema", opts.do_print_config_schema, "Print configuration schema");
  app.add_flag("--validate-config", opts.do_validate_config, "Exit after config validation (it is always validated)");
  app.add_flag("--print-device-tree", opts.do_print_dts, "Print device tree");
  app.add_flag("--print-isa-string", opts.do_print_isa, "Print ISA string");
  app.add_flag(
    "--enable-experimental-extensions",
    opts.config_enable_experimental_extensions,
    "Enable experimental extensions"
  );
  app.add_flag("--use-abi-names", sim.use_abi_names, "Use ABI register names in trace log");
  app.add_flag("--rv32", opts.use_rv32_default, "Use the default RV32 configuration");

  bool disable_trap_loop_detection = false;
  app.add_flag(
    "--disable-trap-loop-detection",
    disable_trap_loop_detection,
    "Disable detection of potentially infinite trap loops"
  );

  // --- File / value options ---
  app.add_option("--device-tree-blob", opts.dtb_file, "Device tree blob file")
    ->check(CLI::ExistingFile)
    ->option_text("<file>");
  app.add_option("--terminal-log", sim.term_log_path, "Terminal log output file")->option_text("<file>");
  app.add_option("--test-signature", sim.sig_file, "Test signature file")->option_text("<file>");
  app.add_option("--config", opts.config_file, "Configuration file")
    ->check(CLI::ExistingFile)
    ->option_text("<file>")
    ->excludes("--rv32");
  app
    .add_option(
      "--config-override",
      opts.config_overrides,
      "Configuration override file (repeatable; later files override earlier ones)."
    )
    ->check(CLI::ExistingFile)
    ->option_text("<file>")
    ->allow_extra_args(false);
  app.add_option("--trace-output", sim.trace_log_path, "Trace output file")->option_text("<file>");
  app.add_option("--signature-granularity", sim.sig_granularity, "Signature granularity")->option_text("<uint>");
  app.add_option("--rvfi-dii", sim.rvfi_dii_port, "RVFI DII port")
    ->check(CLI::Range(1, 65535))
    ->option_text("<int> (within [1 - 65535])");
  app.add_option("--inst-limit", sim.insn_limit, "Instruction limit")->option_text("<uint>");
#ifdef SAILCOV
  app.add_option("--sailcov-file", sailcov_file, "Sail coverage output file")->option_text("<file>");
#endif

  // --- Trace flags ---
  app.add_flag("--trace-instr", opts.config_print_instr, "Enable trace output for instruction execution");
  app.add_flag("--trace-ptw", sim.trace_ptw, "Enable trace output for Page Table walk");
  app.add_flag("--trace-tlb", sim.trace_tlb, "Enable trace output for TLB adds and flushes");
  app.add_flag("--trace-gpr", sim.trace_gpr, "Enable trace output for general purpose register reads/writes");
  app.add_flag("--trace-fpr", sim.trace_fpr, "Enable trace output for floating-point register reads/writes");
  app.add_flag("--trace-vreg", sim.trace_vreg, "Enable trace output for vector register reads/writes");
  app.add_flag("--trace-csr", sim.trace_csr, "Enable trace output for CSR reads/writes");
  app.add_flag_callback(
    "--trace-arch-regs",
    [&sim] {
      sim.trace_gpr = true;
      sim.trace_fpr = true;
      sim.trace_vreg = true;
    },
    "Enable trace output for architectural register reads and writes"
  );
  app.add_flag_callback(
    "--trace-reg",
    [&sim] {
      sim.trace_gpr = true;
      sim.trace_fpr = true;
      sim.trace_vreg = true;
      sim.trace_csr = true;
    },
    "Enable trace output for register access"
  );
  app.add_flag("--trace-mem", sim.trace_mem_access, "Enable trace output for memory accesses");
  app.add_flag("--trace-rvfi", sim.trace_rvfi, "Enable trace output for RVFI");
  app.add_flag("--trace-clint", opts.config_print_clint, "Enable trace output for CLINT memory accesses and status");
  app.add_flag("--trace-exception", opts.config_print_exception, "Enable trace output for exceptions");
  app.add_flag("--trace-interrupt", opts.config_print_interrupt, "Enable trace output for interrupts");
  app.add_flag("--trace-htif", opts.config_print_htif, "Enable trace output for HTIF operations");
  app.add_flag("--trace-pma", opts.config_print_pma, "Enable trace output for PMA checks");
  app.add_flag_callback(
    "--trace-platform",
    [&opts] {
      opts.config_print_clint = true;
      opts.config_print_exception = true;
      opts.config_print_interrupt = true;
      opts.config_print_htif = true;
      opts.config_print_pma = true;
    },
    "Enable trace output for platform-level events"
  );
  app.add_flag("--trace-step", opts.config_print_step, "Add a blank line between steps in the trace output");
  app.add_flag_callback(
    "--trace",
    [&opts, &sim] {
      opts.config_print_instr = true;
      sim.trace_gpr = true;
      sim.trace_fpr = true;
      sim.trace_vreg = true;
      sim.trace_csr = true;
      sim.trace_mem_access = true;
      sim.trace_rvfi = true;
      opts.config_print_clint = true;
      opts.config_print_exception = true;
      opts.config_print_interrupt = true;
      opts.config_print_htif = true;
      opts.config_print_pma = true;
      opts.config_print_step = true;
    },
    "Enable all trace output except TLB and PTW traces"
  );

  app.add_option("elfs", opts.elfs, "List of ELF files to load.");

  std::size_t column_width = 45;
  app.get_formatter()->long_option_alignment_ratio(6.f / column_width);
  app.get_formatter()->column_width(column_width);

  if (argc == 1) {
    fprintf(stdout, "%s\n", app.help().c_str());
    exit(EXIT_FAILURE);
  }
  try {
    app.parse(argc, argv);
  } catch (const CLI::ParseError &e) {
    exit(app.exit(e));
  }

  // Mirror the few flags that the model needs but that also affect Simulator.
  sim.trace_instr = opts.config_print_instr;
  sim.trace_step = opts.config_print_step;
  sim.enable_trap_loop_detection = !disable_trap_loop_detection;

  return opts;
}

void init_platform_constants(ModelImpl &model) {
  model.set_reservation_set_size_exp(get_config_uint64({"platform", "reservation", "reservation_set_size_exp"}));
  model.set_reservation_require_exact_addr_match(
    get_config_bool({"platform", "reservation", "require_exact_reservation_addr"})
  );
}

int inner_main(int argc, char **argv) {
  CLIOptions opts = parse_cli(argc, argv);
  ModelImpl model;

  // --- Print-and-exit options ---
  if (opts.do_print_version) {
    std::cout << version_info::release_version << std::endl;
    return EXIT_SUCCESS;
  }
  if (opts.do_print_build_info) {
    print_build_info();
    return EXIT_SUCCESS;
  }
  if (opts.do_print_default_config) {
    printf("%s", opts.use_rv32_default ? get_default_rv32_config() : get_default_config());
    return EXIT_SUCCESS;
  }
  if (opts.do_print_config_schema) {
    printf("%s", get_config_schema());
    return EXIT_SUCCESS;
  }

  const bool use_rvfi = (opts.sim.rvfi_dii_port != 0);

  // --- Info messages ---
  if (opts.sim.show_times) {
    fprintf(stderr, "will show execution times on completion.\n");
  }
  if (!opts.sim.term_log_path.empty()) {
    fprintf(stderr, "using %s for terminal output.\n", opts.sim.term_log_path.c_str());
  }
  if (!opts.sim.sig_file.empty()) {
    fprintf(stderr, "using %s for test-signature output.\n", opts.sim.sig_file.c_str());
  }
  if (opts.sim.sig_granularity != 4) {
    fprintf(stderr, "setting signature-granularity to %d bytes\n", opts.sim.sig_granularity);
  }
  if (opts.config_enable_experimental_extensions) {
    fprintf(stderr, "enabling unratified extensions.\n");
    model.set_enable_experimental_extensions(true);
  }
  if (!opts.sim.trace_log_path.empty()) {
    fprintf(stderr, "using %s for trace output.\n", opts.sim.trace_log_path.c_str());
  }

  // --- Pre-init model config flags ---
  model.set_config_print_instr(opts.config_print_instr);
  model.set_config_print_clint(opts.config_print_clint);
  model.set_config_print_exception(opts.config_print_exception);
  model.set_config_print_interrupt(opts.config_print_interrupt);
  model.set_config_print_htif(opts.config_print_htif);
  model.set_config_print_pma(opts.config_print_pma);
  model.set_config_rvfi(use_rvfi);
  model.set_config_use_abi_names(opts.sim.use_abi_names);
  model.set_config_print_step(opts.config_print_step);

  // --- JSON config + overrides ---
  std::string config_json_string = opts.config_file.empty()
                                     ? (opts.use_rv32_default ? get_default_rv32_config() : get_default_config())
                                     : read_file_to_string(opts.config_file);

  const std::string base_source_desc =
    opts.config_file.empty() ? "default configuration" : "configuration file " + opts.config_file;
  jsoncons::json config_json = parse_json_or_exit(config_json_string, base_source_desc);
  for (const auto &override_path : opts.config_overrides) {
    std::string override_json_string = read_file_to_string(override_path);
    jsoncons::json override_item = parse_json_or_exit(override_json_string, "override file " + override_path);
    deep_merge_json(config_json, override_item);
  }

  std::ostringstream os;
  os << config_json;
  config_json_string = os.str();

  std::string config_source_desc = opts.config_file.empty() ? "default configuration" : opts.config_file;
  if (!opts.config_overrides.empty()) {
    config_source_desc = "merged configuration from " + config_source_desc;
    for (const auto &override_path : opts.config_overrides) {
      config_source_desc = config_source_desc + ", " + override_path;
    }
  }
  validate_config_schema(config_json, config_source_desc);

  sail_config_set_string(config_json_string.c_str());
  init_platform_constants(model);
  model.model_init();

  // Validate config (and exit if requested)
  {
    bool config_is_valid = model.zconfig_is_valid(UNIT);
    const char *s = config_is_valid ? "valid" : "invalid";
    if (!config_is_valid || opts.do_validate_config) {
      if (opts.config_file.empty()) {
        fprintf(stderr, "Default configuration is %s.\n", s);
      } else {
        fprintf(stderr, "Configuration in %s is %s.\n", opts.config_file.c_str(), s);
      }
      return config_is_valid ? EXIT_SUCCESS : EXIT_FAILURE;
    }
  }

  if (opts.do_print_dts) {
    print_dts(model);
    return EXIT_SUCCESS;
  }
  if (opts.do_print_isa) {
    print_isa(model);
    return EXIT_SUCCESS;
  }

  if (opts.elfs.empty() && !use_rvfi) {
    fprintf(stderr, "No elf file provided.\n");
    return EXIT_FAILURE;
  }

  // --- Fill in the few sim_cfg fields that come from JSON config ---
  opts.sim.max_time_to_wait = get_config_uint64({"platform", "max_time_to_wait"});
  opts.sim.insns_per_tick = get_config_uint64({"platform", "instructions_per_tick"});

  // --- Construct simulator (opens logs, sockets, registers callbacks) ---
  riscv_sim::Simulator simulator(model, opts.sim);

#ifdef SAILCOV
  if (!sailcov_file.empty()) {
    sail_set_coverage_file(sailcov_file.c_str());
  }
#endif

  // --- DTB ---
  if (!opts.dtb_file.empty()) {
    fprintf(stderr, "using %s as DTB file.\n", opts.dtb_file.c_str());
    riscv_sim::write_dtb_to_rom(model, read_file(opts.dtb_file), get_config_uint64({"memory", "dtb_address"}));
  }

  // --- Resolve entry, load ELFs, init sail ---
  uint64_t entry = use_rvfi ? simulator.rvfi_entry() : riscv_sim::load_sail(model, opts.elfs[0], /*main_file=*/true);
  fprintf(stdout, "Entry point: 0x%" PRIx64 "\n", entry);

  for (auto it = opts.elfs.cbegin() + (use_rvfi ? 0 : 1); it != opts.elfs.cend(); ++it) {
    fprintf(stdout, "Loading additional ELF file %s.\n", it->c_str());
    (void)riscv_sim::load_sail(model, *it, /*main_file=*/false);
  }

  riscv_sim::init_sail(model, entry, opts.config_file.c_str());

  // Main Loop
  int exit_code = EXIT_SUCCESS;
  bool keep_running = true;
  while (keep_running) {
    auto result = simulator.run();
    switch (result.status) {
    case riscv_sim::RunStatus::HtifSuccess:
      fprintf(stdout, "SUCCESS\n");
      keep_running = false;
      break;
    case riscv_sim::RunStatus::HtifFailure:
      fprintf(stdout, "FAILURE: %" PRIi64 "\n", static_cast<int64_t>(result.htif_exit_code));
      exit_code = EXIT_FAILURE;
      keep_running = false;
      break;
    case riscv_sim::RunStatus::TrapLoop:
      fprintf(
        stdout,
        "FAILURE: possible trap loop detected with MEPC=0x%" PRIx64 " and SEPC=0x%" PRIx64 "\n",
        result.mepc,
        result.sepc
      );
      exit_code = EXIT_FAILURE;
      keep_running = false;
      break;
    case riscv_sim::RunStatus::SailException:
    case riscv_sim::RunStatus::InstructionLimit:
    case riscv_sim::RunStatus::RvfiEof:
      keep_running = false;
      break;
    case riscv_sim::RunStatus::RvfiEndTrace:
      if (use_rvfi) {
        riscv_sim::reinit_sail(model, entry, opts.config_file.c_str());
        simulator.reset_for_next_run();
      } else {
        keep_running = false;
      }
      break;
    }
  }

  // Finish
  if (!model.have_exception) {
    simulator.write_signature();
  }
  model.model_fini();
  if (opts.sim.show_times) {
    simulator.print_times();
  }

#ifdef SAILCOV
  if (sail_coverage_exit() != 0) {
    fprintf(stderr, "Could not write coverage information!\n");
    exit_code = EXIT_FAILURE;
  }
#endif

  return exit_code;
}

int main(int argc, char **argv) {
  try {
    return inner_main(argc, argv);
  } catch (const std::exception &exc) {
    std::cerr << "Error: " << exc.what() << std::endl;
  }
  return EXIT_FAILURE;
}
