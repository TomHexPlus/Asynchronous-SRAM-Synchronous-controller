// Taha Izadi Mohassel 402110543
`timescale 1ns/1ns

module sram_controller #(
    parameter freq = 50
) (
    input             clk,
    input             rst,
    input             memRead,
    input             memWrite,
    input      [8 :0] addrTarget,
    input      [31:0] dataIn,
    output reg        ready,
    output reg [31:0] dataOut,

    // for communicating with sram
    output reg [8 :0] addr,
    inout      [15:0] data,
    output            CE, OE, UB, LB,
    output reg        WE
);

    // clock period
    localparam CLK_PERIOD = 1000 / freq;

    // sram critical path delay
    localparam SRAM_DELAY = 15;

    // ceiling division (A + B - 1) / B
    localparam CYCLES = (SRAM_DELAY + CLK_PERIOD - 1) / CLK_PERIOD;

    // FSM
    localparam S_IDLE                = 4'b0000;
    localparam S_WRITE_LOWER         = 4'b0001;
    localparam S_WRITE_UPPER         = 4'b0010;
    localparam S_READ_LOWER_SETUP    = 4'b0100;
    localparam S_READ_LOWER_CAPTURE  = 4'b0101;
    localparam S_READ_UPPER_SETUP    = 4'b0110;
    localparam S_READ_UPPER_CAPTURE  = 4'b0111;

    reg [3:0] current_state, next_state;
    reg [$clog2(CYCLES):0] wait_counter;

    // for driving data bus
    reg  [15:0] data_reg;
    assign data = (!WE) ? data_reg : 16'hZZZZ;

    // always low signals of sram
    assign CE = 1'b0;
    assign OE = 1'b0;
    assign UB = 1'b0;
    assign LB = 1'b0;
    

    // state transition
    always @(posedge clk or posedge rst)
    begin
        if (rst)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end

    // wait counter
    always @(posedge clk or posedge rst)
    begin
        // if it's reset
        if (rst)
            wait_counter <= 0;
        // setting wait counter 
        else if (next_state != current_state)
        begin
            if (next_state == S_WRITE_LOWER || next_state == S_WRITE_UPPER ||
                next_state == S_READ_LOWER_SETUP || next_state == S_READ_UPPER_SETUP)
                wait_counter <= CYCLES - 1;
        // decreasing wait counter during operation
        end else if (wait_counter > 0)
            wait_counter <= wait_counter - 1;
    end

    // combinational next state
    always @(*)
    begin
        // defult of next state
        next_state = current_state;

        // choosing next state based on controller signals
        case (current_state)
            S_IDLE: begin
                if (memWrite)
                    next_state = S_WRITE_LOWER;
                else if(memRead)
                    next_state = S_READ_LOWER_SETUP;
            end
            S_WRITE_LOWER: begin
                if (wait_counter == 0)
                    next_state = S_WRITE_UPPER;
            end
            S_WRITE_UPPER: begin
                if (wait_counter == 0)
                    next_state = S_IDLE;
            end
            S_READ_LOWER_SETUP: begin
                if (wait_counter == 0)
                    next_state = S_READ_LOWER_CAPTURE;
            end
            S_READ_LOWER_CAPTURE: begin
                next_state = S_READ_UPPER_SETUP;
            end
            S_READ_UPPER_SETUP: begin
                if (wait_counter == 0)
                    next_state = S_READ_UPPER_CAPTURE;
            end
            S_READ_UPPER_CAPTURE: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // output
    always @(posedge clk or posedge rst)
    begin
        // if it's reset
        if (rst) begin
            ready <= 1'b1;
            dataOut <= 32'b0;
            addr <= 9'b0;
            data_reg <= 16'b0;
        end else begin
            // default values
            ready <= (next_state == S_IDLE && current_state == S_IDLE);

            if (current_state == S_READ_LOWER_CAPTURE)
                dataOut[15:0] <= data;
            else if (current_state == S_READ_UPPER_CAPTURE)
                dataOut[31:16] <= data;
            

            // set outputs based on next state
            case (next_state)
                S_WRITE_LOWER: begin
                    WE <= 1'b0;
                    addr <= addrTarget;
                    data_reg <= dataIn[15:0];
                end
                S_WRITE_UPPER: begin
                    WE <= 1'b0; 
                    addr <= addrTarget + 1;
                    data_reg <= dataIn[31:16];
                end
                S_READ_LOWER_SETUP: begin
                    WE <= 1'b1;
                    addr <= addrTarget;
                end
                S_READ_UPPER_SETUP: begin
                    WE <= 1'b1;
                    addr <= addrTarget + 1;
                end
            endcase
        end
    end
endmodule

module sram_controller_testbench;
    // global reset for switching
    reg         global_rst;

    // binary selection test
    reg         test_select;

    // signals for 10MHz test
    reg         clk_10, rst_10, memRead_10, memWrite_10;

    reg  [8:0]  addrTarget_10;
    reg  [31:0] dataIn_10;
    wire [31:0] dataOut_10;
    wire [8:0]  sram_addr_10;
    wire [15:0] sram_data_10;

    wire        sram_CE_10,
                sram_OE_10, 
                sram_WE_10, 
                sram_UB_10, 
                sram_LB_10,
                ready_10;

    reg  [31:0] written_data_10 [0:9];
    reg         flag_10; // for failing tests

    // signals for 200MHz test
    reg         clk_200, rst_200, memRead_200, memWrite_200;
    
    reg  [8:0]  addrTarget_200;
    reg  [31:0] dataIn_200;
    wire [31:0] dataOut_200;
    wire [8:0]  sram_addr_200;
    wire [15:0] sram_data_200;

    wire        sram_CE_200,
                sram_OE_200,
                sram_WE_200,
                sram_UB_200,
                sram_LB_200,
                ready_200;

    reg  [31:0] written_data_200 [0:9];
    reg         flag_200;

    
    // 10MHz instances
    sram sram_10MHz (
        .addr(sram_addr_10),
        .data(sram_data_10),
        .CE(sram_CE_10),
        .OE(sram_OE_10),
        .WE(sram_WE_10),
        .UB(sram_UB_10),
        .LB(sram_LB_10)
    );

    sram_controller #(.freq(10)) sram_controller_10MHz (
        .clk(clk_10),
        .rst(rst_10),
        .memRead(memRead_10),
        .memWrite(memWrite_10),
        .addrTarget(addrTarget_10),
        .dataIn(dataIn_10), 
        .ready(ready_10),
        .dataOut(dataOut_10),
        .addr(sram_addr_10),
        .data(sram_data_10),
        .CE(sram_CE_10),
        .OE(sram_OE_10),
        .WE(sram_WE_10),
        .UB(sram_UB_10),
        .LB(sram_LB_10)
    );

    

    // 200MHz instances
    sram sram_200MHz (
        .addr(sram_addr_200),
        .data(sram_data_200),
        .CE(sram_CE_200),
        .OE(sram_OE_200),
        .WE(sram_WE_200),
        .UB(sram_UB_200),
        .LB(sram_LB_200)
    );
    
    sram_controller #(.freq(200)) sram_controller_200MHz (
        .clk(clk_200),
        .rst(rst_200),
        .memRead(memRead_200),
        .memWrite(memWrite_200),
        .addrTarget(addrTarget_200),
        .dataIn(dataIn_200),
        .ready(ready_200),
        .dataOut(dataOut_200),
        .addr(sram_addr_200),
        .data(sram_data_200),
        .CE(sram_CE_200),
        .OE(sram_OE_200),
        .WE(sram_WE_200),
        .UB(sram_UB_200),
        .LB(sram_LB_200)
    );

    
    // clocks
    always #50 clk_10 = ~clk_10; // 100ns
    always #2.5 clk_200 = ~clk_200; // 5ns

    // integer variables for loops
    integer i, j;

    // main block for testing...
    initial begin
        // vcd file handling
        $dumpfile("controller_simulation.vcd");
        $dumpvars(0, sram_controller_testbench);
        
        // initializing
        clk_10  = 0;
        clk_200 = 0;
        global_rst = 1;
        test_select = 0;

        // ****************** 10MHz Test ******************
        $display("\n\n=== STARTING 10MHz TEST ===");
        rst_10 = 1;
        flag_10 = 0;
        memRead_10 = 0;
        memWrite_10 = 0;
        $display("At %0t ns ====> Starting Simulation", $time);
        
        #100;
        global_rst = 0;
        rst_10 = 0;
        $display("At %0t ns ====> Reset and Waiting for ready\n", $time);
        wait(ready_10);

        // Write Operations
        $display("=== Starting 10 32-bit WRITE operations ===");
        for (i = 0; i < 10; i = i + 1)
        begin
            @(negedge clk_10);
            memWrite_10 = 1;
            dataIn_10 = $random;
            written_data_10[i] = dataIn_10;
            addrTarget_10 = 2 * i;
            $display("At %0t ns ====> Writing %h to address %0d", $time, dataIn_10, addrTarget_10);

            @(posedge clk_10);
            memWrite_10 = 0;

            wait(!ready_10);
            $display("At %0t ns ====> ready is %d", $time, ready_10);
            wait(ready_10);
            $display("At %0t ns ====> Write %0d finished. ready is %d\n", $time, i+1, ready_10);
        end

        // Read Operations & Verification
        $display("\n === READ and Verification ===");
        for (j = 0; j < 10; j = j + 1)
        begin
            @(negedge clk_10);
            memRead_10 = 1;
            addrTarget_10 = 2 * j;

            @(posedge clk_10);
            memRead_10 = 0;

            wait(!ready_10);
            $display("At %0t ns ====> ready is %d", $time, ready_10);

            wait(ready_10);
            $display("At %0t ns ====> Reading from address %0d. Ready is %d",$time, addrTarget_10, ready_10);

            // verification
            $display("Verification [%0d]...", j+1);
            $display("Data Written: %h ====== Data Read: %h", written_data_10[j], dataOut_10);

            if (dataOut_10 === written_data_10[j])
                $display("Test [%0d] Passed...\n", j+1);
            else
            begin
                $display("Test [%0d] Failed...\n", j+1);
                flag_10 = 1'b1;
            end
        end

        if (!flag_10)
            $display("\n=== ALL 10MHz TESTS PASSED ===");
        else
            $display("\n=== 10MHz TESTS FAILED ===");

        #100;

        // ****************** 200MHz Test ******************
        $display("\n\n=== STARTING 200MHz TEST ===");
        
        // Reset everything for 200MHz test
        global_rst = 1;
        test_select = 1;
        rst_200 = 1;
        flag_200 = 0;
        memRead_200 = 0;
        memWrite_200 = 0;
        $display("At %0t ns ====> Starting Simulation...", $time);
        
        #10;
        global_rst = 0;
        rst_200 = 0;
        $display("At %0t ns ====> Reset and Waiting for ready\n", $time);
        wait(ready_200);

        // Write Operations
        $display("=== Starting 10 32-bit WRITE operations ===");
        for (i = 0; i < 10; i = i + 1)
        begin
            @(negedge clk_200);
            memWrite_200 = 1;
            dataIn_200 = $random;
            written_data_200[i] = dataIn_200;
            addrTarget_200 = 2 * i;
            $display("At %0t ns ====> Writing %h to address %0d",$time, dataIn_200, addrTarget_200);

            @(posedge clk_200);
            memWrite_200 = 0;

            wait(!ready_200);
            $display("At %0t ns ====> Ready is %d", $time, ready_200);

            wait(ready_200);
            $display("At %0t ns ====> Write %0d finished. ready is %d", $time, i+1, ready_200);
        end

        // Read Operations & Verification
        $display("\n=== READ and Verification ===");
        for (j = 0; j < 10; j = j + 1)
        begin
            @(negedge clk_200);
            memRead_200 = 1;
            addrTarget_200 = 2 * j;

            @(posedge clk_200);
            memRead_200 = 0;

            wait(!ready_200);
            $display("At %0t ns ====> Ready is %d", $time, ready_200);

            wait(ready_200);
            $display("At %0t ns ====> Reading from address %0d. Ready is %d", $time, addrTarget_200, ready_200);

            $display("=== Verification [%0d]...", j+1);
            $display("Data Written: %h ====== Data Read: %h", written_data_200[j], dataOut_200);

            if (dataOut_200 === written_data_200[j])
                $display("Test [%0d] Passed...\n", j+1);
            else begin
                $display("Test [%0d] Failed...\n", j+1);
                flag_200 = 1'b1;
            end
        end

        if (!flag_200)
            $display("\n=== ALL 200MHz TESTS PASSED ===");
        else
            $display("\n=== 200MHz TESTS FAILED ===");
        
        $display("\n\n=== SIMULATION FINISHED ===");
        $finish;
    end
endmodule