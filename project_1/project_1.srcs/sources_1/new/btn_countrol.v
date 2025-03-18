`timescale 1ns / 1ps
module send_tx_btn (
    input  clk,
    input  rst,
    input  btn_start,
    output tx_done,
    output tx
);
    wire w_start;
    wire w_tx_done;

    // 내부 신호와 레지스터 선언
    parameter IDLE = 0, START = 1, SEND = 2;

    reg [1:0] state, next_state;
    reg [7:0] send_tx_data_reg, send_tx_data_next;
    reg send_reg, send_next;
    reg [3:0] send_count_reg, send_count_next;

    // 제공된 디바운스 모듈 인스턴스화
    btn_debounce U_Start_btn (
        .clk(clk),
        .reset(rst),
        .i_btn(btn_start),
        .o_btn(w_start)
    );

    // UART 송신 모듈
    uart U_UART (
        .clk(clk),
        .rst(rst),
        .btn_start(send_reg),  // 상태 머신에서 제어되는 신호 사용
        .tx_data_in(send_tx_data_reg),
        .tx_done(w_tx_done),
        .tx(tx)
    );

    // tx_done 출력 신호 연결
    assign tx_done = w_tx_done;

    // 상태 레지스터 업데이트 (동기 로직)
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            send_tx_data_reg <= 8'h30;  // "0" ASCII 코드
            send_reg <= 1'b0;
            send_count_reg <= 4'b0;
        end else begin
            state <= next_state;
            send_tx_data_reg <= send_tx_data_next;
            send_reg <= send_next;
            send_count_reg <= send_count_next;
        end
    end

    // 다음 상태 및 출력 계산 (조합 로직)
    always @(*) begin
        // 기본값 설정 - 현재 값 유지
        send_tx_data_next = send_tx_data_reg;
        next_state = state;
        send_next = send_reg;  // 이전 값 유지가 기본 동작
        send_count_next = send_count_reg;
        
        case (state)
            IDLE: begin
                // 대기 상태에서는 송신 신호 비활성화
                send_next = 1'b0;
                
                // 디바운스된 버튼 입력 감지시 다음 상태로 전환
                if (w_start) begin
                    // 다음 문자 계산
                    if (send_tx_data_reg == 8'h7A) begin  // 'z'에 도달
                        send_tx_data_next = 8'h30;        // '0'으로 리셋
                    end else begin
                        send_tx_data_next = send_tx_data_reg + 1'b1;  // 다음 ASCII 문자
                    end
                    next_state = START;
                end
            end
            
            START: begin
                // 송신 시작 신호 활성화
                send_next = 1'b1;
                
                // UART 모듈이 송신을 시작했을 때(tx_done이 0으로 변화)
                if (w_tx_done == 1'b0) begin
                    next_state = SEND;
                end
            end
            
            SEND: begin
                // 송신 중에는 송신 신호 유지
                send_next = 1'b1;
                
                // 송신이 완료되었을 때(tx_done이 1로 변화)
                if (w_tx_done == 1'b1) begin
                    // 전송 카운트 증가
                    send_count_next = send_count_reg + 1'b1;
                    
                    // 전송 횟수에 따라 다음 상태 결정
                    if (send_count_reg >= 4'd14) begin  // 15회 전송 완료
                        next_state = IDLE;
                        send_count_next = 4'b0;  // 카운터 초기화
                    end else begin
                        next_state = IDLE;  // 다음 버튼 입력 대기
                    end
                end
            end
            
            default: begin
                // 예상치 못한 상태의 경우 안전하게 IDLE로 복귀
                next_state = IDLE;
                send_next = 1'b0;
            end
        endcase
    end
endmodule