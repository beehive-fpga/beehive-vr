module prepare_eng_ctrl (
     input  clk
    ,input  rst

    // metadata bus in
    ,input  logic                           manage_prep_msg_val
    ,output logic                           prep_manage_msg_rdy

    // data bus in
    ,input  logic                           manage_prep_req_val

    // state write
    ,output logic                           prep_vr_state_wr_req

    ,output logic                           ctrl_datap_store_info 
    ,input  logic                           datap_ctrl_prep_ok
    ,input  logic                           datap_ctrl_log_has_space

    ,output logic                           start_req_ingest
    ,input  logic                           log_write_done
    
    ,output logic                           start_log_clean
    ,input  logic                           log_clean_done
    
    // prep ok packet out               
    ,output logic                           prep_to_udp_meta_val
    ,input  logic                           to_udp_prep_meta_rdy

    ,output logic                           prep_to_udp_data_val
    ,output logic                           prep_to_udp_data_last
    ,input  logic                           to_udp_prep_data_rdy

    ,output logic                           prep_engine_rdy
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        // read state and update in the same cycle
        HANDLE_OP = 3'd1,
        SEND_PREP_OK_META = 3'd2,
        SEND_PREP_OK_DATA = 3'd3,
        WAIT_LOG_WRITE = 3'd4,
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

    assign prep_engine_rdy = state_reg == READY;

    always_comb begin
        prep_manage_msg_rdy = 1'b0;
        prep_to_udp_meta_val = 1'b0;
        prep_to_udp_data_val = 1'b0;
        prep_to_udp_data_last = 1'b0;

        prep_vr_state_wr_req = 1'b0;

        ctrl_datap_store_info = 1'b0;
        start_req_ingest = 1'b0;
        start_log_clean = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                ctrl_datap_store_info = 1'b1;
                if (manage_prep_msg_val & manage_prep_req_val) begin
                    prep_manage_msg_rdy = 1'b1;
                    start_req_ingest = 1'b1;
                    start_log_clean = 1'b1;
                    state_next = HANDLE_OP;
                end
            end
            HANDLE_OP: begin
                if (datap_ctrl_prep_ok) begin
                    state_next = SEND_PREP_OK_META;
                end
                else if (~datap_ctrl_log_has_space) begin
                    state_next = WAIT_LOG_WRITE;
                end
                else begin
                    state_next = SEND_PREP_OK_META;
                end
            end
            SEND_PREP_OK_META: begin
                prep_to_udp_meta_val = 1'b1;
                if (to_udp_prep_meta_rdy) begin
                    state_next = SEND_PREP_OK_DATA;
                end
            end
            SEND_PREP_OK_DATA: begin
                prep_to_udp_data_val = 1'b1;
                prep_to_udp_data_last = 1'b1;
                if (to_udp_prep_data_rdy) begin
                    if (log_write_done & log_clean_done) begin
                        prep_vr_state_wr_req = 1'b1;
                        state_next = READY;
                    end
                    else begin
                        state_next = WAIT_LOG_WRITE;
                    end
                end
            end
            WAIT_LOG_WRITE: begin
                if (log_write_done & log_clean_done) begin
                    prep_vr_state_wr_req = 1'b1;
                    state_next = READY;
                end
            end
            default: begin
                prep_manage_msg_rdy = 'X;
                prep_to_udp_meta_val = 'X;
                prep_to_udp_data_val = 'X;
                prep_to_udp_data_last = 'X;

                ctrl_datap_store_info = 'X;
                start_req_ingest = 'X;

                state_next = UND;
            end
        endcase
    end


endmodule
