module prepare_eng_log_ctrl (
     input clk
    ,input rst

    ,input  logic   start_req_ingest
    ,output logic   log_write_done
    
    // realign bus out
    ,input  logic                           realign_log_ctrl_rd_val
    ,input  logic                           realign_log_ctrl_rd_last
    ,output logic                           log_ctrl_realign_rd_rdy
    
    // log entry bus out
    ,output logic                           prep_log_hdr_mem_wr_val
    ,input  logic                           log_hdr_mem_prep_wr_rdy
    
    ,output logic                           prep_log_data_mem_wr_val
    ,input  logic                           log_data_mem_prep_wr_rdy

    ,output logic                           log_ctrl_datap_incr_wr_addr
    ,input  logic                           datap_ctrl_log_has_space
);

    typedef enum logic[1:0] {
        READY = 2'd0,
        WRITING = 2'd1,
        DRAIN = 2'd2,
        UND = 'X
    } data_state_e;

    typedef enum logic {
        WAITING = 1'b0,
        WR_HDR = 1'b1,
        UNDEF = 'X
    } hdr_state_e;

    data_state_e    data_state_reg;
    data_state_e    data_state_next;

    hdr_state_e     hdr_state_reg;
    hdr_state_e     hdr_state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            data_state_reg <= READY;
            hdr_state_reg <= WAITING;
        end
        else begin
            data_state_reg <= data_state_next;
            hdr_state_reg <= hdr_state_next;
        end
    end

    always_comb begin
        prep_log_hdr_mem_wr_val = 1'b0;

        hdr_state_next = hdr_state_reg;
        case (hdr_state_reg)
            WAITING: begin
                if (start_req_ingest) begin
                    hdr_state_next = WR_HDR;
                end
            end
            WR_HDR: begin
                if (datap_ctrl_log_has_space) begin
                    prep_log_hdr_mem_wr_val = 1'b1;
                    if (log_hdr_mem_prep_wr_rdy) begin
                        hdr_state_next = WAITING;
                    end
                end
                else begin
                    hdr_state_next = WAITING;
                end
            end
            default: begin
                prep_log_hdr_mem_wr_val = 'X;

                hdr_state_next = UNDEF;
            end
        endcase
    end

    always_comb begin
        log_write_done = 1'b0;
        prep_log_data_mem_wr_val = 1'b0;
        log_ctrl_realign_rd_rdy = 1'b0;

        log_ctrl_datap_incr_wr_addr = 1'b0;

        data_state_next = data_state_reg;
        case (data_state_reg)
            READY: begin
                log_write_done = 1'b1;
                if (start_req_ingest) begin
                    if (datap_ctrl_log_has_space) begin
                        data_state_next = WRITING;
                    end
                    else begin
                        data_state_next = DRAIN;
                    end
                end
            end
            WRITING: begin
                if (datap_ctrl_log_has_space) begin
                    prep_log_data_mem_wr_val = realign_log_ctrl_rd_val;
                    log_ctrl_realign_rd_rdy = log_data_mem_prep_wr_rdy;

                    if (realign_log_ctrl_rd_val & log_data_mem_prep_wr_rdy) begin
                        log_ctrl_datap_incr_wr_addr = 1'b1;
                        if (realign_log_ctrl_rd_last) begin
                            data_state_next = READY;
                        end
                    end
                end
                else begin
                    log_ctrl_realign_rd_rdy = 1'b1;
                    if (realign_log_ctrl_rd_val & realign_log_ctrl_rd_last) begin
                        data_state_next = READY;
                    end
                end
            end
            DRAIN: begin
                log_ctrl_realign_rd_rdy = 1'b1;
                if (realign_log_ctrl_rd_val & realign_log_ctrl_rd_last) begin
                    data_state_next = READY;
                end
            end
            default: begin
                log_write_done = 'X;
                prep_log_data_mem_wr_val = 'X;
                log_ctrl_realign_rd_rdy = 'X;
        
                data_state_next = UND;
            end
        endcase
    end

endmodule
