# KeyV : In-order /KeyRing/ self-timed processors based on the RISC-V ISA

This project explores the design trade-offs of the *KeyRing* asynchronous microarchitecture. It is used to design **KeyV**, an in-order KeyRing processor based on the RV32IM user-level [RISC-V ISA specification](https://riscv.org/technical/specifications/), implemented using the TSMC65GP (65nm) ASIC technology. KeyV is compared with **SynV**, a 6-stages pipeline synchronous clock-gated processor implementing the same ISA and targeting a similar design flow with the same ASIC technology.

## Setup

  - This project relies on CAD tools and technologies provided by [CMC](https://www.cmc.ca/). It was developed under **Centos 7**, and it is expected to work (*without major modifications*) in any CMC environment, including a virtual machine instance accessibe via the [NDN Cloud](https://vcad.cmc.ca).

  - Setting-up the environment must be performed prior to doing any work on this project. To do so, execute the [setup.csh](setup.csh) script from the root of the project in a `tcsh` shell:

    ``` bash
    source setup.csh
    ```

## Software

  - Programs are compiled for the processors using the dedicated [Makefile](software/Makefile) in the *software* directory. The help is self-explanatory:

    ``` bash
    make help
    ```

  - The RISC-V toolchain used in this project is deployed in the [toolchain](software/toolchain/) directory, using the [build\_toolchain\_.csh](software/toolchain/build_toolchain.csh) script.

  - The project includes a (simplified) custom [firmware](software/firmware/), which handles basic memory operations.
    - [crt.S](software/firmware/crt.S): Assembly program which handles basic starting & ending functions (reset, call main, traps…)
    - [stdlib.c](software/firmware/stdlib.c): C program which handles basic memory operations (malloc) & printing functions (write in a scratchpad memory)
    - [link.ld](software/firmware/link.ld): Linker script which reflects the core memory organization in the software.

  - Different benchmarks are available in the [benchmark](software/benchmark/) folder to validate the behaviour of the processor, and evaluate its performances:
    - [basic](software/benchmark/basic/): Simple assembly program adapted to test each instructions in the ISA.
    - [fibo](software/benchmark/fibo/): Simple C program running few iterations of the fibonacci algorithm. It is used to test the toolchain with the custom firmware functions.
    - [dhrystone](software/benchmark/dhrystone/): The Dhrystone benchmark adapted to use the custom firmware. It is used to evaluate the performances of the processor.
    - [coremark](software/benchmark/coremark/): The Coremark benchmark adapted to use the custom firmware. It is used to evaluate the performances of the processor.

## Simulation

  - The simulation is performed with *Modelsim*, and is handled by the [Makefile](simulation/Makefile) in the *simulation* directory. The  help is self-explanatory:

    ``` bash
    make help
    ```

  - Simulation flows rely on the following Tcl scripts:
    - [sim.tcl](scripts/sim.tcl)
    - [kVsim.tcl](scripts/kVsim.tcl)
    - [kVutils.tcl](scripts/kVutils.tcl)

  - Post-synthesis simulations rely on SDF files that must first be produced by DC or PrimeTime.

  - SAIF files are generated to evaluate the dynamic power consumption of the design in DC.

## Synthesis

  - The synthesis flow is handled by the [Makeifle](synthesis/Makefile) in the *synthesis* directory. The help is self-explanatory:

    ``` bash
    make help
    ```

  - Synthesis flow relies on the following scripts:
    - [syn.tcl](scripts/syn.tcl)
    - [KeyRing.tcl](scripts/KeyRing.tcl)
    - [kVsyn.tcl](scripts/kVsyn.tcl)
    - [kVutils.tcl](scripts/kVutils.tcl)

  - Timing constraints for the SynV / KeyV processors are respectively written in:
    - [sdc\_synv.tcl](scripts/sdc_synv.tcl)
    - [sdc\_keyv.tcl](scripts/sdc_keyv.tcl)

  - Clock gating for SynV is handled separately:
    -[cg.tcl](scripts/cg.tcl)

  - SDF files are produced by PrimeTime:
    - [sdf.tcl](scripts/sdf.tcl)

  - Power analysis is performed by DC based on post synthesis acitvity recorded in SAIF
    - [pwr.tcl](scripts/pwr.tcl)

## Results

  - Results from the simulation and synthesis flows are parsed and analyzed using the following scripts:
    - [data\_parse.tcl](scripts/data_parse.tcl)
    - [data\_plots.py](scripts/data_plots.py)
