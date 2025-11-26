module improved_dr_alm #(
    parameter M_WIDTH = 5 // Number of mantissa bits to keep
) (
    input  logic signed [ 7:0] i_a,
    input  logic signed [ 7:0] i_b,
    output logic signed [15:0] o_z
);

  logic [7:0] abs_a, abs_b;
  logic sign_a, sign_b, sign_z;
  logic [2:0] k_a, k_b;
  logic [6:0] frac_a, frac_b;
  logic [M_WIDTH-1:0] frac_a_trunc, frac_b_trunc;
  logic [3:0] sum_k;
  logic [M_WIDTH:0] sum_frac_trunc;
  logic [7:0] sum_frac_restored;
  logic [15:0] result_mag;
  
  // Error compensation logic
  logic [6:0] trunc_a, trunc_b;
  logic [M_WIDTH:0] compensation;

  // Sign and Absolute Value
  assign sign_a = i_a[7];
  assign sign_b = i_b[7];
  assign sign_z = sign_a ^ sign_b;

  assign abs_a = sign_a ? -i_a : i_a;
  assign abs_b = sign_b ? -i_b : i_b;

  // Leading One Detector
  function automatic [2:0] get_k(input logic [7:0] val);
    if (val[7]) return 7;
    if (val[6]) return 6;
    if (val[5]) return 5;
    if (val[4]) return 4;
    if (val[3]) return 3;
    if (val[2]) return 2;
    if (val[1]) return 1;
    return 0;
  endfunction

  assign k_a = get_k(abs_a);
  assign k_b = get_k(abs_b);

  // Mantissa Extraction
  logic [7:0] norm_a, norm_b;
  assign norm_a = abs_a << (7 - k_a);
  assign norm_b = abs_b << (7 - k_b);
  
  assign frac_a = norm_a[6:0];
  assign frac_b = norm_b[6:0];

  // Truncation - Keep top M_WIDTH bits
  assign frac_a_trunc = frac_a[6 : 7-M_WIDTH];
  assign frac_b_trunc = frac_b[6 : 7-M_WIDTH];
  
  // Capture truncated portion for error compensation
  assign trunc_a = frac_a & ((1 << (7-M_WIDTH)) - 1);
  assign trunc_b = frac_b & ((1 << (7-M_WIDTH)) - 1);

  // Error Compensation Logic - Best Strategy: Magnitude-Aware with k>=3
  // Only apply compensation when both inputs have sufficient magnitude (>=8)
  // For smaller values, compensation introduces more error than benefit
  always_comb begin
    if (7-M_WIDTH > 0) begin
      logic apply_compensation;
      apply_compensation = (k_a >= 3) && (k_b >= 3);
      
      if (apply_compensation) begin
        // Conservative 75% threshold for compensation
        logic [6:0] sum_trunc;
        sum_trunc = {1'b0, trunc_a[7-M_WIDTH-1:0]} + {1'b0, trunc_b[7-M_WIDTH-1:0]};
        
        // Compensate if sum >= 75% of maximum possible truncated sum
        // 75% = 50% + 25% = (sum >> 1) + (sum >> 2)
        if (sum_trunc >= ((sum_trunc >> 1) + (sum_trunc >> 2))) begin
          compensation = 1;
        end else begin
          compensation = 0;
        end
      end else begin
        compensation = 0;
      end
    end else begin
      compensation = 0;
    end
  end

  // Sum of characteristics and truncated mantissas with compensation
  assign sum_k = k_a + k_b;
  assign sum_frac_trunc = {1'b0, frac_a_trunc} + {1'b0, frac_b_trunc} + compensation;

  // Restore to 7-bit width (pad with zeros)
  assign sum_frac_restored = {sum_frac_trunc, {7-M_WIDTH{1'b0}}};

  // Antilogarithm Approximation (Mitchell's)
  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 0;
    end else begin
      if (sum_frac_restored[7]) begin
        // sum >= 1.0
        if (sum_k + 1 >= 7)
            result_mag = {8'b0, sum_frac_restored} << (sum_k + 1 - 7);
        else
            result_mag = {8'b0, sum_frac_restored} >> (7 - (sum_k + 1));
      end else begin
        // sum < 1.0
        if (sum_k >= 7)
            result_mag = {8'b0, (8'd128 | sum_frac_restored)} << (sum_k - 7);
        else
            result_mag = {8'b0, (8'd128 | sum_frac_restored)} >> (7 - sum_k);
      end
    end
  end

  assign o_z = sign_z ? -result_mag : result_mag;

endmodule