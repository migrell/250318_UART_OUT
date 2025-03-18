`timescale 1ns / 1ps
module send_tx_btn (
    input  clk,
    input  rst,
    input  btn_start,
    output tx_done,
    output tx,
    // 디버깅 출력 추가
    output debug_active,
    output debug_done,
    output [3:0] debug_bit_position
);
    // 내부 신호 선언
    wire w_start;
    wire w_tx_done;
    wire w_tick;
    wire [3:0] bit_position;
    wire active;
    wire done;

    // 디버깅용 출력 연결
    assign debug_bit_position = bit_position;
    assign debug_active = active;
    assign debug_done = done;

    // 내부 신호와 레지스터 선언
    parameter IDLE = 0, START = 1, SEND = 2;

    reg [1:0] state, next_state;
    reg [7:0] send_tx_data_reg, send_tx_data_next;
    reg send_reg, send_next;
    reg [3:0] send_count_reg, send_count_next;

    // 시프트 레지스터 기반 버튼 디바운싱 모듈 사용
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
        .btn_start(send_reg),
        .tx_data_in(send_tx_data_reg),
        .tx_done(w_tx_done),
        .tx(tx)
    );

    // 보드레이트 생성기 모듈
    baud_tick_gen U_BAUD_Tick_Gen (
        .clk(clk),
        .rst(rst),
        .baud_tick(w_tick)
    );
    
    // 비트 카운터 모듈
    bit_counter U_BIT_COUNTER (
        .clk(clk),
        .rst(rst),
        .start(w_start),  // 디바운스된 버튼 입력 사용
        .tick(w_tick),
        .bit_position(bit_position),
        .active(active),
        .done(done)
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
        // 기본값 설정
        send_tx_data_next = send_tx_data_reg;
        next_state = state;
        send_next = 1'b0;  // 기본값을 비활성화로 변경하여 우발적인 전송 방지
        send_count_next = send_count_reg;
        
        case (state)
            IDLE: begin
                // IDLE 상태에서는 송신 신호 확실히 비활성화
                send_next = 1'b0;
                
                if (w_start) begin  // 디바운스된 버튼 입력 감지
                    // 다음 문자 준비
                    if (send_tx_data_reg == 8'h7A) begin  // 'z'
                        send_tx_data_next = 8'h30;  // '0'
                    end else begin
                        send_tx_data_next = send_tx_data_reg + 1'b1;
                    end
                    next_state = START;
                end
            end
            
            START: begin
                // 송신 시작 신호 - 한 사이클 동안만 활성화
                send_next = 1'b1;
                
                // tx_done이 LOW로 변하면 송신 시작됨을 감지
                if (w_tx_done == 1'b0) begin
                    next_state = SEND;
                end
            end
            
            SEND: begin
                // 송신 중에는 송신 신호 비활성화하여 중복 전송 방지
                send_next = 1'b0;
                
                // tx_done이 다시 HIGH가 되면 송신 완료
                if (w_tx_done == 1'b1) begin
                    send_count_next = send_count_reg + 1'b1;
                    
                    if (send_count_reg >= 4'd14) begin  // 15번째 전송 후
                        next_state = IDLE;
                        send_count_next = 4'b0;  // 카운터 리셋
                    end else begin
                        next_state = IDLE;  // 다음 버튼 입력 대기
                    end
                end
            end
            
            default: begin
                next_state = IDLE;
                send_next = 1'b0;
            end
        endcase
    end
endmodule