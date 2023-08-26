module prepare_clean_log_ctrl (
     input clk
    ,input rst

    ,input  logic   start_log_clean
    ,output logic   log_clean_done

    ,output logic   prep_log_hdr_mem_rd_req_val
    ,input  logic   log_hdr_mem_prep_rd_req_rdy

    ,input  logic   log_hdr_mem_prep_rd_resp_val
    ,output logic   prep_log_hdr_mem_rd_resp_rdy

    ,output logic   clean_ctrl_datap_store_hdr 
);

    typedef enum logic[1:0] {
        READY = 2'd0,
        RD_HDR = 2'd1,
        HDR_RESP = 2'd2,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    always_comb begin
        prep_log_hdr_mem_rd_req_val = 1'b0;
        prep_log_hdr_mem_rd_resp_rdy = 1'b0;

        clean_ctrl_datap_store_hdr = 1'b0;

        log_clean_done = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                log_clean_done = 1'b1;
                if (start_log_clean) begin
                    state_next = RD_HDR;
                end
            end
            RD_HDR: begin
                prep_log_hdr_mem_rd_req_val = 1'b1;
                if (log_hdr_mem_prep_rd_req_rdy) begin
                    state_next = HDR_RESP;
                end
            end
            HDR_RESP: begin
                clean_ctrl_datap_store_hdr = 1'b1;
                prep_log_hdr_mem_rd_resp_rdy = 1'b1;
                if (log_hdr_mem_prep_rd_resp_val) begin
                    state_next = READY;
                end
            end
        endcase
    end
endmodule
