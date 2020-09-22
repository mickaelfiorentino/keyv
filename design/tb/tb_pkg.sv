/******************************************************************************
 * Project : KeyV
 * File    : tb_pkg.sv
 * Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
 * Lab     : GRM - Polytechnique Montreal
 * Date    : <2020-02-25 Tue>
 * Brief   : KeyV test bench Package
 ******************************************************************************/
package tb_pkg;

    /* Using VHDL packages in systemVerilog (from modelsim documentation):
     * - Requires the -mixedsvvh argument when compiling the VHDL package with vcom
     * - Because VHDL is case-insensitive, constants are converted to lower-case
     */
    import rv32_pkg::*;

    /***************************************************************************
     * PARAMETERS
     ***************************************************************************/

    // IMEM content
    parameter MEM_INIT_FILE = "/export/tmp/fiorentino/Projects/keyv/software/mem.hex";

    // KEYRING
    parameter KEYRING_E = 6;
    parameter KEYRING_S = 6;
    parameter KEYRING_L = 30;
    parameter KEYRING_DE_FLAT = (KEYRING_E*KEYRING_S+3)*KEYRING_L;

    typedef logic [KEYRING_L-1:0] t_keyring_delay;
    typedef logic [KEYRING_DE_FLAT:0] t_keyring_delay_flat;

    function t_keyring_delay to_thermometer (input integer val);
        t_keyring_delay delay;
        if (val > 0) begin
            for (int i=KEYRING_L-val; i<KEYRING_L; i++) begin
                delay[i] = 1'b1;
            end
        end
        for (int i=0; i<KEYRING_L-val; i++) begin
            delay[i] = 1'b0;
        end
        return delay;
    endfunction

    parameter F_DELAY_SIM  = to_thermometer(1);
    parameter D_DELAY_SIM  = to_thermometer(1);
    parameter R_DELAY_SIM  = to_thermometer(1);
    parameter E_DELAY_SIM  = to_thermometer(1);
    parameter M_DELAY_SIM  = to_thermometer(1);
    parameter W_DELAY_SIM  = to_thermometer(1);
    parameter MU_DELAY_SIM = to_thermometer(1);

    parameter F_DELAY_SYN  = to_thermometer(25);
    parameter D_DELAY_SYN  = to_thermometer(15);
    parameter R_DELAY_SYN  = to_thermometer(15);
    parameter E_DELAY_SYN  = to_thermometer(15);
    parameter M_DELAY_SYN  = to_thermometer(15);
    parameter W_DELAY_SYN  = to_thermometer(20);
    parameter MU_DELAY_SYN = to_thermometer(1);

    // Last instruction of any program is Loop Forever
    parameter LAST_INST_DATA = 32'h0000006f;
    parameter LAST_INST_ADDR = 32'h00000070;

    // Timer Instruction: rdcycle a0
    parameter TIMER_INST = 32'hC0002573;

    // PASS (P = 50 in ascii), FAIL (F = 46 in ascii)
    parameter PASS = 16'h0050;
    parameter FAIL = 16'h0046;

    /****************************************************************************
     * ARG_GETS
     *
     *     Read string argument from simulator
     ****************************************************************************/
    function string arg_gets (input string arg);
        string val;
        if (!($value$plusargs({arg,"=%s"}, val))) begin
            $display ("TB ERROR: Missing %s argument", arg);
            $finish;
        end else begin
            $display ("PARAMETER %s = %s", arg, val);
        end
        return val;
    endfunction

    /***************************************************************************
     * DECODE
     *
     *     RV32IM instruction decoding
     ***************************************************************************/

    // Opcodes
    typedef enum { IMM, REG, BRANCH, LOAD, STORE, SYS, JAL, JALR, LUI, AUIPC, FENCE, OP_ERR } t_opcode;
    typedef enum { ADD, SUB, SLT, SLTU, XOR, OR, AND, SLL, SRL, SRA, ADDI, SLTI,
                   SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, BEQ, BNE, BLT, BLTU, BGE,
                   BGEU, LB, LBU, LH, LHU, LW, SB, SH, SW, MUL, MULH, MULHSU, MULHU,
                   DIV, DIVU, REM, REMU, EBREAK, CSRRW, CSRRWI, CSRRS, CSRRSI, CSRRC,
                   CSRRCI, FENCER, FENCEI, OTHER, ERR } t_funct;

    task decode (input logic [31:0] imem, output t_opcode opcode, output t_funct funct);

        case (imem[opcode_h:opcode_l])

            op_imm: begin
                opcode = IMM;
                case (imem[funct3_h:funct3_l])
                    fct_addi  : funct = ADDI;
                    fct_slti  : funct = SLTI;
                    fct_sltiu : funct = SLTIU;
                    fct_xori  : funct = XORI;
                    fct_ori   : funct = ORI;
                    fct_andi  : funct = ANDI;
                    fct_slli  : funct = SLLI;
                    fct_sri   : funct = imem[inst_arith_b] == 1'b1 ? SRAI : SRLI;
                    default   : funct = ERR;
                endcase
            end

            op_op: begin
                opcode = REG;
                if (imem[inst_mul_b] == 1'b0) begin
                    case (imem[funct3_h:funct3_l])
                        fct_slt  : funct = SLT;
                        fct_sltu : funct = SLTU;
                        fct_xor  : funct = XOR;
                        fct_or   : funct = OR;
                        fct_and  : funct = AND;
                        fct_sll  : funct = SLL;
                        fct_add  : funct = imem[inst_arith_b] == 1'b1 ? SUB : ADD;
                        fct_sr   : funct = imem[inst_arith_b] == 1'b1 ? SRA : SRL;
                        default  : funct = ERR;
                    endcase
                end else begin
                    case (imem[funct3_h:funct3_l])
                        fct_mul    : funct = MUL;
                        fct_mulh   : funct = MULH;
                        fct_mulhsu : funct = MULHSU;
                        fct_mulhu  : funct = MULHU;
                        fct_div    : funct = DIV;
                        fct_divu   : funct = DIVU;
                        fct_rem    : funct = REM;
                        fct_remu   : funct = REMU;
                        default    : funct = ERR;
                    endcase
                end
            end

            op_branch: begin
                opcode = BRANCH;
                case (imem[funct3_h:funct3_l])
                    fct_beq  : funct = BEQ;
                    fct_bne  : funct = BNE;
                    fct_blt  : funct = BLT;
                    fct_bltu : funct = BLTU;
                    fct_bge  : funct = BGE;
                    fct_bgeu : funct = BGEU;
                    default  : funct = ERR;
                endcase
            end

            op_jal: begin
                opcode = JAL;
                funct  = OTHER;
            end

            op_jalr: begin
                opcode = JALR;
                funct  = OTHER;
            end

            op_lui: begin
                opcode = LUI;
                funct  = OTHER;
            end

            op_auipc: begin
                opcode = AUIPC;
                funct = OTHER;
            end

            op_load: begin
                opcode = LOAD;
                case (imem[funct3_h:funct3_l])
                    fct_lb  : funct = LB;
                    fct_lbu : funct = LBU;
                    fct_lh  : funct = LH;
                    fct_lhu : funct = LHU;
                    fct_lw  : funct = LW;
                    default : funct = ERR;
                endcase
            end

            op_store: begin
                opcode = STORE;
                case (imem[funct3_h:funct3_l])
                    fct_sb  : funct = SB;
                    fct_sh  : funct = SH;
                    fct_sw  : funct = SW;
                    default : funct = ERR;
                endcase
            end

            op_system: begin
                opcode = SYS;
                case (imem[funct3_h:funct3_l])
                    fct_ecall_ebreak : funct = EBREAK;
                    fct_csrrw        : funct = CSRRW;
                    fct_csrrwi       : funct = CSRRWI;
                    fct_csrrs        : funct = CSRRS;
                    fct_csrrsi       : funct = CSRRSI;
                    fct_csrrc        : funct = CSRRC;
                    fct_csrrci       : funct = CSRRCI;
                    default          : funct = ERR;
                endcase
            end

            op_fence: begin
                opcode = FENCE;
                case (imem[funct3_h:funct3_l])
                    fct_fence  : funct = FENCER;
                    fct_fencei : funct = FENCEI;
                    default    : funct = ERR;
                endcase
            end

            default: begin
                opcode = OP_ERR;
                funct  = ERR;
            end

        endcase
    endtask

endpackage
