// CLS && iverilog -g2012 -o a.out Cache.sv && vvp a.out

module Cache #(
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
    inout wire [0:CTR1_BUS_SIZE - 1] C1,
    inout wire [0:CTR2_BUS_SIZE - 1] C2,
    inout wire [0:DATA1_BUS_SIZE - 1] D1,
    inout wire [0:DATA2_BUS_SIZE - 1] D2,
    output wire [0:ADDR2_BUS_SIZE - 1] A2,

    input reg CLK,
    input reg RESET,
    input reg C_DUMP,
    input wire [ADDR1_BUS_SIZE - 1:0] A1
);

    
    reg [0:CTR1_BUS_SIZE - 1] C1_out = 'hz;
    reg [0:CTR2_BUS_SIZE - 1] C2_out = 'hz;
    reg [0:DATA1_BUS_SIZE - 1] D1_out = 'hz;
    reg [0:DATA2_BUS_SIZE - 1] D2_out = 'hz;
    reg [0:ADDR2_BUS_SIZE - 1] A2_out = 'hz;

    assign C1 = C1_out;
    assign C2 = C2_out;
    assign D1 = D1_out;
    assign D2 = D2_out;
    assign A2 = A2_out;

    parameter BIT_CACHE_LINE_SIZE = CACHE_LINE_SIZE * 8;
    parameter LINE_IN_CACHE_SIZE = 2 + CACHE_TAG_SIZE + BIT_CACHE_LINE_SIZE;

    reg [CACHE_ADDR_SIZE - 1:0] addr;
    reg [CACHE_TAG_SIZE - 1:0] tag;
    reg [CACHE_SET_SIZE - 1:0] set;
    reg [CACHE_OFFSET_SIZE - 1:0] offset;
    reg [BIT_CACHE_LINE_SIZE - 1:0] data;
    reg [LINE_IN_CACHE_SIZE - 1:0] cache[0:CACHE_LINE_COUNT - 1];
    reg [CACHE_LINE_COUNT - 1:0] times;
    reg [CTR1_BUS_SIZE - 1:0] request;

    int line_number;
    int shift;
    integer fd;
    int i;
    int cache_hit = 0;
    int cache_miss = 0;

    task dump();
        $display("hit = %0d, miss = %0d", cache_hit, cache_miss);
        fd = $fopen("CacheDump.ext", "w");
        for (i = 0; i < CACHE_LINE_COUNT; i++) begin
            $fdisplay(fd, "[%d] %b", i, cache[i]);
        end
        $fclose(fd);
    endtask

    task reset();
        C2_out = 0;
        for (i = 0; i < CACHE_LINE_COUNT; ++i) begin
            cache[i] = 0;
            times[i] = 0;
        end
    endtask

    initial begin
        $display("Cache"); 
        reset();
    end

    always @(negedge CLK) begin
        if (C_DUMP) dump();
        if (RESET) reset();
    end

    task automatic upd_time();
        for (int i = set * CACHE_WAY; i < (set + 1) * CACHE_WAY; ++i) begin
            if (get_tag(i) != tag) times[i] = 0;
            else times[i] = 1; 
        end
    endtask

    function reg[LINE_IN_CACHE_SIZE - 1:0] get_line(int pos);
        return cache[pos];
    endfunction

    function automatic reg[CACHE_TAG_SIZE - 1:0] get_tag(int pos);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(pos);
        return (line >> BIT_CACHE_LINE_SIZE) % (1 << CACHE_TAG_SIZE); 
    endfunction

    function reg[CACHE_TAG_SIZE - 1:0] get_set(int pos);
        return pos / CACHE_WAY;
    endfunction

    function automatic reg[BIT_CACHE_LINE_SIZE - 1:0] get_data(int pos); 
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(pos);
        return line % (1 << BIT_CACHE_LINE_SIZE); 
    endfunction

    function automatic reg get_dirty(int pos);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(pos);
        return (line >> (BIT_CACHE_LINE_SIZE + CACHE_TAG_SIZE)) % 2; 
    endfunction

    function automatic reg get_valid(int pos);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(pos);
        return line >> (BIT_CACHE_LINE_SIZE + CACHE_TAG_SIZE + 1); 
    endfunction

    task set_line(int pos, reg[LINE_IN_CACHE_SIZE - 1:0] line);
        cache[pos] = line;
    endtask

    task automatic set_valid(int pos, reg valid);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(pos);
        line[LINE_IN_CACHE_SIZE - 1] = valid;
        set_line(pos, line);
    endtask

    task automatic set_dirty(int pos, reg dirty);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(pos);
        line[LINE_IN_CACHE_SIZE - 2] = dirty;
        set_line(pos, line);
    endtask

    function int get_line_number();
        for (i = CACHE_WAY * set; i < CACHE_WAY * (set + 1); i++) begin
            if (get_valid(i) != 0 && get_tag(i) == tag) return i;
        end
        return -1;
    endfunction

    function automatic int get_replacement();
        for (i = CACHE_WAY * set; i < CACHE_WAY * (set + 1); i++) begin
            if (get_valid(i) == 0) return i;
        end

        for (i = CACHE_WAY * set; i < CACHE_WAY * (set + 1); i++) begin
            if (times[i] == 0) return i;
        end
    endfunction

    function reg[LINE_IN_CACHE_SIZE - 1:0] build_new_line();
        return data + (tag << BIT_CACHE_LINE_SIZE) + (1 << (BIT_CACHE_LINE_SIZE + CACHE_TAG_SIZE + 1));
    endfunction

    function reg[7:0] get8();
        return (data >> offset * 8) % (1 << 8);
    endfunction
    function reg[15:0] get16();
        return (data >> offset * 8) % (1 << 16);
    endfunction
    function reg[31:0] get32();
        return (data >> offset * 8) % (1 << 32);
    endfunction

    task CLKwaiting(int cnt);
        for (i = 0; i < cnt; ++i) begin
            @(negedge CLK);
        end
    endtask

    task invalidate(int pos);
        if (pos != -1 && get_valid(pos) != 0) begin
            set_valid(pos, 0);
            if (get_dirty(pos) == 1) begin
                write_mem(get_tag(pos), get_set(pos), get_data(pos));
            end
        end
    endtask

    task automatic write_mem(int tag, int set, reg[BIT_CACHE_LINE_SIZE - 1:0] wr);
        C2_out = 3;
        A2_out = (tag << CACHE_SET_SIZE) + set;
        for (int i = 0; i < BIT_CACHE_LINE_SIZE; i += DATA2_BUS_SIZE) begin
            D2_out = (wr >> i) % (1 << 8) + (((wr >> (i + 8)) % (1 << 8)) << 8);
            CLKwaiting(1);
            A2_out = 'hz;
            C2_out = 'hz;
        end
        D2_out = 'hz;

        while (!(C2 === 1)) CLKwaiting(1);
        CLKwaiting(1);
        C2_out = 0;
    endtask

    task automatic read_mem(int tag, int set);
        C2_out = 2;
        A2_out = (tag << CACHE_SET_SIZE) + set;
        CLKwaiting(1);
        A2_out = 'hz;
        C2_out = 'hz;
        while (!(C2 === 1)) CLKwaiting(1);
        data = 0;
        shift = 0;
        for (int x = 0; x < 16; ++x) begin
            data += (D2 << shift);
            shift += DATA2_BUS_SIZE;
            CLKwaiting(1);
        end
        C1_out = 0;
    endtask

    task read8_ans(reg[7:0] wr);
        C1_out = 7;
        D1_out = wr;
        CLKwaiting(1);
        C1_out = 'hz;
        D1_out = 'hz;
    endtask

    task read16_ans(reg[15:0] wr);
        C1_out = 7;
        D1_out = wr;
        CLKwaiting(1);
        C1_out = 'hz;
        D1_out = 'hz;
    endtask

    task read32_ans(reg[31:0] wr);
        C1_out = 7;
        D1_out = wr % (1 << DATA1_BUS_SIZE);
        CLKwaiting(1);
        D1_out = wr >> DATA1_BUS_SIZE;
        CLKwaiting(1);
        C1_out = 'hz;
        D1_out = 'hz;
    endtask

    task automatic write8_ans(reg [DATA1_BUS_SIZE - 1:0] data1);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(line_number);
        for (int i = 0; i < 8; ++i) begin
            line[i + offset * 8] = data1[i];
        end
        set_line(line_number, line);

        C1_out = 7;
        CLKwaiting(1);
        C1_out = 'hz;
    endtask

    task automatic write16_ans(reg [DATA1_BUS_SIZE - 1:0] data1);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(line_number);
        for (int i = 0; i < 16; ++i) begin
            line[i + offset * 8] = data1[i];
        end
        set_line(line_number, line);

        C1_out = 7;
        CLKwaiting(1);
        C1_out = 'hz;
    endtask

    task automatic write32_ans(reg [DATA1_BUS_SIZE - 1:0] data1, reg [DATA1_BUS_SIZE - 1:0] data2);
        reg[LINE_IN_CACHE_SIZE - 1:0] line = get_line(line_number);
        for (int i = 0; i < 32; ++i) begin
            if (i < 16) line[i + offset * 8] = data1[i];
            else line[i + offset * 8] = data2[i - 16];
        end
        set_line(line_number, line);
        C1_out = 7;
        CLKwaiting(1);
        C1_out = 'hz;
    endtask

    always @(negedge CLK) begin
        if (C1 === 1 || C1 === 2 || C1 === 3 || C1 === 4 ||
        C1 === 5 || C1 === 6 || C1 === 7) begin
            reg [DATA1_BUS_SIZE - 1:0] data1;
            reg [DATA1_BUS_SIZE - 1:0] data2;
            addr = A1;
            data1 = D1;
            tag = addr >> CACHE_SET_SIZE;
            set = addr % (1 << CACHE_SET_SIZE);
            request = C1;
            CLKwaiting(1);
            if (request == 7) data2 = D1;
            offset = A1;

            CLKwaiting(1);
            C1_out = 0;
            line_number = get_line_number();


            if (request == 4) begin
                CLKwaiting(4);
                invalidate(line_number);
            end else if (line_number == -1) begin
                CLKwaiting(2);
                cache_miss++;
                read_mem(tag, set);
                line_number = get_replacement();
                invalidate(line_number);
                set_line(line_number, build_new_line());
            end else begin
                CLKwaiting(4);
                cache_hit++;
            end

            data = get_data(line_number);

            if (request == 1) begin
                read8_ans(get8());
            end
            if (request == 2) begin
                read16_ans(get16());
            end
            if (request == 3) begin
                read32_ans(get32());
            end
            if (request == 5) begin
                write8_ans(data1);
                set_dirty(line_number, 1);
            end
            if (request == 6) begin
                write16_ans(data1);
                set_dirty(line_number, 1);
            end
            if (request == 7) begin
                write32_ans(data1, data2);
                set_dirty(line_number, 1);
            end
            upd_time();
        end 
    end

endmodule