`timescale 1ns / 1ps

module tb_uart_tx ();
    // 테스트에 필요한 입력 신호 선언 (레지스터)
    reg clk;              // 클록 신호
    reg rst;              // 리셋 신호 (1: 활성화, 0: 비활성화)
    reg tx_start_trig;    // 송신 시작 트리거 신호
    
    // 테스트를 통해 관찰할 출력 신호 선언 (와이어)
    wire tx_out;          // UART 송신 출력 신호
    wire tx_done;         // 송신 완료 신호
    
    // 수정된 모듈 인스턴스화 - 올바른 포트 이름 사용
    send_tx_btn dut (
        .clk(clk),                     // 클록 연결
        .rst(rst),                     // 리셋 연결
        .btn_start(tx_start_trig),     // 송신 시작 트리거 연결
        .tx(tx_out),                   // 송신 출력 연결
        .tx_done(tx_done)              // 송신 완료 신호 연결
    );
    
    // 클록 생성 (10ns 주기, 5ns 마다 토글)
    always #5 clk = ~clk;
    
    // 테스트 시나리오 정의
    initial begin
        // 초기값 설정
        clk = 1'b0;              // 클록 초기값 0
        rst = 1'b1;              // 리셋 활성화
        tx_start_trig = 1'b0;    // 송신 시작 트리거 초기값 0
        
        #20 rst = 1'b0;          // 20ns 후 리셋 비활성화
        #20 tx_start_trig = 1'b1; // 40ns 후 송신 시작 트리거 활성화
        #100 tx_start_trig = 1'b0; // 140ns 후 송신 시작 트리거 비활성화
        
        // 첫 번째 전송 완료 대기
        #10000;
        
        // 두 번째 버튼 입력
        #20 tx_start_trig = 1'b1;
        #100 tx_start_trig = 1'b0;
        
        // 충분한 시뮬레이션 시간 확보
        #10000;
    end
    
    // 신호 모니터링
    always @(posedge clk) begin
        if (!rst) begin
            $display("Time=%0t, TX=%b, Done=%b", $time, tx_out, tx_done);
        end
    end
endmodule