module log_engine (
     input  clk
    ,input  rst

    ,input  logic   start_req


);
    // we need to insert the entry header on each entry
    // we also need to insert end of the last entry onto the front of the next entry
    // it needs to be dynamic width
endmodule
