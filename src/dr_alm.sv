module dr_alm #(
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
  logic [M_WIDTH:0] sum_frac_trunc; // 1 bit extra for carry
  logic [7:0] sum_frac_restored;
  logic [15:0] result_mag;

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

  // Truncation
  // Keep top M_WIDTH bits.
  // Example: if M_WIDTH=4, keep bits 6,5,4,3.
  assign frac_a_trunc = frac_a[6 : 7-M_WIDTH];
  assign frac_b_trunc = frac_b[6 : 7-M_WIDTH];

  // Sum of characteristics and truncated mantissas
  assign sum_k = k_a + k_b;
  assign sum_frac_trunc = {1'b0, frac_a_trunc} + {1'b0, frac_b_trunc};

  // Restore to 7-bit width (pad with zeros)
  // sum_frac_trunc has M_WIDTH fractional bits (plus carry).
  // We need 7 fractional bits.
  // So shift left by (7 - M_WIDTH).
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
