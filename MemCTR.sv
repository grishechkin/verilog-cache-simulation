// CLS && iverilog -g2012 -o a.out MemCTR.sv && vvp a.out

module MemCTR #(
    parameter MEM_SIZE = 1048576,
    parameter CACHE_SIZE = 1024,
    parameter CACHE_LINE_SIZE = 32,
    parameter CACHE_LINE_COUNT = 32,
    parameter CACHE_WAY = 2,
    parameter CACHE_SETS_COUNT = 16,
    parameter CACHE_TAG_SIZE = 11,
    parameter CACHE_SET_SIZE = 4,
    parameter CACHE_OFFSET_SIZE = 5,
    parameter CACHE_ADDR_SIZE = 20,
    parameter ADDR1_BUS_SIZE = 15,
    parameter ADDR2_BUS_SIZE = 15,
    parameter DATA1_BUS_SIZE = 16,
    parameter DATA2_BUS_SIZE = 16,
    parameter CTR1_BUS_SIZE = 3,
    parameter CTR2_BUS_SIZE = 2
)

(
    inout wire [DATA2_BUS_SIZE - 1:0] D2,
    inout wire [CTR2_BUS_SIZE - 1:0] C2,

    input reg M_DUMP,
    input reg RESET,
    input reg CLK,
    input wire [ADDR2_BUS_SIZE - 1:0] A2
);

    reg [DATA2_BUS_SIZE - 1:0] D2_out = 'hz;
    reg [CTR2_BUS_SIZE - 1:0] C2_out = 'hz;

    assign D2 = D2_out;
    assign C2 = C2_out;

    parameter _SEED = 225526;

    integer SEED = _SEED;
    reg[7:0] ram[0:MEM_SIZE - 1];
    integer i = 0;
    integer fd;
    reg[CACHE_ADDR_SIZE:0] addr;

    logic write = 0;
    int curWrite;
    int endWrite;
    logic read = 0;
    int curRead;
    int endRead;

    int delay;

    initial begin
        $display("RAM");
        reset();
        // dump();
        
        // for (i = 0; i < MEM_SIZE; i += 1) begin
        //     $display("[%d] %d", i, ram[i]);  
        // end 
    end

    task automatic reset();
        for (i = 0; i < MEM_SIZE; i++) begin
            ram[i] = $random(SEED)>>16;  
        end
    endtask

    task automatic dump();
        fd = $fopen("RAMdump.ext", "w");
        for (i = 0; i < MEM_SIZE; i++) begin
            $fdisplay(fd, "[%d] %b", i, ram[i]);
        end
        $fclose(fd);
    endtask

    task automatic CLKwaiting(int cnt);
        for (int i = 0; i < cnt; ++i) begin
            @(negedge CLK);
        end
    endtask

    always @(negedge CLK) begin
        if (RESET == 1) reset();
        if (M_DUMP == 1) dump(); 
        
    end

    always @(negedge CLK) begin
        if (C2 === 2 || C2 === 3) begin
            addr = A2 << CACHE_OFFSET_SIZE;
            if (C2 == 2) begin
                CLKwaiting(1);
                C2_out = 0;
                CLKwaiting(99);
                C2_out = 1;
                for (i = addr; i + 1 < addr + CACHE_LINE_SIZE; i += 2) begin
                    D2_out = ram[i] + (ram[i + 1] << 8);
                    CLKwaiting(1);
                end
                D2_out = 'hz;
                C2_out = 'hz;
            end else begin
                delay = 100;
                i = addr;
                for (int j = 0; j < 16; ++j) begin
                    ram[i] = D2 % (1 << 8);
                    ram[i + 1] = D2 >> 8;
                    CLKwaiting(1);
                    C2_out = 0;
                    delay--;
                    i += 2;
                end
                C2_out = 0;
                CLKwaiting(delay);
                C2_out = 1;
                CLKwaiting(1);
                C2_out = 'hz;
            end
        end
    end 

endmodule