#pragma once

#include <cstdint>
#include <memory>
#include <string>

#include "riscv_sim_utils.h" // ConfigError, mem_sig_*, htif_tohost_address

class ModelImpl;

namespace riscv_sim {

enum class RunStatus {
  HtifSuccess,
  HtifFailure,
  TrapLoop,
  InstructionLimit,
  SailException,
  RvfiEof,
  RvfiEndTrace,
};

struct RunResult {
  RunStatus status;
  uint64_t htif_exit_code = 0; // for HtifFailure
  uint64_t mepc = 0;           // for TrapLoop
  uint64_t sepc = 0;           // for TrapLoop
};

struct SimulatorConfig {
  // Run-loop behavior
  uint64_t insn_limit = 0;
  uint64_t max_time_to_wait = 0;
  uint64_t insns_per_tick = 0;

  // Run-loop tracing
  bool trace_instr = false;
  bool trace_step = false;
  bool trace_rvfi = false;
  bool show_times = false;

  // log_callbacks flags
  bool trace_gpr = false;
  bool trace_fpr = false;
  bool trace_vreg = false;
  bool trace_csr = false;
  bool trace_mem_access = false;
  bool trace_ptw = false;
  bool trace_tlb = false;
  bool use_abi_names = false;

  // Signature
  std::string sig_file;
  unsigned sig_granularity = 4;

  // Logs ("" = stdout / no terminal log)
  std::string trace_log_path;
  std::string term_log_path;

  // RVFI (0 = disabled)
  unsigned rvfi_dii_port = 0;

  bool enable_trap_loop_detection = true;
};

class Simulator {
public:
  Simulator(ModelImpl &model, const SimulatorConfig &cfg);
  ~Simulator();

  Simulator(const Simulator &) = delete;
  Simulator &operator=(const Simulator &) = delete;

  RunResult run();

  void write_signature();
  void reset_for_next_run();

  // Only valid if rvfi_dii_port was non-zero in config.
  uint64_t rvfi_entry() const;

  // Prints initialization/execution timing to stderr.
  void print_times() const;

  uint64_t total_insns() const;

private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace riscv_sim
