/******************************************************************************
 * Project : KeyV
 * File    : tb.sv
 * Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
 * Lab     : GRM - Polytechnique Montreal
 * Date    : <2020-02-25 Tue>
 * Brief   : KeyV test bench
 ******************************************************************************/
`timescale 1ps/1ps
import tb_pkg::*;

module tb ();

    /***************************************************************************
     * SIMULATOR PARAMETERS
     ***************************************************************************/
    parameter DO_VCD = 0;

    string DESIGN, STEP;
    initial begin
        DESIGN = arg_gets("DESIGN");
        STEP   = arg_gets("STEP");
    end

    /***************************************************************************
     * CLOCK & RESET
     *
     *     - 500 MHz Clock
     *     - Active low reset
     ***************************************************************************/
    parameter PERIOD = 2000;
    parameter INTERFACE_DELAY = 870;
    logic rstn = 1'b0;
    logic clk  = 1'b0;
    always #(PERIOD/2) clk = ~clk;

    /***************************************************************************
     * DELAYS CONFIGURATION
     *
     *     - Flat array of [ExS (keyring) + 3 (mul/div)] * L Registers
     *     - Shift register (scan-in): keyring, mul_stop, mul_start, mul
     ***************************************************************************/
    logic delay_en = 1'b0;
    logic delay_cfg;
    t_keyring_delay_flat delay_flat;

    initial begin
        if (STEP == "syn") begin
            delay_flat = {F_DELAY_SYN, D_DELAY_SYN, R_DELAY_SYN, E_DELAY_SYN, M_DELAY_SYN, W_DELAY_SYN,
                          F_DELAY_SYN, D_DELAY_SYN, R_DELAY_SYN, E_DELAY_SYN, M_DELAY_SYN, W_DELAY_SYN,
                          F_DELAY_SYN, D_DELAY_SYN, R_DELAY_SYN, E_DELAY_SYN, M_DELAY_SYN, W_DELAY_SYN,
                          F_DELAY_SYN, D_DELAY_SYN, R_DELAY_SYN, E_DELAY_SYN, M_DELAY_SYN, W_DELAY_SYN,
                          F_DELAY_SYN, D_DELAY_SYN, R_DELAY_SYN, E_DELAY_SYN, M_DELAY_SYN, W_DELAY_SYN,
                          F_DELAY_SYN, D_DELAY_SYN, R_DELAY_SYN, E_DELAY_SYN, M_DELAY_SYN, W_DELAY_SYN,
                          MU_DELAY_SYN, MU_DELAY_SYN, MU_DELAY_SYN};
        end else begin
            delay_flat = {F_DELAY_SIM, D_DELAY_SIM, R_DELAY_SIM, E_DELAY_SIM, M_DELAY_SIM, W_DELAY_SIM,
                          F_DELAY_SIM, D_DELAY_SIM, R_DELAY_SIM, E_DELAY_SIM, M_DELAY_SIM, W_DELAY_SIM,
                          F_DELAY_SIM, D_DELAY_SIM, R_DELAY_SIM, E_DELAY_SIM, M_DELAY_SIM, W_DELAY_SIM,
                          F_DELAY_SIM, D_DELAY_SIM, R_DELAY_SIM, E_DELAY_SIM, M_DELAY_SIM, W_DELAY_SIM,
                          F_DELAY_SIM, D_DELAY_SIM, R_DELAY_SIM, E_DELAY_SIM, M_DELAY_SIM, W_DELAY_SIM,
                          F_DELAY_SIM, D_DELAY_SIM, R_DELAY_SIM, E_DELAY_SIM, M_DELAY_SIM, W_DELAY_SIM,
                          MU_DELAY_SIM, MU_DELAY_SIM, MU_DELAY_SIM};
        end
    end


    initial begin
        repeat (5) @(negedge clk);
        delay_en = 1'b1;
        for (int i=0; i < KEYRING_DE_FLAT-1; i++) begin
            delay_cfg <= delay_flat[i];
            repeat (1) @(negedge clk);
        end
        repeat (1) @(negedge clk);
        delay_en = 1'b0;
    end

    /***************************************************************************
     * DUT - Top level instance
     ***************************************************************************/
    top #(.MEM_INIT_FILE (MEM_INIT_FILE),
          .CORE_INTERFACE_DELAY (INTERFACE_DELAY))
    u_top(.i_rstn      (rstn),
          .i_clk       (clk),
          .i_delay_en  (delay_en),
          .i_delay_cfg (delay_cfg));

    /***************************************************************************
     * MONITORING
     *
     *     - Decode instructions
     *     - Start/Stop VCD recording
     ***************************************************************************/

    // Read IMEM from top level
    logic [31:0] imem_read, imem_addr, imem_addr_s;
    assign imem_read = tb.u_top.core_imem_read; // Breakpoint
    assign imem_addr = tb.u_top.core_imem_addr;
    always_ff @(posedge clk)
      imem_addr_s <= imem_addr;

    // Decode instructions
    t_opcode opcode;
    t_funct  funct;
    always_comb
      decode(imem_read, opcode, funct);

    // Initialize VCD parameters
    logic vcd;
    string vcd_f;
    initial begin
        vcd = 1'b0;
        $sformat(vcd_f, "%s/%s/%s.%s.vcd", DESIGN, STEP, DESIGN, STEP);
        if (DO_VCD > 0) begin
            $dumpfile(vcd_f);                // VCD file
            $dumpvars(tb.u_top.u_core);      // Record only signals in the core
            $dumpoff;                        // Do not start recording yet
        end
    end

    // Start VCD recording
    always @(imem_read)
      if (DO_VCD > 0 && imem_read == TIMER_INST && vcd == 0) begin
          $display ("> Benchmark Start (%0t)", $time);
          $dumpon;
          repeat (3) @(negedge clk);
          vcd = 1'b1;
      end

    // Stop VCD recording
    always @(imem_read)
      if (DO_VCD > 0 && imem_read == TIMER_INST && vcd == 1) begin
          $display ("> Benchmark Stop (%0t)", $time);
          $dumpoff;
          repeat (3) @(negedge clk);
          vcd = 1'b0;
      end

    /***************************************************************************
     * MAIN
     ***************************************************************************/
    initial begin
        $timeformat(-12, 1, "ps", 1);

        // Start
        $display ("\nSIMULATION BEGINS (%0t)", $time);

        // Wait until delay configuration done
        wait(delay_en == 1'b1);
        wait(delay_en == 1'b0);

        // Deassert reset
        repeat (5) @(negedge clk);
        rstn = ~rstn;

        // Wait until benchmark ends
        wait(imem_read == LAST_INST_DATA && imem_addr_s == LAST_INST_ADDR);

        // Stop
        repeat (5) @(negedge clk);
        rstn = ~rstn;

        if (DO_VCD > 0)
          $dumpflush;

        $display ("SIMULATION ENDS (%0t)\n", $time);
        $stop;
    end

endmodule
