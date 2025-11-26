// Improved Approximate Logarithmic Multipliers
// Three designs with different accuracy/power tradeoffs

// Design 1: Enhanced DR-ALM with better error compensation
// Uses improved LSB compensation and rounding
module enhanced_dr_alm_8bit #(
    parameter TRUNC_WIDTH = 6
) (
    input  logic [7:0] i_a,
    input  logic [7:0] i_b,
    output logic [15:0] o_z
);

    logic [2:0] k1, k2;
    logic [6:0] x1, x2;
    logic [TRUNC_WIDTH-1:0] x1t, x2t;
    logic [TRUNC_WIDTH:0] sum_x;
    logic [3:0] k_sum;
    logic [TRUNC_WIDTH-1:0] xt;
    logic [15:0] result;
    logic overflow;

    // Enhanced: Add correction term based on truncated bits
    logic [1:0] correction;

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
            k1 = find_leading_one(i_a);
            k2 = find_leading_one(i_b);

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

            // Enhanced truncation with rounding
            x1t = {x1[6:8-TRUNC_WIDTH], 1'b1};
            x2t = {x2[6:8-TRUNC_WIDTH], 1'b1};

            // Improved correction: add 2 instead of 1 for better median error
            sum_x = {1'b0, x1t} + {1'b0, x2t} + 2'd2;

            overflow = sum_x[TRUNC_WIDTH];

            if (overflow) begin
                k_sum = {1'b0, k1} + {1'b0, k2} + 4'd1;
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end else begin
                k_sum = {1'b0, k1} + {1'b0, k2};
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end

            result = {xt, {(16-TRUNC_WIDTH){1'b0}}};
            o_z = result >> (15 - k_sum);
        end
    end

endmodule : enhanced_dr_alm_8bit

// Design 2: Hybrid multiplier - uses exact for small operands
// Small operands have higher relative error, so use exact multiplication
module hybrid_alm_8bit #(
    parameter TRUNC_WIDTH = 6,
    parameter THRESHOLD = 4'd8  // Use exact mult if both operands < threshold
) (
    input  logic [7:0] i_a,
    input  logic [7:0] i_b,
    output logic [15:0] o_z
);

    logic [15:0] exact_result;
    logic [15:0] approx_result;
    logic use_exact;

    // Exact multiplication for small operands
    assign exact_result = i_a * i_b;

    // Check if operands are small (high relative error region)
    assign use_exact = (i_a < THRESHOLD) || (i_b < THRESHOLD);

    // DR-ALM for larger operands
    logic [2:0] k1, k2;
    logic [6:0] x1, x2;
    logic [TRUNC_WIDTH-1:0] x1t, x2t;
    logic [TRUNC_WIDTH:0] sum_x;
    logic [3:0] k_sum;
    logic [TRUNC_WIDTH-1:0] xt;
    logic [15:0] result;
    logic overflow;

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
            approx_result = 16'd0;
        end else begin
            k1 = find_leading_one(i_a);
            k2 = find_leading_one(i_b);

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

            x1t = {x1[6:8-TRUNC_WIDTH], 1'b1};
            x2t = {x2[6:8-TRUNC_WIDTH], 1'b1};
            sum_x = {1'b0, x1t} + {1'b0, x2t} + 1'b1;

            overflow = sum_x[TRUNC_WIDTH];

            if (overflow) begin
                k_sum = {1'b0, k1} + {1'b0, k2} + 4'd1;
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end else begin
                k_sum = {1'b0, k1} + {1'b0, k2};
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end

            result = {xt, {(16-TRUNC_WIDTH){1'b0}}};
            approx_result = result >> (15 - k_sum);
        end

        // Select based on operand magnitude
        o_z = use_exact ? exact_result : approx_result;
    end

endmodule : hybrid_alm_8bit

// Design 3: Iterative refinement ALM
// Adds one iteration of error correction
module iterative_alm_8bit #(
    parameter TRUNC_WIDTH = 6
) (
    input  logic [7:0] i_a,
    input  logic [7:0] i_b,
    output logic [15:0] o_z
);

    logic [2:0] k1, k2;
    logic [6:0] x1, x2;
    logic [TRUNC_WIDTH-1:0] x1t, x2t;
    logic [TRUNC_WIDTH:0] sum_x;
    logic [3:0] k_sum;
    logic [TRUNC_WIDTH-1:0] xt;
    logic [15:0] result;
    logic overflow;

    // Correction terms
    logic [7:0] x1_x2_approx;
    logic [15:0] correction;

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
            k1 = find_leading_one(i_a);
            k2 = find_leading_one(i_b);

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

            x1t = {x1[6:8-TRUNC_WIDTH], 1'b1};
            x2t = {x2[6:8-TRUNC_WIDTH], 1'b1};

            // Mitchell's approximation error correction term: x1*x2
            // Approximate x1*x2 using truncated values
            x1_x2_approx = (x1[6:3] * x2[6:3]);

            // Add correction scaled by 2^(k1+k2-7)
            sum_x = {1'b0, x1t} + {1'b0, x2t} + 1'b1;

            overflow = sum_x[TRUNC_WIDTH];

            if (overflow) begin
                k_sum = {1'b0, k1} + {1'b0, k2} + 4'd1;
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end else begin
                k_sum = {1'b0, k1} + {1'b0, k2};
                xt = {1'b1, sum_x[TRUNC_WIDTH-2:0]};
            end

            result = {xt, {(16-TRUNC_WIDTH){1'b0}}};
            result = result >> (15 - k_sum);

            // Add scaled correction term
            if (k_sum >= 7)
                correction = {8'b0, x1_x2_approx} << (k_sum - 7);
            else
                correction = {8'b0, x1_x2_approx} >> (7 - k_sum);

            o_z = result + correction[15:0];
        end
    end

endmodule : iterative_alm_8bit

// Signed wrappers for all designs
module enhanced_dr_alm_8bit_signed #(
    parameter TRUNC_WIDTH = 6
) (
    input  logic signed [7:0] i_a,
    input  logic signed [7:0] i_b,
    output logic signed [15:0] o_z
);
    logic [7:0] abs_a, abs_b;
    logic [15:0] unsigned_product;
    logic sign_result;

    assign sign_result = i_a[7] ^ i_b[7];

    always_comb begin
        abs_a = i_a[7] ? (-i_a) : i_a;
        abs_b = i_b[7] ? (-i_b) : i_b;
    end

    enhanced_dr_alm_8bit #(.TRUNC_WIDTH(TRUNC_WIDTH)) mult_core (
        .i_a(abs_a), .i_b(abs_b), .o_z(unsigned_product)
    );

    always_comb begin
        if (sign_result)
            o_z = -$signed({1'b0, unsigned_product});
        else
            o_z = $signed({1'b0, unsigned_product});
    end
endmodule : enhanced_dr_alm_8bit_signed

module hybrid_alm_8bit_signed #(
    parameter TRUNC_WIDTH = 6,
    parameter THRESHOLD = 4'd8
) (
    input  logic signed [7:0] i_a,
    input  logic signed [7:0] i_b,
    output logic signed [15:0] o_z
);
    logic [7:0] abs_a, abs_b;
    logic [15:0] unsigned_product;
    logic sign_result;

    assign sign_result = i_a[7] ^ i_b[7];

    always_comb begin
        abs_a = i_a[7] ? (-i_a) : i_a;
        abs_b = i_b[7] ? (-i_b) : i_b;
    end

    hybrid_alm_8bit #(.TRUNC_WIDTH(TRUNC_WIDTH), .THRESHOLD(THRESHOLD)) mult_core (
        .i_a(abs_a), .i_b(abs_b), .o_z(unsigned_product)
    );

    always_comb begin
        if (sign_result)
            o_z = -$signed({1'b0, unsigned_product});
        else
            o_z = $signed({1'b0, unsigned_product});
    end
endmodule : hybrid_alm_8bit_signed

module iterative_alm_8bit_signed #(
    parameter TRUNC_WIDTH = 6
) (
    input  logic signed [7:0] i_a,
    input  logic signed [7:0] i_b,
    output logic signed [15:0] o_z
);
    logic [7:0] abs_a, abs_b;
    logic [15:0] unsigned_product;
    logic sign_result;

    assign sign_result = i_a[7] ^ i_b[7];

    always_comb begin
        abs_a = i_a[7] ? (-i_a) : i_a;
        abs_b = i_b[7] ? (-i_b) : i_b;
    end

    iterative_alm_8bit #(.TRUNC_WIDTH(TRUNC_WIDTH)) mult_core (
        .i_a(abs_a), .i_b(abs_b), .o_z(unsigned_product)
    );

    always_comb begin
        if (sign_result)
            o_z = -$signed({1'b0, unsigned_product});
        else
            o_z = $signed({1'b0, unsigned_product});
    end
endmodule : iterative_alm_8bit_signed
