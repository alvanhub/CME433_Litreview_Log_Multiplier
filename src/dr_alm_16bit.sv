// 16-bit Dynamic Range Approximate Logarithmic Multiplier (DR-ALM)
// Based on: "Design and Analysis of Energy-Efficient Dynamic Range
// Approximate Logarithmic Multipliers for Machine Learning"
// Yin et al., IEEE TSUSC 2021

module dr_alm_16bit #(
    parameter TRUNC_WIDTH = 6  // Truncation width (t) - DR-ALM-6
) (
    input  logic [15:0] i_a,
    input  logic [15:0] i_b,
    output logic [31:0] o_z
);

    // Internal signals
    logic [3:0] k1, k2;
    logic [14:0] x1, x2;  // Fractional parts (15 bits for 16-bit input)
    logic [TRUNC_WIDTH-1:0] x1t, x2t;
    logic [TRUNC_WIDTH:0] sum_x;  // x1t + x2t + compensation
    logic [4:0] k_sum;
    logic [TRUNC_WIDTH-1:0] xt;  // Result mantissa
    logic [31:0] result;
    logic overflow;

    // LOD function for 16-bit input
    function automatic [3:0] find_leading_one(input logic [15:0] data);
        casez (data)
            16'b1???????????????: find_leading_one = 4'd15;
            16'b01??????????????: find_leading_one = 4'd14;
            16'b001?????????????: find_leading_one = 4'd13;
            16'b0001????????????: find_leading_one = 4'd12;
            16'b00001???????????: find_leading_one = 4'd11;
            16'b000001??????????: find_leading_one = 4'd10;
            16'b0000001?????????: find_leading_one = 4'd9;
            16'b00000001????????: find_leading_one = 4'd8;
            16'b000000001???????: find_leading_one = 4'd7;
            16'b0000000001??????: find_leading_one = 4'd6;
            16'b00000000001?????: find_leading_one = 4'd5;
            16'b000000000001????: find_leading_one = 4'd4;
            16'b0000000000001???: find_leading_one = 4'd3;
            16'b00000000000001??: find_leading_one = 4'd2;
            16'b000000000000001?: find_leading_one = 4'd1;
            16'b0000000000000001: find_leading_one = 4'd0;
            default:              find_leading_one = 4'd0;
        endcase
    endfunction

    always_comb begin
        if (i_a == 0 || i_b == 0) begin
            o_z = 32'd0;
        end else begin
            // Step 1: Find leading one positions
            k1 = find_leading_one(i_a);
            k2 = find_leading_one(i_b);

            // Step 2: Extract fractional part (bits below leading 1)
            case (k1)
                4'd15: x1 = i_a[14:0];
                4'd14: x1 = {i_a[13:0], 1'b0};
                4'd13: x1 = {i_a[12:0], 2'b0};
                4'd12: x1 = {i_a[11:0], 3'b0};
                4'd11: x1 = {i_a[10:0], 4'b0};
                4'd10: x1 = {i_a[9:0], 5'b0};
                4'd9:  x1 = {i_a[8:0], 6'b0};
                4'd8:  x1 = {i_a[7:0], 7'b0};
                4'd7:  x1 = {i_a[6:0], 8'b0};
                4'd6:  x1 = {i_a[5:0], 9'b0};
                4'd5:  x1 = {i_a[4:0], 10'b0};
                4'd4:  x1 = {i_a[3:0], 11'b0};
                4'd3:  x1 = {i_a[2:0], 12'b0};
                4'd2:  x1 = {i_a[1:0], 13'b0};
                4'd1:  x1 = {i_a[0], 14'b0};
                4'd0:  x1 = 15'b0;
            endcase

            case (k2)
                4'd15: x2 = i_b[14:0];
                4'd14: x2 = {i_b[13:0], 1'b0};
                4'd13: x2 = {i_b[12:0], 2'b0};
                4'd12: x2 = {i_b[11:0], 3'b0};
                4'd11: x2 = {i_b[10:0], 4'b0};
                4'd10: x2 = {i_b[9:0], 5'b0};
                4'd9:  x2 = {i_b[8:0], 6'b0};
                4'd8:  x2 = {i_b[7:0], 7'b0};
                4'd7:  x2 = {i_b[6:0], 8'b0};
                4'd6:  x2 = {i_b[5:0], 9'b0};
                4'd5:  x2 = {i_b[4:0], 10'b0};
                4'd4:  x2 = {i_b[3:0], 11'b0};
                4'd3:  x2 = {i_b[2:0], 12'b0};
                4'd2:  x2 = {i_b[1:0], 13'b0};
                4'd1:  x2 = {i_b[0], 14'b0};
                4'd0:  x2 = 15'b0;
            endcase

            // Step 3: Truncate to t bits with LSB=1 compensation
            x1t = {x1[14:16-TRUNC_WIDTH], 1'b1};
            x2t = {x2[14:16-TRUNC_WIDTH], 1'b1};

            // Step 4: Add truncated fractions with compensation (+1)
            sum_x = {1'b0, x1t} + {1'b0, x2t} + 1'b1;

            // Check overflow
            overflow = sum_x[TRUNC_WIDTH];

            // Step 5: Antilogarithmic conversion
            // The mantissa uses upper bits of sum: sum_x[t-1:1] to get proper scaling
            if (overflow) begin
                // Overflow: x1t + x2t >= 1
                k_sum = {1'b0, k1} + {1'b0, k2} + 5'd1;
                xt = {1'b1, sum_x[TRUNC_WIDTH-1:1]};
            end else begin
                // No overflow
                k_sum = {1'b0, k1} + {1'b0, k2};
                xt = {1'b1, sum_x[TRUNC_WIDTH-1:1]};
            end

            // Step 6: Shift result
            result = {xt, {(32-TRUNC_WIDTH){1'b0}}};
            o_z = result >> (31 - k_sum);
        end
    end

endmodule : dr_alm_16bit

// Signed wrapper for 16-bit DR-ALM
module dr_alm_16bit_signed #(
    parameter TRUNC_WIDTH = 6
) (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

    logic [15:0] abs_a, abs_b;
    logic [31:0] unsigned_product;
    logic sign_a, sign_b, sign_result;

    assign sign_a = i_a[15];
    assign sign_b = i_b[15];
    assign sign_result = sign_a ^ sign_b;

    // Get absolute values
    always_comb begin
        abs_a = sign_a ? (-i_a) : i_a;
        abs_b = sign_b ? (-i_b) : i_b;
    end

    // Unsigned multiplication
    dr_alm_16bit #(.TRUNC_WIDTH(TRUNC_WIDTH)) mult_core (
        .i_a(abs_a),
        .i_b(abs_b),
        .o_z(unsigned_product)
    );

    // Apply sign to result
    always_comb begin
        if (sign_result)
            o_z = -$signed({1'b0, unsigned_product});
        else
            o_z = $signed({1'b0, unsigned_product});
    end

endmodule : dr_alm_16bit_signed
