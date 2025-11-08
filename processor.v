`timescale 1ns/1ps
module mips32_4stage(input clk1, clk2);

    // Program Counter and pipeline registers
    reg [31:0] pc, IF_ID_IR, IF_ID_NPC;
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;
    reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;
    reg EX_MEM_Cond;

    // Register file and memory
    reg [31:0] Reg [0:31];
    reg [31:0] Mem [0:1023];

    // Control signals
    reg [2:0] ID_EX_type, EX_MEM_type;
    reg HALTED;
    reg TAKEN_BRANCH;

    // Opcodes
    parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011,
              SLT=6'b000100, MUL=6'b000101, HLT=6'b111111,
              LW=6'b001000, SW=6'b001001, ADDI=6'b001010,
              SUBI=6'b001011, SLTI=6'b001100, BNEQZ=6'b001101, BEQZ=6'b001110;

    // Instruction types
    parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010,
              STORE=3'b011, BRANCH=3'b100, HALT=3'b101;

   
    // IF STAGE
 
    always @(posedge clk1)
    if (HALTED == 0)
    begin
        if (((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_Cond == 1)) ||
            ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_Cond == 0)))
        begin
            IF_ID_IR  <= #2 Mem[EX_MEM_ALUOut];
            IF_ID_NPC <= #2 EX_MEM_ALUOut + 1;
            pc        <= #2 EX_MEM_ALUOut + 1;
            TAKEN_BRANCH <= #2 1'b1;
        end
        else
        begin
            IF_ID_IR  <= #2 Mem[pc];
            IF_ID_NPC <= #2 pc + 1;
            pc        <= #2 pc + 1;
            TAKEN_BRANCH <= #2 1'b0;
        end
    end

    
    // ID STAGE
   
    always @(posedge clk2)
    if (HALTED == 0)
    begin
        ID_EX_IR  <= #2 IF_ID_IR;
        ID_EX_NPC <= #2 IF_ID_NPC;
        ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}};

        // Register reads
        ID_EX_A <= #2 (IF_ID_IR[25:21] == 0) ? 0 : Reg[IF_ID_IR[25:21]];
        ID_EX_B <= #2 (IF_ID_IR[20:16] == 0) ? 0 : Reg[IF_ID_IR[20:16]];

        // Determine instruction type
        case (IF_ID_IR[31:26])
            ADD, SUB, AND, OR, SLT, MUL : ID_EX_type <= #2 RR_ALU;
            ADDI, SUBI, SLTI            : ID_EX_type <= #2 RM_ALU;
            LW                          : ID_EX_type <= #2 LOAD;
            SW                          : ID_EX_type <= #2 STORE;
            BNEQZ, BEQZ                 : ID_EX_type <= #2 BRANCH;
            HLT                         : ID_EX_type <= #2 HALT;
            default                     : ID_EX_type <= #2 HALT;
        endcase
    end

  
    // EX STAGE
    always @(posedge clk1)
    if (HALTED == 0)
    begin
        EX_MEM_IR   <= #2 ID_EX_IR;
        EX_MEM_type <= #2 ID_EX_type;
        TAKEN_BRANCH <= #2 0;
        case (ID_EX_type)
            RR_ALU: begin
                case (ID_EX_IR[31:26])
                    ADD : EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;
                    SUB : EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;
                    AND : EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B;
                    OR  : EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B;
                    SLT : EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_B);
                    MUL : EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B;
                    default : EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                endcase
            end
            RM_ALU: begin
                case (ID_EX_IR[31:26])
                    ADDI : EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                    SUBI : EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm;
                    SLTI : EX_MEM_ALUOut <= #2 (ID_EX_A < ID_EX_Imm);
                    default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                endcase
            end
            LOAD, STORE: begin
                EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                EX_MEM_B      <= #2 ID_EX_B;
            end
            BRANCH: begin
                EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm;
                EX_MEM_Cond   <= #2 (ID_EX_A == 0);
            end
        endcase
    end

     //MEM/WB STAGE
   
    always @(posedge clk2)
    if (HALTED == 0)
    begin
        case (EX_MEM_type)
            RR_ALU: if (TAKEN_BRANCH == 0)
                        Reg[EX_MEM_IR[15:11]] <= #2 EX_MEM_ALUOut;

            RM_ALU: if (TAKEN_BRANCH == 0)
                        Reg[EX_MEM_IR[20:16]] <= #2 EX_MEM_ALUOut;

            LOAD: if (TAKEN_BRANCH == 0)
                        Reg[EX_MEM_IR[20:16]] <= #2 Mem[EX_MEM_ALUOut];

            STORE: if (TAKEN_BRANCH == 0)
                        Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B;

            HALT: HALTED <= #2 1'b1;
        endcase
    end

endmodule
