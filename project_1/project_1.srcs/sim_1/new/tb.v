module tb_uart_tx ();

   // 테스트에 필요한 입력 신호 선언 (레지스터)
   reg clk;         // 클록 신호
   reg rst;         // 리셋 신호 (1: 활성화, 0: 비활성화)
   reg tx_start_trig;  // 송신 시작 트리거 신호
   reg [7:0] tx_din;   // 송신할 8비트 데이터
   
   // 테스트를 통해 관찰할 출력 신호 선언 (와이어)
   wire tx_dout;    // UART 송신 출력 신호
   wire tx_done;    // 송신 완료 신호

  
   // UART 컨트롤러 모듈 인스턴스화 (현재는 주석 처리됨)
   uart dut (
       .clk(clk),                    // 클록 연결
       .rst(rst),                    // 리셋 연결
       .tx_start_trigger(tx_start_trig),  // 송신 시작 트리거 연결
       .tx_data(tx_din),            // 송신 데이터 연결
       .tx_o(tx_dout),              // 송신 출력 연결
       .tx_done(tx_done)            // 송신 완료 신호 연결
   );
   


    // uart dut(
    //     .clk(clk),
    //     .rst(rst),
    //     .btn_start(tx_start_trig),
    //     .tx(tx_out)
    // );

 
   always #5 clk = ~clk;

   // 테스트 시나리오 정의
   initial begin
       // 초기값 설정
       clk = 1'b0;              // 클록 초기값 0
       rst = 1'b1;              // 리셋 활성화
    //    tx_din = 8'b01010101;    // 송신할 데이터: 교대 비트 패턴(0x55)
       tx_start_trig = 1'b0;    // 송신 시작 트리거 초기값 0
       
       #20 rst = 1'b0;
       
       #20 tx_start_trig = 1'b1;
     
       #20 tx_start_trig = 1'b0;
   end
endmodule