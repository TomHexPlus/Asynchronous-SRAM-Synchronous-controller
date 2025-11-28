// Taha Izadi  Mohassel 402110543
`timescale 1ns/1ns

// asyncron sram module
module sram(
    input [8 :0] addr,
    inout [15:0] data,
    input        CE, OE, WE, UB, LB
);
    // internal memory array
    reg [15:0] memory [0:511];

    // READ
    assign #(15, 15, 4) data = (CE == 0 && WE == 1 && OE == 0) ?
                           {
                            (UB == 0 ? memory[addr][15:8] : 8'hzz), 
                            (LB == 0 ? memory[addr][7:0]  : 8'hzz)
                           } :
                           16'hzzzz;

    // WRITE
    always @(*)
    begin
        if (CE == 0 && WE == 0)
        begin
            if (LB == 0)
                memory[addr][7:0] <= #15 data[7:0];
            if (UB == 0)
                memory[addr][15:8] <= #15 data[15:8];
        end
    end
endmodule


module sram_tb;

    // sram signals
    reg  [8:0]  addr;
    reg         CE;
    reg         OE;
    reg         WE;
    reg         UB;
    reg         LB;
    
    // 2 way data pass
    wire [15:0] data;

    // loop counter
    integer count = 0;
    
    // variable for writing on data
    reg  [15:0] data_driver_reg;
    
    // writing on data based on WE signal
    assign data = (WE == 0) ? data_driver_reg : 16'hzzzz;

    // instance
    sram my_sram (
        .data(data),
        .addr(addr),
        .CE(CE),
        .OE(OE),
        .WE(WE),
        .UB(UB),
        .LB(LB)
    );

    // test block
    initial begin
        // vcd file handling
        $display("Initializing simulation...");
        $dumpfile("sram_simulation.vcd");
        $dumpvars(0, sram_tb);
        
        // initializing signals
        addr = 9'h0;
        CE = 1;
        OE = 1;
        WE = 1;
        UB = 1;
        LB = 1;
        data_driver_reg = 16'h0;
        
        #20; 

        // Phase 1: normal operation test
        $display("\nPHASE 1: Normal Operation Test (CE = 0)");

        // activating the chip
        CE = 0;
        
        // 1. writing address on lower byte for first 10
        $display("Step 1: Writing address to lower byte for addresses 0-9...");
        while(count < 10) begin
            addr = count;
            data_driver_reg = {8'h00, count[7:0]};
            $display("data is: %h", data_driver_reg);
            LB = 0;
            UB = 1;
            WE = 0;   
            #20;      
            WE = 1;   
            #5;       
            count = count + 1;
        end
        LB = 1; 
        #10;

        // 2. writing log2 of address on upper byte for second 10
        $display("Step 2: Writing $clog2(address) to upper byte for addresses 10-19...");
        while(count < 20) begin
            addr = count;
            data_driver_reg = {$clog2(count), 8'h00};
            LB = 1;
            UB = 0;
            WE = 0;   
            #20;
            WE = 1;   
            #5;
            count = count + 1;
        end
        UB = 1; 
        #10;
        
        // 3. writing randoms on third 10
        $display("Step 3: Writing random data to addresses 20-29...");
        while(count < 30) begin
            addr = count;
            data_driver_reg = $random;
            LB = 0;
            UB = 0;
            WE = 0;   
            #20;
            WE = 1;   
            #5;
            count = count + 1;
        end
        LB = 1;
        UB = 1;
        #10;
        
        // 4. reading first 30
        $display("Step 4: Reading and displaying data from addresses 0-29...");
        OE = 0;

        count = 0;
        while(count < 30) begin
            addr = count;

            // handling upper & lower
            if (count < 10) begin
                LB = 0;
                UB = 1;
            end
            if ((count > 9) && (count < 20)) begin
                LB = 1;
                UB = 0;
            end
            if (count > 19) begin
                LB = 0;
                UB = 0;
            end

            #20;
            $display("Read from addr[%0d]: data = %h", count, data);
            count = count + 1;
        end
        OE = 1;
        #20;
        
        // Phase 2: standby
        $display("\nPHASE 2: Standby Mode Test (CE = 1)");
        CE = 1;
        
        // 5. writing on standby mode
        $display("Step 5: Attempting to write to memory while in standby mode...");
        addr = 5;
        data_driver_reg = 16'hFFFF;
        WE = 0;
        LB = 0;
        UB = 0;
        #20;
        WE = 1;
        LB = 1;
        UB = 1;

        // 6. reading on standby mode
        $display("Step 6: Attempting to read from memory while in standby mode...");
        addr = 5;
        OE = 0;
        LB = 0;
        UB = 0;
        #20;
        $display("Attempted read from addr[5] while CE=1. Data bus is: %h", data);
        OE = 1;
        #10;

        // 7. checkkng the memory changes on standby mode
        // address: 5
        $display("Step 7: Verifying that memory content did NOT change...");
        CE = 0;
        OE = 0;
        addr = 5; 
        LB = 0;
        UB = 0;
        #20;
        $display("Read from addr[5] after standby test. Data is: %h (Should be xx05)", data);
        
        // address: 15
        addr = 15; 
        LB = 0;
        UB = 0;
        #20;
        $display("Read from addr[15] after standby test. Data is: %h (Should be 04xx)", data);
        OE = 1;

        // finish simulating
        #50;
        $display("\nSimulation finished.");
        $finish;
    end

endmodule