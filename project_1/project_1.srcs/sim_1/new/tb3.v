module tb_uart ();
    reg clk, rst, btn_start;
    reg [7:0] data_in;
    wire tx;
    reg rx;
    wire w_tick, w_rx_done;
    wire [7:0] rx_data;

    // 보드레이트 생성기는 필수적입니다 - 주석 해제
    baud_tick_gen U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .baud_tick(w_tick)
    );


    // UART 송신기 인스턴스화
    // uart_tx DUT_tx (
    //     .clk(clk),
    //     .rst(rst),
    //     .tick(w_tick),
    //     .start_trigger(btn_start),
    //     .data_in(data_in),
    //     .o_tx_done(tx_done),
    //     .o_tx(tx)
    // );

    uart_rx DUT_rx (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),  // tick
        .rx(rx),
        .rx_done(w_rx_done),
        .rx_data(rx_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        rx  = 1;

        #100;
        rst = 0;  // 리셋 해제

        #1000;  // 시스템이 안정화될 시간 추가

        // UART 프레임 전송 시작
        rx = 0;  // start bit

        #104160;  // 정확한 보드레이트 타이밍 - 9600bps에서 1비트 = 104,160ns
        rx = 1;  // data 0 - LSB 첫 비트

        #104160;
        rx = 0;  // data 1

        #104160;
        rx = 0;  // data 2

        #104160;
        rx = 1;  // data 3

        #104160;
        rx = 1;  // data 4

        #104160;
        rx = 0;  // data 5

        #104160;
        rx = 0;  // data 6

        #104160;
        rx = 1;  // data 7 - MSB 마지막 비트

        #104160;
        rx = 1;  // stop bit

        // 수신 완료 후 충분한 시간 대기
        #208320;  // 2비트 시간만큼 추가 대기

        $finish;  // 시뮬레이션 종료
    end
endmodule

