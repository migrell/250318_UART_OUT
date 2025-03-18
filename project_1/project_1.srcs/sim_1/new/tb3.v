module tb_uart ();
    reg clk, rst, btn_start;
    reg [7:0] data_in;
//    wire tx;
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
    
    

       
    // 수정된 모듈 인스턴스화 - 올바른 포트 이름 사용
    // send_tx_btn dut (
    //     .clk(clk),                     // 클록 연결
    //     .rst(rst),                     // 리셋 연결
    //     .btn_start(tx_start_trig),     // 송신 시작 트리거 연결
    //     .tx(tx_out),                   // 송신 출력 연결
    //     .tx_done(tx_done)              // 송신 완료 신호 연결
    // );



    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst = 1;
/*
        btn_start = 0;
        data_in = "0";
        #10;
        rst = 0;
        #10;
        btn_start = 1;
        #2_000_000;
        //@(tx_done);
        //wait(tx_done == 0);   // 전송 안될 때기
        btn_start = 0;
*/
    
    //  신호 모니터링
    // always @(posedge clk) begin
    //     if (!rst) begin
    //         $display("Time=%0t, TX=%b, Done=%b", $time, tx_out, tx_done);
    //     end
    // end
    end
endmodule

 