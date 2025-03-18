module uart_test( //테스트
    input clk,          // 시스템 클럭 (100MHz)
    input reset_n,      // 활성 Low 리셋
    input user_btn,     // 사용자 버튼 입력
    output uart_tx,     // UART 전송 라인
    output tx_active_led,  // 전송 중 표시 LED
    output tx_done_led,    // 전송 완료 표시 LED
    output debug_led       // 디버깅용 LED
);
    // 내부 신호 선언
    wire rst = ~reset_n;  // 활성 High 리셋으로 변환
    wire tx_done;
    
    // 디버깅용 보드레이트 테스트 모듈
    baud_test U_BAUD_TEST(
        .clk(clk),
        .rst(rst),
        .test_tick(),
        .debug_led(debug_led)
    );
    
    // UART 송신 모듈
    send_tx_btn U_SEND_TX(
        .clk(clk),
        .rst(rst),
        .btn_start(user_btn),
        .tx_done(tx_done),
        .tx(uart_tx)
    );
    
    // 상태 표시 LED 제어
    reg tx_active_reg;
    reg tx_done_reg;
    reg [31:0] timeout_counter;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_active_reg <= 0;
            tx_done_reg <= 0;
            timeout_counter <= 0;
        end else begin
            // 전송 시작 감지
            if (user_btn)
                tx_active_reg <= 1;
            // 전송 완료 감지
            else if (tx_done) begin
                tx_active_reg <= 0;
                tx_done_reg <= 1;
            end
            
            // 완료 LED 리셋 (1초 후 - 100MHz 기준)
            if (tx_done_reg) begin
                if (timeout_counter >= 100000000) begin
                    tx_done_reg <= 0;
                    timeout_counter <= 0;
                end else begin
                    timeout_counter <= timeout_counter + 1;
                end
            end
        end
    end
    
    // 상태 LED 출력 할당
    assign tx_active_led = tx_active_reg;
    assign tx_done_led = tx_done_reg;
    
endmodule