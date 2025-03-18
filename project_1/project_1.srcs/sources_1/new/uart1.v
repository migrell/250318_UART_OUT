`timescale 1ns / 1ps

module uart (
    input clk,
    input rst,
    input btn_start,
    input [7:0] tx_data_in,
    output tx_done,
    output tx,
    output [1:0] state_out,

    input rx,
    output rx_done,
    output [7:0] rx_data
);
    // --------- 내부 신호 선언 ---------
    wire w_tick;


    //     uart U_UART_TX (
    //     .clk(clk),
    //     .rst(rst),
    //     .btn_start(send_reg),
    //     .tx_data_in(send_tx_data_reg),
    //     .tx_done(w_tx_done),
    //     .tx(tx)
    // );


    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .rx(rx),
        .rx_done(rx_done),
        .rx_data(rx_data)

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





    // FSM 상태 정의
    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    // 레지스터 선언
    reg [1:0] state, next;
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;
    reg [2:0] data_count, data_count_next;
    reg [3:0] tick_count_reg, tick_count_next;

    // 보드레이트 생성기 관련 신호
    parameter BAUD_RATE = 9600;
    localparam BAUD_COUNT = (100_000_000 / BAUD_RATE) / 16;
    reg [$clog2(BAUD_COUNT) - 1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;

    // --------- 출력 신호 할당 ---------
    assign tx = tx_reg;
    assign tx_done = tx_done_reg;
    assign state_out = state;
    assign w_tick = tick_reg;

    // --------- 보드레이트 생성기 로직 ---------
    always @(posedge clk, posedge rst) begin
        if (rst == 1) begin
            count_reg <= 0;
            tick_reg  <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg  <= tick_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        tick_next  = 1'b0;

        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next  = 1'b1;
        end else begin
            count_next = count_reg + 1;
        end
    end

    // --------- UART 송신기 레지스터 업데이트 ---------
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_reg <= 1'b1;
            tx_done_reg <= 1'b1;
            data_count <= 0;
            tick_count_reg <= 0;
        end else begin
            state <= next;
            tx_reg <= tx_next;
            tx_done_reg <= tx_done_next;
            data_count <= data_count_next;
            tick_count_reg <= tick_count_next;
        end
    end

    // --------- UART 송신기 조합 로직 ---------
    always @(*) begin
        next = state;
        tx_next = tx_reg;
        tx_done_next = tx_done_reg;
        data_count_next = data_count;
        tick_count_next = tick_count_reg;

        case (state)
            IDLE: begin
                tx_next = 1'b1;
                tx_done_next = 1'b1;
                data_count_next = 3'b000;
                tick_count_next = 4'h0;

                if (btn_start) begin
                    next = START;
                    tx_done_next = 1'b0;
                end
            end

            START: begin
                tx_next = 1'b0;

                if (w_tick) begin
                    if (tick_count_reg >= 15) begin
                        tick_count_next = 0;
                        next = DATA;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = tx_data_in[data_count];

                if (w_tick) begin
                    if (tick_count_reg >= 15) begin
                        tick_count_next = 0;

                        if (data_count == 3'b111) begin
                            next = STOP;
                            data_count_next = 3'b000;
                        end else begin
                            data_count_next = data_count + 1;
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;

                if (w_tick) begin
                    if (tick_count_reg >= 15) begin
                        tx_done_next = 1'b1;
                        next = IDLE;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            default: begin
                next = IDLE;
                tx_next = 1'b1;
                tx_done_next = 1'b1;
                data_count_next = 3'b000;
                tick_count_next = 0;
            end
        endcase
    end
endmodule



`timescale 1ns / 1ps

module uart_tx (
    input clk,
    input rst,
    input tick,
    input start_trigger,
    input [7:0] data_in,
    output o_tx_done,
    output o_tx,
    output [1:0] state_out
);
    // FSM 상태 정의 - 4-state Mealy model
    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0] state, next;
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;

    assign state_out = state;  // state_out으로 현재 상태 출력

    // 데이터 카운터 추가 (0-7)
    reg [2:0] data_count, data_count_next;
    reg [3:0] tick_count_reg, tick_count_next;

    // 출력 할당
    assign o_tx = tx_reg;
    assign o_tx_done = tx_done_reg;

    // 상태 레지스터 및 출력 레지스터
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            tx_reg         <= 1'b1;  // UART의 기본 idle 상태는 high
            tx_done_reg    <= 1'b1;  // 초기 상태는 준비 완료
            data_count     <= 0;  // 데이터 카운터 초기화
            tick_count_reg <= 0;
        end else begin
            state <= next;
            tx_reg <= tx_next;
            tx_done_reg <= tx_done_next;
            data_count <= data_count_next;
            tick_count_reg <= tick_count_next;
        end
    end

    // 다음 상태 및 출력 로직 - 래치 방지를 위한 모든 경우의 신호 명시적 할당
    always @(*) begin
        // 모든 신호에 대한 기본값 설정 (래치 방지)
        next = state;
        tx_next = tx_reg;
        tx_done_next = tx_done_reg;
        data_count_next = data_count;
        tick_count_next = tick_count_reg;

        case (state)
            IDLE: begin
                tx_next = 1'b1;  // idle 상태에서는 high
                tx_done_next = 1'b1;  // 전송 준비 완료
                data_count_next = 3'b000;  // 데이터 카운터 초기화
                tick_count_next = 0;

                if (start_trigger) begin
                    next = START;  // 시작 트리거가 있으면 START 상태로 전환
                    tx_done_next = 1'b0;  // 전송 시작, 준비 상태 해제
                end
            end

            START: begin
                tx_next = 1'b0;  // 시작 비트는 항상 0 (래치 방지를 위해 항상 설정)

                if (tick) begin
                    if (tick_count_reg >= 15) begin
                        tick_count_next = 0;
                        next = DATA;  // 다음은 데이터 비트 전송
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            DATA: begin
                // 현재 데이터 비트 설정 (래치 방지를 위해 항상 설정)
                tx_next = data_in[data_count];

                if (tick) begin
                    if (tick_count_reg >= 15) begin
                        // 다음 비트 또는 상태 전환 로직
                        if (data_count == 3'b111) begin
                            next = STOP;  // 마지막 비트 후 STOP으로 전환
                            data_count_next = 3'b000;  // 카운터 초기화
                        end else begin
                            data_count_next = data_count + 1; // 다음 비트로
                        end
                        tick_count_next = 0;  // 틱 카운터 초기화
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;  // 정지 비트는 항상 1

                if (tick) begin
                    if (tick_count_reg >= 15) begin
                        tx_done_next = 1'b1;  // 전송완료 신호->1
                        next = IDLE;
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            default: begin
                next = IDLE;
                tx_next = 1'b1;
                tx_done_next = 1'b1;
                data_count_next = 3'b000;
                tick_count_next = 0;
            end
        endcase
    end
endmodule


`timescale 1ns / 1ps

module baud_tick_gen (
    input  clk,
    input  rst,
    output baud_tick
);
    // 9600 baud rate 설정
    parameter BAUD_RATE = 9600;
    localparam BAUD_COUNT = (100_000_000 / BAUD_RATE) / 16; // 16배 빠른 틱 주파수

    reg [$clog2(BAUD_COUNT) - 1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;

    // 출력 할당
    assign baud_tick = tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst == 1) begin
            count_reg <= 0;
            tick_reg  <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg  <= tick_next;
        end
    end

    // 다음 상태 로직
    always @(*) begin
        count_next = count_reg;
        tick_next  = tick_reg;

        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next  = 1'b1;
        end else begin
            count_next = count_reg + 1;
            tick_next  = 1'b0;
        end
    end
endmodule


module uart_rx (
    input clk,
    input rst,
    input tick,
    input rx,
    output rx_done,
    output [7:0] rx_data
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] state, next;

    reg rx_done_reg, rx_done_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [4:0] tick_count_reg, tick_count_next;
    reg [7:0] rx_data_reg, rx_data_next;

    //output
    assign rx_done = rx_done_reg;
    assign rx_data = rx_data_reg;

    //state
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
    end  //state complete 

    //next
    always @(*) begin
        next = state;
        tick_count_next = tick_count_reg;  // 초기화
        bit_count_next = bit_count_reg;
        rx_done_next = 0;  // 누락된 초기화 추가
        // rx_data_next = rx_data_reg;  // 누락된 초기화 추가

        case (state)
            IDLE: begin
                tick_count_next = 0;
                bit_count_next = 0;
                rx_done_next = 0;  // IDLE 상태에서 rx_done 신호 초기화

                if (rx == 0) begin
                    next = START;
                end
            end

            START: begin
                if (tick == 1) begin
                    if (tick_count_reg == 7) begin
                        next = DATA;
                        tick_count_next = 0;  // 다음 상태로 전환 시 카운터 초기화
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end  //8회 반복 
            end

            DATA: begin
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        // read data
                        rx_data_next[bit_count_reg] = rx;
                        if (bit_count_reg == 7) begin
                            next = STOP;
                            tick_count_next = 0;  // tick count 초기화
                        end else begin
                            next = DATA;
                            bit_count_next = bit_count_reg + 1;
                            tick_count_next = 0;  // tick count 초기화
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                if (tick == 1) begin
                    if (tick_count_reg == 23) begin //STATE 1 FRAME 빨라서 TICK 수정
                        rx_done_next = 1;  // 데이터 수신 완료 신호 설정
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end


            default: begin
                next = IDLE;
                tick_count_next = 0;
                bit_count_next = 0;
                rx_done_next = 0;
            end
        endcase
    end
endmodule

module TOP_UART (
    input  clk,
    input  rst,
    input  rx,
    output tx
);
    wire w_rx_done;
    wire [7:0] w_rx_data;
    
    // 단일 UART 모듈 사용 - 회로도에 맞게 구성
    uart U_UART (
        .clk(clk),
        .rst(rst),
        .btn_start(w_rx_done),  // 수신 완료 시 송신 시작
        .tx_data_in(w_rx_data), // 수신한 데이터를 송신 데이터로 사용
        .tx_done(),
        .tx(tx),
        .state_out(),
        .rx(rx),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

endmodule



    // UART 송신기


















