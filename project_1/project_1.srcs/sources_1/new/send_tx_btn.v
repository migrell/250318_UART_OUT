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
    parameter IDLE = 0, LOAD = 1, START = 2, SEND = 3;
    parameter BUFFER_SIZE = 16;         // 16문자 버퍼 크기
    parameter ASCII_MIN = 32;           // 출력 가능한 ASCII 시작 (공백)
    parameter ASCII_MAX = 126;          // 출력 가능한 ASCII 끝 (물결 ~)

    reg [1:0] state, next_state;
    reg [7:0] send_tx_data_reg, send_tx_data_next;
    reg send_reg, send_next;
    
    // 버퍼 관련 레지스터 추가
    reg [7:0] char_buffer [0:BUFFER_SIZE-1];  // 16문자 버퍼
    reg [3:0] buffer_index_reg, buffer_index_next;  // 현재 전송할 문자 인덱스
    reg [6:0] ascii_index_reg, ascii_index_next;    // 현재 ASCII 인덱스
    reg buffer_ready_reg, buffer_ready_next;  // 버퍼 준비 상태
    reg buffer_update_reg, buffer_update_next; // 버퍼 업데이트 필요 여부
    
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

    // 버퍼 업데이트 함수 - 현재 ASCII 인덱스부터 16문자를 버퍼에 로드
    task update_buffer;
        input [6:0] start_index;
        integer j;
        begin
            for (j = 0; j < BUFFER_SIZE; j = j + 1) begin
                if (start_index + j <= ASCII_MAX) begin
                    char_buffer[j] <= start_index + j;
                end else begin
                    // ASCII 범위를 넘어가면 다시 초기값부터 시작
                    char_buffer[j] <= ASCII_MIN + ((start_index + j - ASCII_MAX - 1) % (ASCII_MAX - ASCII_MIN + 1));
                end
            end
        end
    endtask

    // 상태 레지스터 업데이트 (동기 로직)
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            send_tx_data_reg <= ASCII_MIN;  // 공백 ASCII 코드
            send_reg <= 1'b0;
            buffer_index_reg <= 4'b0;
            ascii_index_reg <= ASCII_MIN;   // 시작 ASCII 값 변경
            buffer_ready_reg <= 1'b0;
            buffer_update_reg <= 1'b0;
            
            // 초기 버퍼 설정 (출력 가능한 문자부터)
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin
                char_buffer[i] <= ASCII_MIN + i;
            end
        end else begin
            state <= next_state;
            send_tx_data_reg <= send_tx_data_next;
            send_reg <= send_next;
            buffer_index_reg <= buffer_index_next;
            ascii_index_reg <= ascii_index_next;
            buffer_ready_reg <= buffer_ready_next;
            buffer_update_reg <= buffer_update_next;
            
            // 버퍼 업데이트가 필요한 경우
            if (buffer_update_reg) begin
                update_buffer(ascii_index_reg);
            end
        end
    end

    // 다음 상태 및 출력 계산 (조합 로직)
    always @(*) begin
        // 기본값 설정
        send_tx_data_next = send_tx_data_reg;
        next_state = state;
        send_next = 1'b0;  // 기본값은 비활성화
        buffer_index_next = buffer_index_reg;
        ascii_index_next = ascii_index_reg;
        buffer_ready_next = buffer_ready_reg;
        buffer_update_next = 1'b0;  // 기본값은 업데이트 없음
        
        case (state)
            IDLE: begin
                send_next = 1'b0;
                buffer_index_next = 4'b0;  // 버퍼 인덱스 리셋
                
                if (w_start) begin  // 버튼 입력 감지
                    next_state = LOAD;
                    buffer_ready_next = 1'b1;  // 버퍼 준비 완료
                    
                    // 버튼이 눌린 후 첫 전송 시작인 경우, ASCII 인덱스 초기화
                    if (!buffer_ready_reg) begin
                        ascii_index_next = ASCII_MIN;  // 공백부터 시작
                        buffer_update_next = 1'b1;     // 버퍼 업데이트 요청
                    end
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
                    if (buffer_index_reg == BUFFER_SIZE - 1) begin
                        // 현재 버퍼의 마지막 문자 전송 완료
                        
                        if (ascii_index_reg + BUFFER_SIZE > ASCII_MAX) begin
                            // 모든 출력 가능 ASCII 문자 전송 완료 - 다시 IDLE 상태로
                            next_state = IDLE;
                            buffer_ready_next = 1'b0;  // 버퍼 준비 해제
                        end else begin
                            // 다음 버퍼로 업데이트
                            ascii_index_next = ascii_index_reg + BUFFER_SIZE;
                            buffer_update_next = 1'b1;  // 버퍼 업데이트 요청
                            buffer_index_next = 4'b0;   // 버퍼 인덱스 리셋
                            next_state = LOAD;          // 다음 문자 로드
                        end
                    end else begin
                        // 다음 문자 전송 준비
                        buffer_index_next = buffer_index_reg + 1'b1;
                        next_state = LOAD;
                    end
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule