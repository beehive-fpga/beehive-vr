module commit_eng_ctrl (
     input clk
    ,input rst
    
    ,input  logic                           manage_commit_msg_val
    ,output logic                           commit_manage_msg_rdy
    
    // data bus in
    ,input  logic                           manage_commit_req_val
    ,input  logic                           manage_commit_req_last
    ,output logic                           commit_manage_req_rdy
    
    // state write
    ,output logic                           commit_vr_state_wr_req
    ,input  logic                           vr_state_commit_wr_rdy
    
    // log entry rd bus
    ,output logic                           commit_log_mem_rd_req_val
    ,input  logic                           log_mem_commit_rd_req_rdy

    ,input  logic                           log_mem_commit_rd_resp_val
    ,output logic                           commit_log_mem_rd_resp_rdy
    
    // log entry bus out
    ,output logic                           commit_log_mem_wr_val
    ,input  logic                           log_mem_commit_wr_rdy

    ,output logic                           ctrl_datap_store_msg
    ,output logic                           ctrl_datap_store_state
    ,output logic                           ctrl_datap_store_log_entry
    ,output logic                           ctrl_datap_calc_next_entry
    
    ,input  logic                           datap_ctrl_commit_ok
    ,input  logic                           datap_ctrl_last_commit

    ,output logic                           commit_eng_rdy
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        RD_LOG_ENTRY_HDR = 3'd3,
        LOG_ENTRY_RESP = 3'd4,
        UPDATE_LOG_ENTRY = 3'd5,
        UPDATE_STATE = 3'd6,
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

    assign commit_eng_rdy = state_reg == READY;

    always_comb begin
        commit_manage_msg_rdy = 1'b0;
        commit_manage_req_rdy = 1'b0;

        commit_log_mem_rd_req_val = 1'b0;
        commit_log_mem_rd_resp_rdy = 1'b0;

        ctrl_datap_store_msg = 1'b0;
        ctrl_datap_store_state = 1'b0;
        ctrl_datap_store_log_entry = 1'b0;
        ctrl_datap_calc_next_entry = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                ctrl_datap_store_msg = 1'b1;
                ctrl_datap_store_state = 1'b1;
                if (manage_commit_msg_val & manage_commit_req_val) begin
                    commit_manage_msg_rdy = 1'b1;
                    commit_manage_req_rdy = 1'b1;
                    commit_log_mem_rd_req_val = 1'b1;
                    if (~log_mem_commit_rd_req_rdy) begin
                        state_next = RD_LOG_ENTRY_HDR;
                    end
                    else begin
                        state_next = LOG_ENTRY_RESP;
                    end
                end
            end
            RD_LOG_ENTRY_HDR: begin
                commit_log_mem_rd_req_val = 1'b1;
                if (log_mem_commit_rd_req_rdy) begin
                    state_next = LOG_ENTRY_RESP;
                end
            end
            LOG_ENTRY_RESP: begin
                commit_log_mem_rd_resp_rdy = 1'b1;
                ctrl_datap_store_log_entry = 1'b1;
                if (log_mem_commit_rd_resp_val) begin
                    state_next = UPDATE_LOG_ENTRY;
                end
            end
            UPDATE_LOG_ENTRY: begin
                if (~datap_ctrl_commit_ok) begin
                    state_next = READY;
                end
                else begin
                    commit_log_mem_wr_val = 1'b1;
                    if (log_mem_commit_wr_rdy) begin
                        ctrl_datap_calc_next_entry = 1'b1;
                        if (datap_ctrl_last_commit) begin
                            state_next = UPDATE_STATE;
                        end
                        else begin
                            state_next = RD_LOG_ENTRY_HDR;
                        end
                    end
                end
            end
            UPDATE_STATE: begin
                commit_vr_state_wr_req = 1'b1;
                if (vr_state_commit_wr_rdy) begin
                    state_next = READY;
                end
            end
        endcase
    end

endmodule
