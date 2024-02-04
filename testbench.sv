// CLS && iverilog -g2012 -o a.out test_bench.sv && vvp a.out
`include "Cache.sv"
`include "CPU.sv"
`include "MemCTR.sv"


module Test_banch;
    parameter MEM_SIZE = 1048576;
    parameter CACHE_SIZE = 1024;
    parameter CACHE_LINE_SIZE = 32;
    parameter CACHE_LINE_COUNT = 32;
    parameter CACHE_WAY = 2;
    parameter CACHE_SETS_COUNT = 16;
    parameter CACHE_TAG_SIZE = 11;
    parameter CACHE_SET_SIZE = 4;
    parameter CACHE_OFFSET_SIZE = 5;
    parameter CACHE_ADDR_SIZE = 20;
    parameter ADDR1_BUS_SIZE = 15;
    parameter ADDR2_BUS_SIZE = 15;
    parameter DATA1_BUS_SIZE = 16;
    parameter DATA2_BUS_SIZE = 16;
    parameter CTR1_BUS_SIZE = 3;
    parameter CTR2_BUS_SIZE = 2;

    wire[ADDR1_BUS_SIZE - 1:0] A1;
    wire[ADDR2_BUS_SIZE - 1:0] A2;
    wire[DATA1_BUS_SIZE - 1:0] D1;
    wire[DATA2_BUS_SIZE - 1:0] D2;
    wire[CTR1_BUS_SIZE - 1:0] C1;
    wire[CTR2_BUS_SIZE - 1:0] C2;

    reg C_DUMP;
    reg M_DUMP;

    reg RESET = 0;

    reg CLK = 0;

    CPU cpu(
        .A1(A1),
        .C1(C1),
        .D1(D1),
        .M_DUMP(M_DUMP),
        .C_DUMP(C_DUMP),
        
        .CLK(CLK)
    );

    Cache cache(
        .C1(C1),
        .C2(C2),
        .D1(D1),
        .D2(D2),
        .A2(A2),

        .CLK(CLK),
        .RESET(RESET),
        .C_DUMP(C_DUMP),
        .A1(A1)
    );

    MemCTR mem(
        .D2(D2),
        .C2(C2),

        .M_DUMP(M_DUMP),
        .RESET(RESET),
        .CLK(CLK),
        .A2(A2)
    );

    task automatic CLKwaiting(int cnt);
        for (int i = 0; i < cnt; ++i) begin
            @(negedge CLK);
        end
    endtask

    initial begin
    end

    always #1 begin
        CLK = ~CLK;
    end

endmodule