`timescale 1ns/1ps

module tb_mips32_4stage();

    // Two-phase clocks (clk1 and clk2)
    reg clk1, clk2;

    // Instantiate DUT (Design Under Test)
    mips32_4stage uut (.clk1(clk1), .clk2(clk2));

    // Local opcode constants (same as inside the DUT)
    localparam ADD   = 6'b000000;
    localparam SUB   = 6'b000001;
    localparam ANDI  = 6'b000010;
    localparam OR    = 6'b000011;
    localparam SLT   = 6'b000100;
    localparam MUL   = 6'b000101;
    localparam HLT   = 6'b111111;
    localparam LW    = 6'b001000;
    localparam SW    = 6'b001001;
    localparam ADDI  = 6'b001010;
    localparam SUBI  = 6'b001011;
    localparam SLTI  = 6'b001100;
    localparam BNEQZ = 6'b001101;
    localparam BEQZ  = 6'b001110;

    integer i;

    // Helper functions to form instructions
    function [31:0] RTYPE;
        input [5:0] opc; input [4:0] rs, rt, rd;
        begin
            RTYPE = {opc, rs, rt, rd, 11'b0};
        end
    endfunction

    function [31:0] ITYPE;
        input [5:0] opc; input [4:0] rs, rt; input [15:0] imm;
        begin
            ITYPE = {opc, rs, rt, imm};
        end
    endfunction

    // Clock generation
    initial begin
        clk1 = 0; 
        clk2 = 1;
    end

    always #5 clk1 = ~clk1;
    always #5 clk2 = ~clk2;

    // Testbench main logic
    initial begin
        // -------- INITIALIZE EVERYTHING --------
        uut.HALTED       = 1'b0;
        uut.TAKEN_BRANCH = 1'b0;

        uut.pc           = 32'd0;
        uut.IF_ID_IR     = 32'd0;
        uut.IF_ID_NPC    = 32'd0;
        uut.ID_EX_IR     = 32'd0;
        uut.ID_EX_NPC    = 32'd0;
        uut.ID_EX_A      = 32'd0;
        uut.ID_EX_B      = 32'd0;
        uut.ID_EX_Imm    = 32'd0;
        uut.EX_MEM_IR    = 32'd0;
        uut.EX_MEM_ALUOut= 32'd0;
        uut.EX_MEM_B     = 32'd0;
        uut.EX_MEM_Cond  = 1'b0;

        // Clear register file and memory
        for (i = 0; i < 32; i = i + 1)
            uut.Reg[i] = 32'd0;
        for (i = 0; i < 1024; i = i + 1)
            uut.Mem[i] = 32'd0;

        // -------- INITIAL PROGRAM & DATA SETUP --------
        uut.Reg[1] = 32'd5;   // R1 = 5
        uut.Reg[2] = 32'd3;   // R2 = 3

        // Program: tests arithmetic, memory, and branch
        uut.Mem[0] = RTYPE(ADD,  5'd1, 5'd2, 5'd3);          // R3 = R1 + R2 = 8
        uut.Mem[1] = RTYPE(SUB,  5'd3, 5'd2, 5'd4);          // R4 = R3 - R2 = 5
        uut.Mem[2] = ITYPE(ADDI, 5'd4, 5'd5, 16'd10);        // R5 = R4 + 10 = 15
        uut.Mem[3] = ITYPE(SW,   5'd0, 5'd5, 16'd100);       // Mem[100] = R5
        uut.Mem[4] = ITYPE(LW,   5'd0, 5'd6, 16'd100);       // R6 = Mem[100]
        uut.Mem[5] = ITYPE(BEQZ, 5'd6, 5'd0, 16'd2);         // if (R6==0) branch (not taken)
        uut.Mem[6] = ITYPE(ADDI, 5'd6, 5'd6, 16'd1);         // R6 = R6 + 1
        uut.Mem[7] = ITYPE(HLT,  5'd0, 5'd0, 16'd0);         // HALT

        // -------- WAVEFORM DUMPING --------
        $dumpfile("mips32_4stage_tb.vcd");

        // Recommended: dump entire testbench hierarchy so all uut internals are visible.
        $dumpvars(0, tb_mips32_4stage);

       

        // -------- SIMULATION MONITORING --------
        $display("Time\tPC\tR3\tR4\tR5\tR6\tMem[100]\tHALTED");
        $monitor("%0t\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%b", $time,
                  uut.pc, uut.Reg[3], uut.Reg[4], uut.Reg[5], uut.Reg[6],
                  uut.Mem[100], uut.HALTED);

        // -------- RUN SIMULATION --------
        #2000;  // run for 2000ns (2 µs)
        $display("Final Values:");
        $display("PC=%0d, R3=%0d, R4=%0d, R5=%0d, R6=%0d, Mem[100]=%0d, HALTED=%b",
                  uut.pc, uut.Reg[3], uut.Reg[4], uut.Reg[5], uut.Reg[6],
                  uut.Mem[100], uut.HALTED);
        $finish;
    end

endmodule
