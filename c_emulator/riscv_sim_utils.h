#pragma once
#include "riscv_model_impl.h"
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace riscv_sim {

class ConfigError : public std::runtime_error {
public:
  using std::runtime_error::runtime_error;
};

struct RunConfig {
  // From CLI
  uint64_t insn_limit = 0;
  bool trace_instr = false;
  bool trace_step = false;
  bool show_times = false;
  bool trace_rvfi = false;
  std::string sig_file;
  // TODO: Move default value over here:
  unsigned sig_granularity = 4;
  // From JSON Config File
  uint64_t max_time_to_wait = 0;
  uint64_t insns_per_tick = 1;
};

uint64_t load_sail(ModelImpl &model, const std::string &filename, bool main_file);
void init_sail(ModelImpl &model, uint64_t elf_entry, const char *config_file);
void reinit_sail(ModelImpl &model, uint64_t elf_entry, const char *config_file);
void write_dtb_to_rom(ModelImpl &model, const std::vector<uint8_t> &dtb, uint64_t addr);

// We should also declare the variables that load_sail fills
extern std::optional<uint64_t> htif_tohost_address;
extern uint64_t mem_sig_start;
extern uint64_t mem_sig_end;

} // namespace riscv_sim
