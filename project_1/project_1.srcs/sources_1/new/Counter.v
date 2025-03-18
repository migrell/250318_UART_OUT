// 비트 카운터 모듈
module bit_counter(
    input clk,
    input rst,
    input start,
    input tick,
    output reg [3:0] bit_position,
    output reg active,
    output reg done
);
    reg [3:0] count;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            active <= 0;
            done <= 0;
            bit_position <= 0;
        end else if (start && !active) begin
            active <= 1;
            done <= 0;
            count <= 0;
        end else if (active && tick) begin
            if (count == 9) begin
                active <= 0;
                done <= 1;
            end else begin
                count <= count + 1;
                bit_position <= count;
            end
        end else begin
            done <= 0;
        end
    end
endmodule