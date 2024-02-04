// CLS && iverilog -g2012 -o a.out CPU.sv && vvp a.out

module CPU #(
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
    output wire [ADDR1_BUS_SIZE - 1:0] A1,
    inout wire [CTR1_BUS_SIZE - 1:0] C1,
    inout wire [DATA1_BUS_SIZE - 1:0] D1,

    output reg M_DUMP,
    output reg C_DUMP,

    input reg CLK
);

    reg [ADDR1_BUS_SIZE - 1:0] A1_out = 'hz;
    reg [CTR1_BUS_SIZE - 1:0] C1_out = 'hz;
    reg [DATA1_BUS_SIZE - 1:0] D1_out = 'hz;

    assign A1 = A1_out;
    assign C1 = C1_out;
    assign D1 = D1_out;

    parameter M = 64;
    parameter N = 60;
    parameter K = 32;
    parameter A_BEGIN = 0;
    parameter B_BEGIN = M * K * A_STEP;
    parameter C_BEGIN = B_BEGIN + K * N * B_STEP;
    parameter A_STEP = 1;
    parameter B_STEP = 2;
    parameter C_STEP = 4;

    int data;
    int a_el;
    int b_el;
    int pa, pb, pc;
    int i;
    int s;
    int clk_counter = 0;

    task CLKwaiting(int cnt);
        for (i = 0; i < cnt; ++i) begin
            @(negedge CLK);
        end
    endtask

    task read8(reg [CACHE_ADDR_SIZE - 1:0] addr);
        C1_out = 1;
        A1_out = addr >> CACHE_OFFSET_SIZE;
        CLKwaiting(1);
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        A1_out = 'hz;
        C1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        data = D1;
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task read16(reg [CACHE_ADDR_SIZE - 1:0] addr);
        C1_out = 2;
        A1_out = addr >> CACHE_OFFSET_SIZE;
        CLKwaiting(1);
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        C1_out = 'hz;
        A1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        data = D1;
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task read32(reg [CACHE_ADDR_SIZE - 1:0] addr);
        C1_out = 3;
        A1_out = addr >> CACHE_OFFSET_SIZE;
        CLKwaiting(1);
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        A1_out = 'hz;
        C1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        data = D1;
        CLKwaiting(1);
        data += D1 << 16;
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task invalidate(reg [CACHE_ADDR_SIZE - 1:0] addr);
        C1_out = 4;
        A1_out = addr >> (CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        C1_out = 'hz;
        A1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task write8(reg [CACHE_ADDR_SIZE - 1:0] addr, reg [7:0] wr);
        C1_out = 5;
        A1_out = addr >> (CACHE_OFFSET_SIZE);
        D1_out = wr;
        CLKwaiting(1);
        D1_out = 'hz;
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        D1_out = 'hz;
        A1_out = 'hz;
        C1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task write16(reg [CACHE_ADDR_SIZE - 1:0] addr, reg [15:0] wr);
        C1_out = 6;
        A1_out = addr >> (CACHE_OFFSET_SIZE);
        D1_out = wr;
        CLKwaiting(1);
        D1_out = 'hz;
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        D1_out = 'hz;
        C1_out = 'hz;
        A1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task write32(reg [CACHE_ADDR_SIZE - 1:0] addr, reg [31:0] wr);
        C1_out = 7;
        A1_out = addr >> (CACHE_OFFSET_SIZE);
        D1_out = wr % (1 << 16);
        CLKwaiting(1);
        D1_out = wr >> 16;
        A1_out = addr % (1 << CACHE_OFFSET_SIZE);
        CLKwaiting(1);
        D1_out = 'hz;
        A1_out = 'hz;
        C1_out = 'hz;
        while (!(C1 === 7)) CLKwaiting(1);
        CLKwaiting(1);
        C1_out = 0;
    endtask

    task dump_cache();
        C_DUMP = 1;
        CLKwaiting(1);
        C_DUMP = 0;
        CLKwaiting(1);
    endtask
    task dump_mem();
        M_DUMP = 1;
        CLKwaiting(1);
        M_DUMP = 0;
        CLKwaiting(1);
    endtask

    initial begin
        $display("CPU");

        C_DUMP = 0;
        M_DUMP = 0;
        C1_out = 0;

        pa = A_BEGIN;
        CLKwaiting(1);
        pc = C_BEGIN;
        CLKwaiting(1);
        CLKwaiting(1);
        for (int y = 0; y < M; y++) begin
            CLKwaiting(1);
            for (int x = 0; x < N; x++) begin
                pb = B_BEGIN;
                CLKwaiting(1);
                s = 0;
                CLKwaiting(1);

                CLKwaiting(1);
                for (int k = 0; k < K; k++) begin
                    CLKwaiting(1);
                    read8(pa + k * A_STEP);
                    a_el = data;
                    CLKwaiting(1);
                    read16(pb + x * B_STEP);
                    b_el = data;

                    // $display("addr a = %0d, addr b = %0d", pa + k * A_STEP, pb + x * B_STEP);
                    // $display("a = %0d, b = %0d", a_el, b_el);

                    CLKwaiting(6); //math
                    s += a_el * b_el;
                    // s += pa[k] * pb[x];
                    CLKwaiting(1);
                    pb += N * B_STEP;
                    CLKwaiting(1); //iteration
                end
                // pc[x] = s;
                // $display("c = %0d, addr = %0b", s, pc + x * C_STEP);
                write32(pc + x * C_STEP, s);
                CLKwaiting(2);
            end
            pa += K * A_STEP;
            pc += N * C_STEP;
            CLKwaiting(3); //iteration
        end
        CLKwaiting(1); //ret

        // for (int i = 0; i < M; ++i) begin
        //     for (int j = 0; j < N; ++j) begin
        //         read32(C_BEGIN + (i * N + j) * C_STEP);
        //         $display("c = %0d, addr = %0b", data, C_BEGIN + (i * N + j) * C_STEP);
        //     end
        //     $finish();
        // end

        $display("Clocks = %0d", clk_counter);
        dump_cache();
        $display("FINISH time = %0t", $time());
        $finish();
    end

    always @(negedge CLK) begin
        clk_counter++;
    end

endmodule