// NMED (Normalized Mean Error Distance) Testbench
// Calculates NMED for 8-bit multiplier on all possible inputs

`timescale 1ns/1ps

module tb_nmed;

    // Test signals
    logic [7:0] a, b;
    logic [15:0] exact_result, approx_result;

    // Error accumulation
    real total_error;
    real max_product;
    real nmed;
    integer total_tests;
    integer non_zero_tests;

    // Instantiate exact multiplier
    assign exact_result = a * b;

    // Instantiate approximate multiplier under test
    // Change this to test different designs:
    // dr_alm_8bit, enhanced_dr_alm_8bit, hybrid_alm_8bit, iterative_alm_8bit

    `ifdef TEST_ENHANCED
        enhanced_dr_alm_8bit #(.TRUNC_WIDTH(5)) uut (
            .i_a(a), .i_b(b), .o_z(approx_result)
        );
        initial $display("Testing: Enhanced DR-ALM");
    `elsif TEST_HYBRID
        hybrid_alm_8bit #(.TRUNC_WIDTH(6), .THRESHOLD(8)) uut (
            .i_a(a), .i_b(b), .o_z(approx_result)
        );
        initial $display("Testing: Hybrid ALM");
    `elsif TEST_ITERATIVE
        iterative_alm_8bit #(.TRUNC_WIDTH(5)) uut (
            .i_a(a), .i_b(b), .o_z(approx_result)
        );
        initial $display("Testing: Iterative ALM");
    `else
        dr_alm_8bit #(.TRUNC_WIDTH(3)) uut (
            .i_a(a), .i_b(b), .o_z(approx_result)
        );
        initial $display("Testing: DR-ALM Baseline");
        // dr_alm_core #(.TRUNC_WIDTH(3), .DWIDTH(8)) uut (
        //     .i_a(a), .i_b(b), .o_z(approx_result)
        // );
        // initial $display("Testing: DR-ALM Baseline");
    `endif

    // Calculate absolute error
    function automatic real abs_error(input logic [15:0] exact, input logic [15:0] approx);
        if (exact >= approx)
            return real'(exact - approx);
        else
            return real'(approx - exact);
    endfunction

    initial begin
        total_error = 0.0;
        max_product = 255.0 * 255.0;  // 65025 for 8-bit
        total_tests = 0;
        non_zero_tests = 0;

        $display("========================================");
        $display("NMED Calculation for 8-bit Multiplier");
        $display("========================================");

        // Test all possible 8-bit input combinations
        for (int i = 0; i < 256; i++) begin
            for (int j = 0; j < 256; j++) begin
                a = i[7:0];
                b = j[7:0];
                #1;  // Allow combinational logic to settle

                // Calculate error
                total_error = total_error + abs_error(exact_result, approx_result);
                total_tests = total_tests + 1;

                if (exact_result != 0)
                    non_zero_tests = non_zero_tests + 1;
            end

            // Progress indicator
            if (i % 32 == 0)
                $display("Progress: %0d/256 rows completed", i);
        end

        // Calculate NMED
        // NMED = (Sum of |ED|) / (Total tests * Max product)
        nmed = total_error / (real'(total_tests) * max_product);

        $display("========================================");
        $display("Results:");
        $display("  Total tests: %0d", total_tests);
        $display("  Total error: %0f", total_error);
        $display("  Max product: %0f", max_product);
        $display("  NMED: %0.6f", nmed);
        $display("  NMED (scientific): %0e", nmed);
        $display("========================================");

        $finish;
    end

endmodule
