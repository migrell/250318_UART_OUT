module tb_uart ();
    reg clk, rst, btn_start;
    reg [7:0] data_in;
    wire tx;
    reg rx;
    wire w_tick, w_rx_done;
    wire [7:0] rx_data;

    baud_tick_gen U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .baud_tick(w_tick)
    );

    uart_rx DUT_rx (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),  // tick
        .rx(rx),
        .rx_done(w_rx_done),
        .rx_data(rx_data)
    );

    // UART 송신기 인스턴스화
    uart_tx DUT_tx (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .start_trigger(btn_start),
        .data_in(data_in),
        .o_tx_done(tx_done),
        .o_tx(tx)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        rx  = 1;
        #10 rst = 0;
        // btn_start = 0;
        // data_in = 8'h00;

        #100;
        rst = 0;  // 리셋 해제

        #100;
        rx = 0;  // start bit

        #10416;
        rx = 1;  // data 0 - LSB 첫 비트

        #10416;
        rx = 0;  // data 1

        #10416;
        rx = 0;  // data 2

        #10416;
        rx = 1;  // data 3

        #10416;
        rx = 1;  // data 4
        #10416;
        rx = 0;  // data 5

        #10416;
        rx = 0;  // data 6
        #10416;
        rx = 1;  // data 7 - MSB 마지막 비트

        #10416;
        rx = 1;  // stop bit

        // 수신 완료 후 잠시 대기
        #1000
        $stop;

  
      
    end
endmodule
