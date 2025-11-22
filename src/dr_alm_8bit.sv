// 8-bit Dynamic Range Approximate Logarithmic Multiplier (DR-ALM)
// Based on: "Design and Analysis of Energy-Efficient Dynamic Range
// Approximate Logarithmic Multipliers for Machine Learning"
// Yin et al., IEEE TSUSC 2021

module dr_alm_8bit #(
    parameter TRUNC_WIDTH = 6  // Truncation width (t) - DR-ALM-6
) (
    input  logic [7:0] i_a,
    input  logic [7:0] i_b,
    output logic [15:0] o_z
);

    // Internal signals
    logic [2:0] k1, k2;
    logic [6:0] x1, x2;  // Fractional parts (7 bits for 8-bit input)
    logic [TRUNC_WIDTH-1:0] x1t, x2t;
    logic [TRUNC_WIDTH:0] sum_x;  // x1t + x2t + compensation
    logic [3:0] k_sum;
    logic [TRUNC_WIDTH-1:0] xt;  // Result mantissa
    logic [15:0] result;
    logic overflow;

    // LOD function
    function automatic [2:0] find_leading_one(input logic [7:0] data);
        casez (data)
            8'b1???????: find_leading_one = 3'd7;
            8'b01??????: find_leading_one = 3'd6;
            8'b001?????: find_leading_one = 3'd5;
            8'b0001????: find_leading_one = 3'd4;
            8'b00001???: find_leading_one = 3'd3;
            8'b000001??: find_leading_one = 3'd2;
            8'b0000001?: find_leading_one = 3'd1;
            8'b00000001: find_leading_one = 3'd0;
            default:     find_leading_one = 3'd0;
        endcase
    endfunction

    always_comb begin
        if (i_a == 0 || i_b == 0) begin
            o_z = 16'd0;
        end else begin
            // Step 1: Find leading one positions
            k1 = find_leading_one(i_a);
            k2 = find_leading_one(i_b);

            // Step 2: Extract fractional part (bits below leading 1)
            case (k1)
                3'd7: x1 = i_a[6:0];
                3'd6: x1 = {i_a[5:0], 1'b0};
                3'd5: x1 = {i_a[4:0], 2'b0};
                3'd4: x1 = {i_a[3:0], 3'b0};
                3'd3: x1 = {i_a[2:0], 4'b0};
                3'd2: x1 = {i_a[1:0], 5'b0};
                3'd1: x1 = {i_a[0], 6'b0};
                3'd0: x1 = 7'b0;
            endcase

            case (k2)
                3'd7: x2 = i_b[6:0];
                3'd6: x2 = {i_b[5:0], 1'b0};
                3'd5: x2 = {i_b[4:0], 2'b0};
                3'd4: x2 = {i_b[3:0], 3'b0};
                3'd3: x2 = {i_b[2:0], 4'b0};
                3'd2: x2 = {i_b[1:0], 5'b0};
                3'd1: x2 = {i_b[0], 6'b0};
                3'd0: x2 = 7'b0;
            endcase

            // Step 3: Truncate to t bits with LSB=1 compensation
            x1t = {x1[6:8-TRUNC_WIDTH], 1'b1};
            x2t = {x2[6:8-TRUNC_WIDTH], 1'b1};

            // Step 4: Add truncated fractions with compensation (+1)
            sum_x = {1'b0, x1t} + {1'b0, x2t} + 1'b1;

            // Check overflow
            overflow = sum_x[TRUNC_WIDTH];

            // Step 5: Antilogarithmic conversion
            // Per Algorithm 1: xt = {1'b1, L[t-2:0]}
            if (overflow) begin
                // Overflow: x1t + x2t >= 1
                k_sum = {1'b0, k1} + {1'b0, k2} + 4'd1;
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end else begin
                // No overflow
                k_sum = {1'b0, k1} + {1'b0, k2};
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end

            // Step 6: Shift result
            result = {xt, {(16-TRUNC_WIDTH){1'b0}}};
            o_z = result >> (15 - k_sum);
        end
    end

endmodule : dr_alm_8bit

// Signed wrapper for DR-ALM
module dr_alm_8bit_signed #(
    parameter TRUNC_WIDTH = 6
) (
    input  logic signed [7:0] i_a,
    input  logic signed [7:0] i_b,
    output logic signed [15:0] o_z
);

    logic [7:0] abs_a, abs_b;
    logic [15:0] unsigned_product;
    logic sign_a, sign_b, sign_result;

    assign sign_a = i_a[7];
    assign sign_b = i_b[7];
    assign sign_result = sign_a ^ sign_b;

    // Get absolute values
    always_comb begin
        abs_a = sign_a ? (-i_a) : i_a;
        abs_b = sign_b ? (-i_b) : i_b;
    end

    // Unsigned multiplication
    dr_alm_8bit #(.TRUNC_WIDTH(TRUNC_WIDTH)) mult_core (
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

endmodule : dr_alm_8bit_signed
