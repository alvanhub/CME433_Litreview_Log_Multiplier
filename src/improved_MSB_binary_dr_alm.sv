// Reference: "Design and Analysis of Energy-Efficient Dynamic Range Approximate Logarithmic Multipliers"
// Improvement: "Improved MSB" Truncation + Binary Tree LOD for High Speed.

module improved_MSB_dr_alm #(
    parameter integer WIDTH = 16,       
    parameter integer KEEP_WIDTH = 5
)(
    input  logic signed [WIDTH-1:0] i_a,
    input  logic signed [WIDTH-1:0] i_b,
    output logic signed [(2*WIDTH)-1:0] o_z
);

    logic sign_a, sign_b, sign_z;
    logic [WIDTH-1:0] abs_a, abs_b;
    
    // -------------------------------------------------------------------------
    // 1. Sign Handling
    // -------------------------------------------------------------------------
    assign sign_a = i_a[WIDTH-1];
    assign sign_b = i_b[WIDTH-1];
    assign sign_z = sign_a ^ sign_b;

    assign abs_a = sign_a ? -i_a : i_a;
    assign abs_b = sign_b ? -i_b : i_b;

    // -------------------------------------------------------------------------
    // 2. High-Speed Leading One Detector (Binary Tree Approach)
    // -------------------------------------------------------------------------
    // This function replaces the 'for' loop with a parallel 'case' structure.
    // This reduces the logic depth significantly (O(log N) vs O(N)).
    
    function automatic [$clog2(WIDTH)-1:0] get_lod_tree(input [WIDTH-1:0] val);
        // This example is optimized for 16-bit. 
        // For generic widths, recursive functions are needed, but this is 
        // the explicit parallel structure for N=16.
        logic [3:0] lod_out;
        
        // Stage 1: Check upper 8 vs lower 8
        if (val[15:8] != 0) begin
            lod_out[3] = 1'b1;
            // Stage 2: Check upper 4 of the top byte
            if (val[15:12] != 0) begin
                lod_out[2] = 1'b1;
                // Stage 3 & 4 combined (Look Up Table style)
                casez (val[15:12])
                    4'b1???: lod_out[1:0] = 2'b11; // 15
                    4'b01??: lod_out[1:0] = 2'b10; // 14
                    4'b001?: lod_out[1:0] = 2'b01; // 13
                    4'b0001: lod_out[1:0] = 2'b00; // 12
                    default: lod_out[1:0] = 2'b00; 
                endcase
            end else begin
                lod_out[2] = 1'b0;
                casez (val[11:8])
                    4'b1???: lod_out[1:0] = 2'b11; // 11
                    4'b01??: lod_out[1:0] = 2'b10; // 10
                    4'b001?: lod_out[1:0] = 2'b01; // 9
                    4'b0001: lod_out[1:0] = 2'b00; // 8
                    default: lod_out[1:0] = 2'b00;
                endcase
            end
        end else begin
            lod_out[3] = 1'b0;
            if (val[7:4] != 0) begin
                lod_out[2] = 1'b1;
                casez (val[7:4])
                    4'b1???: lod_out[1:0] = 2'b11; // 7
                    4'b01??: lod_out[1:0] = 2'b10; // 6
                    4'b001?: lod_out[1:0] = 2'b01; // 5
                    4'b0001: lod_out[1:0] = 2'b00; // 4
                    default: lod_out[1:0] = 2'b00;
                endcase
            end else begin
                lod_out[2] = 1'b0;
                casez (val[3:0])
                    4'b1???: lod_out[1:0] = 2'b11; // 3
                    4'b01??: lod_out[1:0] = 2'b10; // 2
                    4'b001?: lod_out[1:0] = 2'b01; // 1
                    4'b0001: lod_out[1:0] = 2'b00; // 0
                    default: lod_out[1:0] = 2'b00;
                endcase
            end
        end
        return lod_out;
    endfunction

    logic [$clog2(WIDTH)-1:0] k_a, k_b;
    assign k_a = get_lod_tree(abs_a);
    assign k_b = get_lod_tree(abs_b);

    // -------------------------------------------------------------------------
    // 3. Dynamic Truncation (Your "Improved MSB" Logic)
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] norm_a, norm_b;
    assign norm_a = abs_a << ((WIDTH-1) - k_a);
    assign norm_b = abs_b << ((WIDTH-1) - k_b);

    logic [KEEP_WIDTH-1:0] x_a_trunc, x_b_trunc;

    // Using the improved deterministic slicing
    assign x_a_trunc = norm_a[(WIDTH-2) -: KEEP_WIDTH];
    assign x_b_trunc = norm_b[(WIDTH-2) -: KEEP_WIDTH];

    // -------------------------------------------------------------------------
    // 4. Adder and Compensation
    // -------------------------------------------------------------------------
    logic [$clog2(WIDTH):0] sum_k; 
    assign sum_k = k_a + k_b;

    // The +1'b1 injects into the Carry In of the adder during synthesis
    logic [KEEP_WIDTH:0] sum_x;
    assign sum_x = x_a_trunc + x_b_trunc + 1'b1;

    // -------------------------------------------------------------------------
    // 5. Antilog Converter
    // -------------------------------------------------------------------------
    logic carry_x;
    assign carry_x = sum_x[KEEP_WIDTH];

    logic [$clog2(WIDTH):0] final_k;
    assign final_k = sum_k + carry_x;

    logic [KEEP_WIDTH-1:0] final_x;
    assign final_x = sum_x[KEEP_WIDTH-1:0];

    logic [WIDTH*2-1:0] mantissa_reconst;
    assign mantissa_reconst = {1'b1, final_x};

    // -------------------------------------------------------------------------
    // 6. Final Shifter
    // -------------------------------------------------------------------------
    always_comb begin
        if (i_a == 0 || i_b == 0) begin
            o_z = 0;
        end else begin
            // We can pre-calculate the shift amount to slightly aid timing
            if (final_k >= KEEP_WIDTH)
                o_z = mantissa_reconst << (final_k - KEEP_WIDTH);
            else
                o_z = mantissa_reconst >> (KEEP_WIDTH - final_k);

            if (sign_z) o_z = -o_z;
        end
    end

endmodule