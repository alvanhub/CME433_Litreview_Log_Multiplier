// 4-bit Leading One Detector (LOD)
// This is a basic building block for the larger hierarchical LOD.
module lod4_bit (
    input  logic [3:0] a,
    output logic [3:0] d,
    output logic       or_out
);
    // OR reduction checks if any bit is '1'
    assign or_out = |a;

    // Logic to find the position of the most significant '1'
    assign d[3] = a[3];
    assign d[2] = ~a[3] & a[2];
    assign d[1] = ~a[3] & ~a[2] & a[1];
    assign d[0] = ~a[3] & ~a[2] & ~a[1] & a[0];
endmodule