add_subdirectory("riscv-tests")

# Check if rvv-tests exists and has content
set(RVV_TESTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/rvv-tests")

if(EXISTS "${RVV_TESTS_DIR}" AND IS_DIRECTORY "${RVV_TESTS_DIR}")
    message(STATUS "Found rvv-tests, enabling rvv tests")

    file(GLOB elfs_rv64d CONFIGURE_DEPENDS "${RVV_TESTS_DIR}/*")
    # TODO rename elfs_rv64 ?
    if(arch STREQUAL "rv64d")
        foreach(elf IN LISTS elfs_${arch})
            file(RELATIVE_PATH elf_name "${RVV_TESTS_DIR}" ${elf})

            add_test(
                NAME "${arch}_${elf_name}"
                COMMAND
                    $<TARGET_FILE:riscv_sim_${arch}>
                    # TODO we need to change to VLEN=128 and ELEN=64
                    --config "${CMAKE_SOURCE_DIR}/config/default.json"
                    ${elf}
            )
        endforeach()
    endif()
else()
    message(STATUS "rvv-tests submodule not found, skipping RVV tests")
endif()


# This is off by default so we don't require people who
# just want to build the model to have Clang or RISC-V GCC
# installed.
option(FIRST_PARTY_TESTS "Compile & run first party tests (requires Clang or RISC-V GCC).")
if (FIRST_PARTY_TESTS)
    add_subdirectory("first_party")
endif()
