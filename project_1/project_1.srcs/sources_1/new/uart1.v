module TOP_UART (
    input clk,
    // rst 입력 제거
    input rx,
    output tx,
    output [7:0] fnd_font,
    output [3:0] fnd_comm,
    output tx_done,
    output debug_active,
    output debug_done,
    output [3:0] debug_bit_position
);
    // 내부 신호 선언
    wire w_rx_done;         // 수신 완료 신호
    wire [7:0] w_rx_data;   // 수신된 데이터
    
    // 내부 리셋 생성 (Power-On Reset)
    reg [3:0] por_counter = 0;
    wire internal_rst;
    
    always @(posedge clk) begin
        if (por_counter < 4'hF)
            por_counter <= por_counter + 1;
    end
    
    assign internal_rst = (por_counter < 4'hF);  // 처음 15클럭 동안 리셋 활성화
    
    // 타이머를 이용한 자동 송신 로직
    reg [26:0] timer_count;     // 약 1초 타이머 (100MHz 클럭 기준)
    reg tx_trigger;             // 송신 트리거 신호
    reg [7:0] tx_data;          // 송신 데이터
    reg [2:0] data_sequence;    // 송신 데이터 시퀀스 카운터
    
    // 디버그 신호 연결
    assign debug_active = tx_trigger;
    assign debug_done = tx_done;
    assign debug_bit_position = {1'b0, data_sequence};
    
    // 타이머 및 자동 송신 로직
    always @(posedge clk) begin
        if (internal_rst) begin
            timer_count <= 0;
            tx_trigger <= 0;
            data_sequence <= 0;
            tx_data <= 8'h30;  // 기본값 '0'
        end else begin
            // 기본 상태
            tx_trigger <= 0;
            
            // 타이머 증가
            timer_count <= timer_count + 1;
            
            // 약 1초마다 송신 트리거
            if (timer_count == 27'd100_000_000) begin
                timer_count <= 0;
                tx_trigger <= 1;
                
                // 시퀀스에 따라 다른 문자 전송 (0-7까지 순환)
                case (data_sequence)
                    3'd0: tx_data <= 8'h41;  // 'A'
                    3'd1: tx_data <= 8'h42;  // 'B'
                    3'd2: tx_data <= 8'h43;  // 'C'
                    3'd3: tx_data <= 8'h44;  // 'D'
                    3'd4: tx_data <= 8'h45;  // 'E'
                    3'd5: tx_data <= 8'h46;  // 'F'
                    3'd6: tx_data <= 8'h47;  // 'G'
                    3'd7: tx_data <= 8'h48;  // 'H'
                endcase
                
                // 다음 시퀀스로 이동
                if (data_sequence == 3'd7)
                    data_sequence <= 0;
                else
                    data_sequence <= data_sequence + 1;
            end
        end
    end
    
    // UART 모듈 인스턴스화 - 인스턴스 이름 유지
    uart U_UART (
        .clk(clk),
        .rst(internal_rst),  // 내부 생성 리셋 사용
        .btn_start(tx_trigger),
        .tx_data_in(tx_data),
        .tx_done(tx_done),
        .tx(tx),
        .rx(rx),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

    // 7세그먼트 제어 모듈 - 인스턴스 이름 유지
    simple_fnd_controller U_FND_CTR (
        .clk(clk),
        .reset(internal_rst),  // 내부 생성 리셋 사용
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .fnd_font(fnd_font),
        .fnd_comm(fnd_comm)
    );
endmodule

// UART 모듈
module uart(
    input clk,
    input rst,
    //tx
    input btn_start,
    input [7:0] tx_data_in,
    output tx_done,
    output tx, 
    //rx
    input rx,
    output rx_done,
    output [7:0] rx_data
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

    // UART 수신기 인스턴스화
    uart_rx U_UART_RX(
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .rx(rx),
        .rx_done(rx_done),
        .rx_data(rx_data)
    );
endmodule





// UART 송신기 모듈
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
    
    reg [2:0] state, next;
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [3:0] tick_count_reg, tick_count_next;
    
    assign o_tx_done = tx_done_reg;
    assign o_tx = tx_reg;
    
    always @(posedge clk, posedge rst) begin
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
    
    always @(*) begin
        // 기본값 설정
        next = state;
        tx_next = tx_reg;
        tx_done_next = tx_done_reg;
        bit_count_next = bit_count_reg;
        tick_count_next = tick_count_reg;

        case (state)
            IDLE: begin    
                tx_next = 1'b1; // output setting
                tx_done_next = 1'b0; 
                tick_count_next = 4'h0;
                if(start_trigger) begin
                    next = SEND;
                end
            end
            
            SEND: begin
                if(tick == 1'b1) begin
                    next = START;
                end
            end
            
            START: begin
                tx_next = 1'b0; // 출력을 0으로 유지 (시작 비트)
                tx_done_next = 1'b0; // 시작 상태에서는 tx_done을 비활성화
                if(tick == 1'b1) begin 
                    if(tick_count_reg == 15) begin
                        next = DATA;
                        bit_count_next = 3'b000;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_in[bit_count_reg]; // uart LSB first
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 1'b0;
                        if (bit_count_reg == 3'b111) begin
                            next = STOP;
                        end else begin
                            next = DATA;
                            bit_count_next = bit_count_reg + 1; // bit count 증가
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1; // 정지 비트는 1
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        next = IDLE;
                        tx_done_next = 1'b1; // STOP 비트 전송이 완료된 후에만 tx_done 활성화
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            
            default: begin
                next = IDLE;
                tx_next = 1'b1;
            end
        endcase
    end
endmodule

// UART 수신기 모듈
module uart_rx (
    input clk,
    input rst,
    input tick,
    input rx,
    output rx_done,
    output [7:0] rx_data
);
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg[1:0] state, next;
    reg rx_done_reg, rx_done_next;
    reg[2:0] bit_count_reg, bit_count_next;
    reg[4:0] tick_count_reg, tick_count_next;
    reg[7:0] rx_data_reg, rx_data_next;

    // 출력 할당
    assign rx_done = rx_done_reg;
    assign rx_data = rx_data_reg;

    // 상태 레지스터 업데이트
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= 0;
            rx_done_reg <= 0;
            rx_data_reg <= 0;
            bit_count_reg <= 0;
            tick_count_reg <= 0;
        end else begin
            state <= next;
            rx_done_reg <= rx_done_next;
            rx_data_reg <= rx_data_next;
            bit_count_reg <= bit_count_next;
            tick_count_reg <= tick_count_next;
        end
    end

    // 다음 상태 및 출력 계산
    always @(*) begin
        next = state;
        tick_count_next = tick_count_reg;
        bit_count_next = bit_count_reg;
        rx_done_next = 1'b0;
        rx_data_next = rx_data_reg;
        
        case (state)
            IDLE: begin
                tick_count_next = 0;
                bit_count_next = 0;
                rx_done_next = 1'b0;
                if(rx == 1'b0) begin
                    next = START;
                end
            end
            START: begin
                if(tick == 1'b1) begin
                    if(tick_count_reg == 7) begin
                        next = DATA;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            DATA: begin
                if(tick == 1'b1) begin
                    if(tick_count_reg == 15) begin
                        rx_data_next[bit_count_reg] = rx; // 데이터 읽기
                        if(bit_count_reg == 7) begin
                            next = STOP;
                            tick_count_next = 0;
                        end else begin
                            next = DATA;
                            bit_count_next = bit_count_reg + 1;
                            tick_count_next = 0;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            STOP: begin
                if(tick == 1'b1) begin
                    if (tick_count_reg == 23) begin
                        rx_done_next = 1'b1;
                        next = IDLE;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

// 보드레이트 생성기 모듈
module baud_tick_gen (
    input clk,
    input rst,
    output baud_tick
);
    parameter BAUD_RATE = 9600;
    localparam BAUD_COUNT = (100_000_000 / BAUD_RATE) / 16; // 주파수 계산
    reg [$clog2(BAUD_COUNT) - 1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;
    
    // 출력 할당
    assign baud_tick = tick_reg;
    
    // 레지스터 업데이트
    always @(posedge clk, posedge rst) begin
        if(rst == 1) begin
            count_reg <= 0;
            tick_reg <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg <= tick_next;
        end
    end
    
    // 다음 값 계산
    always @(*) begin
        count_next = count_reg;
        tick_next = tick_reg;
        
        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next = 1'b1;
        end else begin
            count_next = count_reg + 1;
            tick_next = 1'b0;
        end
    end
endmodule