# TODO

---

A tentative plan for the project of synthesizing a RISCY-OOO core.


## Building, scripting, running [ 3 days ]

1. [x] automated riscv toolchain setup, including gnu toolchains, riscv-isa-sim, riscv-fesvr, riscv-tests
2. [x] bootrom, bootloader and linux image setup
3. hardware setup, including simulation with verilator and hardware on AWS-F1
    - make clear how verilator works with bsv designs

## Interfacing, benchmarking [ 4 days ]

1. make clear how the core interfaces with connectal (or, how it interacts with outer world)
2. automated benchmark setup, including basic ISA tests, CoreMark, SPEC if available
3. automated benchmarking to gather performance information of the base core
    - under baremetal settings and under linux

## Doc reading, first synthesis [ 1 week ]

1. read the architecture doc and start reading the core part of the code
    - front end, branch predictor
    - back end, instruction dispath, reorder buffer, load/store queue
    - caches
2. figure out how to generate verilog code in a neat way and correspond to differnt components
3. synthsize the design with an ASIC synthsizer
    - figure out how to handle memory blocks (memory compiler)
    - get basic performance numbers

## Further understanding, code tweaking [ 1 week ]

1. continue reading the code and doc
    - interrupts, exceptions handling
    - hardware support for OS (MMU)
    - implementation of execution engine (ALU, FPU)
2. review cache coherency and memory consistency
    - map the strategies used in RISCY-OOO to the actual code
    - test multicore design
3. code tweaking if interested

## Optimizing: critical path, power & resources [ ~ 1 week ]

1. given synthesize results, optimize for the critical delay
    - concurrent benchmarking to evaluate performance gain/loss
2. figure out how to apply clock gating

## First PnR, further optimizing

## Extension I: peripherials, new functional blocks

A functional RISCV processor on FPGA board w/ UART (stdin & stdout), JTAG (debugging), SD card (disk filesystem) support (network might be too ambitious).

## Extension II: experimenting arch ideas

Implement some fancy architecture ideas to the core (e.g. add a cache coherent accelerator block? better cache replacement policy? add support for other extensions (C, V, etc.)?

