`timescale 1ns / 1ps

module uart_tx (
    input clk,
    input rst,
    input tick,
    input start_trigger,
    input [7:0] data_in,
    output o_tx_done,
    output o_tx
);
    //FSM 상태 정의
    parameter IDLE = 0, SEND = 1, START = 2, DATA = 3, STOP = 4;

    
    reg [3:0] state, next;
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [3:0] tick_count_reg, tick_count_next;
    
    assign o_tx_done = tx_done_reg;
    assign o_tx = tx_reg;
    
    // 순차 로직 - 상태 및 레지스터 업데이트
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_reg <= 1'b1;  // UART의 기본 idle 상태는 high
            tx_done_reg <= 0;
            bit_count_reg <= 0;
            tick_count_reg <= 0;
        end else begin
            state <= next;
            tx_reg <= tx_next;
            tx_done_reg <= tx_done_next;
            bit_count_reg <= bit_count_next;
            tick_count_reg <= tick_count_next;
        end
    end
    
    // 조합 로직 - 다음 상태 및 출력 계산
    always @(*) begin
        // 기본값 설정 - 현재 값 유지 (래치 방지를 위한 중요한 부분)
        next = state;
        tx_next = tx_reg;
        tx_done_next = tx_done_reg;
        bit_count_next = bit_count_reg;
        tick_count_next = tick_count_reg;

        case (state)
            IDLE: begin    
                tx_next = 1'b1;  // idle 상태에서는 tx 라인을 high로 유지
                tx_done_next = 1'b0;  // 송신 완료 신호 초기화
                bit_count_next = 3'b000;  // 비트 카운터 초기화
                tick_count_next = 4'h0;  // 틱 카운터 초기화
                
                if(start_trigger) begin
                    next = SEND;  // 시작 트리거를 받으면 SEND 상태로 전환
                end
            end
            
            SEND: begin
                if(tick == 1'b1) begin
                    next = START;  // tick 신호를 받으면 START 상태로 전환
                end
            end
            
            START: begin
                tx_next = 1'b0;  // 시작 비트는 LOW (0)
                
                if(tick == 1'b1) begin 
                    if(tick_count_reg == 15) begin
                        next = DATA;  // 16 틱 후 DATA 상태로 전환
                        bit_count_next = 3'b000;  // 비트 카운터 초기화 (3비트 폭)
                        tick_count_next = 4'h0;  // 틱 카운터 초기화 (4비트 폭)
                    end else begin
                        tick_count_next = tick_count_reg + 1;  // 틱 카운터 증가
                    end
                end
            end

            DATA: begin
                tx_next = data_in[bit_count_reg];  // 현재 비트 위치의 데이터 비트 전송
                 
                if (tick) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 4'h0;  // 틱 카운터 초기화
                        
                        if (bit_count_reg == 7) begin
                            next = STOP;  // 8비트 모두 전송 후 STOP 상태로 전환
                        end else begin
                            bit_count_next = bit_count_reg + 1;  // 다음 비트로 이동
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;  // 틱 카운터 증가
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;  // 정지 비트는 HIGH (1)
                
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        next = IDLE;  // 16 틱 후 IDLE 상태로 복귀
                        tx_done_next = 1'b1;  // 송신 완료 신호 설정
                        tick_count_next = 4'h0;  // 틱 카운터 초기화
                    end else begin
                        tick_count_next = tick_count_reg + 1;  // 틱 카운터 증가
                    end
                end
            end
            
            default: begin
                next = IDLE;  // 잘못된 상태일 경우 IDLE로 복귀
                tx_next = 1'b1;  // 기본 출력은 HIGH
                tx_done_next = 1'b0;  // 송신 완료 신호 초기화
                bit_count_next = 3'b000;  // 비트 카운터 초기화
                tick_count_next = 4'h0;  // 틱 카운터 초기화
            end
        endcase
    end
endmodule

module uart(
    input clk,
    input rst,
    input btn_start,
    input [7:0] tx_data_in,
    output tx_done,
    output tx
);
    // 내부 신호 선언
    wire w_tick;

    // UART 송신기 인스턴스화
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .start_trigger(btn_start),
        .data_in(tx_data_in),
        .o_tx_done(tx_done),
        .o_tx(tx)
    );

    // 보드레이트 생성기 인스턴스화
    baud_tick_gen U_BAUD_Tick_Gen (
        .clk(clk),
        .rst(rst),
        .baud_tick(w_tick)
    );
endmodule

module baud_tick_gen (
    input clk,
    input rst,
    output baud_tick
);
    //100Mhz 1tick generator
    parameter BAUD_RATE = 9600, BAUD_RATE_19200 = 19200;
    localparam BAUD_COUNT = (100_000_000 / BAUD_RATE)/16; //주파수 계산
    reg [$clog2(BAUD_COUNT) - 1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;
    
    //output
    assign baud_tick = tick_reg;
    
    // 순차 로직
    always @(posedge clk or posedge rst) begin
        if(rst == 1) begin
            count_reg <= 0;
            tick_reg <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg <= tick_next;
        end
    end
    
    // 조합 로직 - 래치 방지를 위한 초기화 수정
    always @(*) begin
        // 기본값 설정 (래치 방지)
        count_next = count_reg;
        tick_next = 1'b0;  // 기본값은 0으로 설정 (중요한 변경점)
        
        if (count_reg >= BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next = 1'b1;  // 카운트 완료 시 틱 생성
        end else begin
            count_next = count_reg + 1;
            // tick_next = 1'b0;  // 이미 기본값으로 설정되어 있음
        end
    end
endmodule

module send_tx_btn(
     input clk,
     input rst,
     input btn_start,
     output tx_done,
     output tx
);
    wire w_start, w_tx_done;
    reg [7:0] send_tx_data_reg, send_tx_data_next;
   
    // 버튼 디바운스 모듈.
    btn_debounce U_Start_btn(
        .clk(clk),
        .reset(rst),
        .i_btn(btn_start),
        .o_btn(w_start)
    );
    
    // UART 모듈 인스턴스화
    uart U_UART(
        .clk(clk),
        .rst(rst),
        .btn_start(w_start),
        .tx_data_in(send_tx_data_reg),
        .tx_done(w_tx_done),
        .tx(tx)
    );
    
    // tx_done 출력 신호 연결
    assign tx_done = w_tx_done;
    
    // 레지스터 업데이트 로직
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            send_tx_data_reg <= 8'h30; // "0" ASCII 코드
        end else begin
            send_tx_data_reg <= send_tx_data_next;
        end
    end
    
    // 다음 데이터 계산 로직 - 래치 방지를 위해 수정
    always @(*) begin
        // 기본값 설정 (래치 방지)
        send_tx_data_next = send_tx_data_reg;
        
        if(w_start == 1'b1) begin // 디바운스된 버튼 입력
            if(send_tx_data_reg == 8'h7A) begin // "z" ASCII 코드
                send_tx_data_next = 8'h30; // "0"로
            end else begin
                send_tx_data_next = send_tx_data_reg + 1; // ASCII 코드값 + 1
            end
        end
        // else는 필요 없음 - 기본값이 이미 설정됨
    end    
endmodule

module btn_debounce (
    input clk,
    input reset,
    input i_btn,
    output reg o_btn
);
    // 1MHz 클럭으로 변경된 디바운스 타이밍
    parameter DEBOUNCE_TIME = 5000; // 5ms (1MHz 기준)
    reg [12:0] counter; // 5000을 저장하기 위한 비트 수
    reg btn_state;
    
    // 클럭 분주기 - 100MHz를 1MHz로 변환
    reg [6:0] clk_div_counter;
    reg clk_1mhz;
    
    // 100MHz → 1MHz 클럭 분주
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div_counter <= 0;
            clk_1mhz <= 0;
        end else begin
            if (clk_div_counter >= 49) begin // 100MHz를 1MHz로 분주 (50분주)
                clk_div_counter <= 0;
                clk_1mhz <= ~clk_1mhz; // 클럭 토글
            end else begin
                clk_div_counter <= clk_div_counter + 1;
            end
        end
    end
    
    // 버튼 디바운스 로직 (1MHz 클럭 기준)
    always @(posedge clk_1mhz or posedge reset) begin
        if (reset) begin
            counter <= 0;
            btn_state <= 0;
            o_btn <= 0;
        end else begin
            // 버튼 상태와 입력이 다르면 카운터 증가
            if (btn_state != i_btn) begin
                counter <= counter + 1;
                // 카운터가 설정 시간에 도달하면 상태 변경
                if (counter >= DEBOUNCE_TIME) begin
                    btn_state <= i_btn;
                    counter <= 0;
                end
            end else begin
                counter <= 0; // 입력이 안정적이면 카운터 리셋
            end
            
            // 상승 에지 감지 (0->1 전이)
            if ((btn_state == 1) && (o_btn == 0)) begin
                o_btn <= 1;
            end else begin
                o_btn <= 0; // 버튼을 한 번만 감지하기 위해 리셋
            end
        end
    end
endmodule