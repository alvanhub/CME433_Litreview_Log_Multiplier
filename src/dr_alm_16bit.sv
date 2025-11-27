/**
 * 16x16-bit Approximate Logarithmic Multiplier (DR-ALM)
 *
 * This module performs multiplication of two 16-bit signed numbers using
 * logarithmic arithmetic, which converts multiplication into addition.
 * The core steps are:
 *   1. Convert numbers to a logarithmic representation (characteristic + mantissa).
 *   2. Add the characteristics and mantissas.
 *   3. Convert the result back to a standard binary number (antilogarithm).
 * This version does not include error compensation logic.
 */
module dr_alm_16 #(
    // Number of mantissa bits to keep after truncation (max 15)
    parameter M_WIDTH = 10
) (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

  logic [15:0] abs_a, abs_b;
  logic sign_a, sign_b, sign_z;
  logic [3:0]  k_a, k_b;
  logic [14:0] frac_a, frac_b;
  logic [M_WIDTH-1:0] frac_a_trunc, frac_b_trunc;
  logic [4:0]  sum_k;
  logic [M_WIDTH:0] sum_frac_trunc; // 1 bit extra for carry
  logic [15:0] sum_frac_restored; // 15 fractional bits + 1 integer bit
  logic [31:0] result_mag;

  // 1. Sign and Absolute Value
  assign sign_a = i_a[15];
  assign sign_b = i_b[15];
  assign sign_z = sign_a ^ sign_b;

  assign abs_a = sign_a ? -i_a : i_a;
  assign abs_b = sign_b ? -i_b : i_b;

  // 2. Leading One Detector (to find the characteristic 'k')
  function automatic [3:0] get_k(input logic [15:0] val);
    if (val[15]) return 15;
    if (val[14]) return 14;
    if (val[13]) return 13;
    if (val[12]) return 12;
    if (val[11]) return 11;
    if (val[10]) return 10;
    if (val[ 9]) return 9;
    if (val[ 8]) return 8;
    if (val[ 7]) return 7;
    if (val[ 6]) return 6;
    if (val[ 5]) return 5;
    if (val[ 4]) return 4;
    if (val[ 3]) return 3;
    if (val[ 2]) return 2;
    if (val[ 1]) return 1;
    return 0;
  endfunction

  assign k_a = get_k(abs_a);
  assign k_b = get_k(abs_b);

  // 3. Mantissa Extraction
  logic [15:0] norm_a, norm_b;
  // Normalize by shifting the MSB to the highest position
  assign norm_a = abs_a << (15 - k_a);
  assign norm_b = abs_b << (15 - k_b);

  // The mantissa is the fractional part (all bits except the MSB)
  assign frac_a = norm_a[14:0];
  assign frac_b = norm_b[14:0];

  // 4. Truncation of Mantissa
  // Keep the top M_WIDTH bits of the 15-bit mantissa.
  assign frac_a_trunc = frac_a[14 : 15-M_WIDTH];
  assign frac_b_trunc = frac_b[14 : 15-M_WIDTH];

  // 5. Summation in Logarithmic Domain
  assign sum_k = k_a + k_b;
  assign sum_frac_trunc = {1'b0, frac_a_trunc} + {1'b0, frac_b_trunc};

  // 6. Restore Mantissa to full 15-bit width for antilog step
  // Pad the truncated result with zeros on the right.
  assign sum_frac_restored = {sum_frac_trunc, {15-M_WIDTH{1'b0}}};
  int shift_amt;
  logic [15:0] mantissa;
  // 7. Antilogarithm Approximation (Mitchell's Method)
  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 32'b0;
    end else begin
      // Check for carry-out (mantissa sum >= 1.0)
      if (sum_frac_restored[15]) begin
        // The sum is >= 1.0, so the characteristic increases by 1
        shift_amt = (sum_k + 1) - 15; // Calculate final shift
        if (shift_amt >= 0)
            result_mag = {16'b0, sum_frac_restored} << shift_amt;
        else
            result_mag = {16'b0, sum_frac_restored} >> -shift_amt;
      end else begin
        // The sum is < 1.0. Add the implicit leading '1' back.
        mantissa = (16'h8000 | sum_frac_restored);
        shift_amt = sum_k - 15; // Calculate final shift
        if (shift_amt >= 0)
            result_mag = {16'b0, mantissa} << shift_amt;
        else
            result_mag = {16'b0, mantissa} >> -shift_amt;
      end
    end
  end

  // 8. Apply Final Sign
  assign o_z = sign_z ? -result_mag : result_mag;

endmodule