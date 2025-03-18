`timescale 1ns / 1ps
module send_tx_btn (
    input  clk,
    input  rst,
    input  btn_start,
    output tx_done,
    output tx,
    // 디버깅 출력
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
    parameter IDLE = 0, LOAD = 1, START = 2, SEND = 3, COMPLETE = 4;
    parameter BUFFER_SIZE = 16;  // 버퍼 크기 (한 번에 전송할 문자 수)
    parameter TOTAL_CHARS = 75;  // 총 출력해야 할 문자 수

    reg [2:0] state, next_state;
    reg [7:0] send_tx_data_reg, send_tx_data_next;
    reg send_reg, send_next;
    
    // 버퍼 관련 레지스터
    reg [7:0] char_buffer [0:BUFFER_SIZE-1];  // 전송할 문자 버퍼
    reg [3:0] buffer_index_reg, buffer_index_next;  // 현재 버퍼 내 인덱스
    reg [6:0] char_index_reg, char_index_next;      // 전체 문자열 내 인덱스
    reg transmission_active_reg, transmission_active_next;  // 전송 활성화 상태
    
    // 고정된 문자열 정의 (ASCII 코드 배열로)
    reg [7:0] target_string [0:TOTAL_CHARS-1];
    
    integer i;  // 루프 변수

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
        .start(w_start),
        .tick(w_tick),
        .bit_position(bit_position),
        .active(active),
        .done(done)
    );

    // tx_done 출력 신호 연결
    assign tx_done = w_tx_done;

    // 버퍼 업데이트 함수 - 문자열의 특정 위치부터 16문자를 버퍼에 로드
    task update_buffer;
        input [6:0] start_index;
        integer j;
        begin
            for (j = 0; j < BUFFER_SIZE; j = j + 1) begin
                if (start_index + j < TOTAL_CHARS) begin
                    char_buffer[j] <= target_string[start_index + j];
                end else begin
                    char_buffer[j] <= 8'h20;  // 범위를 벗어나면 공백 문자로 채움
                end
            end
        end
    endtask

    // 상태 레지스터 업데이트 (동기 로직)
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            send_tx_data_reg <= 8'h00;
            send_reg <= 1'b0;
            buffer_index_reg <= 4'b0;
            char_index_reg <= 7'b0;
            transmission_active_reg <= 1'b0;
            
            // 원하는 문자열 초기화 (ASCII 코드로)
            // "1234567890:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz"
            for (i = 0; i < 10; i = i + 1) begin  // 숫자 0-9
                target_string[i] <= 8'd48 + i;
            end
            for (i = 10; i < 17; i = i + 1) begin  // : ; < = > ? @
                target_string[i] <= 8'd58 + (i - 10);
            end
            for (i = 17; i < 43; i = i + 1) begin  // A-Z
                target_string[i] <= 8'd65 + (i - 17);
            end
            for (i = 43; i < 49; i = i + 1) begin  // [ \ ] ^ _ `
                target_string[i] <= 8'd91 + (i - 43);
            end
            for (i = 49; i < 75; i = i + 1) begin  // a-z
                target_string[i] <= 8'd97 + (i - 49);
            end
            
            // 초기 버퍼 설정
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
                if (i < TOTAL_CHARS) begin
                    char_buffer[i] <= target_string[i];
                end else begin
                    char_buffer[i] <= 8'h20;  // 공백 문자
                end
            end
        end else begin
            state <= next_state;
            send_tx_data_reg <= send_tx_data_next;
            send_reg <= send_next;
            buffer_index_reg <= buffer_index_next;
            char_index_reg <= char_index_next;
            transmission_active_reg <= transmission_active_next;
            
            // 버퍼 업데이트가 필요한 경우
            if (char_index_next != char_index_reg) begin
                update_buffer(char_index_next);
            end
        end
    end

    // 다음 상태 및 출력 계산 (조합 로직)
    always @(*) begin
        // 기본값 설정
        send_tx_data_next = send_tx_data_reg;
        next_state = state;
        send_next = 1'b0;
        buffer_index_next = buffer_index_reg;
        char_index_next = char_index_reg;
        transmission_active_next = transmission_active_reg;
        
        case (state)
            IDLE: begin
                send_next = 1'b0;
                buffer_index_next = 4'b0;
                
                // 버튼이 눌리고 현재 전송 중이 아닐 때만 전송 시작
                if (w_start && !transmission_active_reg) begin
                    transmission_active_next = 1'b1;
                    char_index_next = 7'b0;  // 문자열의 처음부터 시작
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                // 버퍼에서 다음 문자 로드
                send_tx_data_next = char_buffer[buffer_index_reg];
                next_state = START;
            end
            
            START: begin
                // 송신 시작 신호 활성화
                send_next = 1'b1;
                
                // 송신이 시작되면 SEND 상태로 전환
                if (w_tx_done == 1'b0) begin
                    next_state = SEND;
                end
            end
            
            SEND: begin
                // 송신 중에는 송신 신호 비활성화
                send_next = 1'b0;
                
                // 송신이 완료되면 다음 문자 처리
                if (w_tx_done == 1'b1) begin
                    if (char_index_reg + buffer_index_reg >= TOTAL_CHARS - 1) begin
                        // 모든 문자 전송 완료
                        next_state = COMPLETE;
                    end else if (buffer_index_reg == BUFFER_SIZE - 1) begin
                        // 현재 버퍼의 마지막 문자 전송 완료, 다음 버퍼로 넘어감
                        char_index_next = char_index_reg + BUFFER_SIZE;
                        buffer_index_next = 4'b0;
                        next_state = LOAD;
                    end else begin
                        // 다음 문자 전송 준비
                        buffer_index_next = buffer_index_reg + 1'b1;
                        next_state = LOAD;
                    end
                end
            end
            
            COMPLETE: begin
                // 전송 완료 상태 - 리셋될 때까지 여기 머무름
                transmission_active_next = 1'b0;
                
                // 버튼이 떼어져도 IDLE 상태로 돌아가지 않음 (리셋 필요)
                if (!w_start) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
                transmission_active_next = 1'b0;
            end
        endcase
    end
endmodule