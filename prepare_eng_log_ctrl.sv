module prepare_log_ctrl (
     input clk
    ,input rst

    ,input  start_req_ingest
    ,output log_write_done
    
    // data bus in
    ,input  logic                           manage_prep_req_val
    ,input  logic                           manage_prep_req_last
    ,output logic                           prep_manage_req_rdy

    // write into the realigner
    ,output logic                           log_ctrl_realign_wr_val
    ,output logic                           log_ctrl_realign_wr_last
    ,input  logic                           realign_log_ctrl_wr_rdy

    // write out of the inserter
    ,input  logic                           insert_log_ctrl_rd_val
    ,input  logic                           insert_log_ctrl_rd_last
    ,output logic                           log_ctrl_insert_rd_rdy
    
    // log entry bus out
    ,output logic                           prep_log_mem_wr_val
    ,input  logic                           log_mem_prep_wr_rdy

    ,output logic                           log_ctrl_datap_incr_wr_addr
);
    
    typedef enum logic[1:0] {
        WAITING = 2'd0,
        INGESTING = 2'd1,
        UND = 'X
    } ingest_state_e;

    typedef enum logic[1:0] {
        READY = 2'd0,
        WRITING = 2'd1,
        UNDEF = 'X
    } log_state_e;
    
    ingest_state_e ingest_state_reg;
    ingest_state_e ingest_state_next;

    log_state_e log_state_reg;
    log_state_e log_state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            ingest_state_reg <= WAITING;
            log_state_reg <= READY;
        end
        else begin
            ingest_state_reg <= ingest_state_next;
            log_state_reg <= log_state_next;
        end
    end

    always_comb begin
        prep_manage_req_rdy = 1'b0;
        log_ctrl_realign_wr_val = 1'b0;

        ingest_state_next = ingest_state_reg;
        case (ingest_state_reg)
            WAITING: begin
                if (start_req_ingest) begin
                    ingest_state_next = INGESTING;
                end
            end
            INGESTING: begin
                prep_manage_req_rdy = realign_log_ctrl_wr_rdy;
                log_ctrl_realign_wr_val = manage_prep_req_val;
                if (manage_prep_req_val & realign_log_ctrl_wr_rdy & manage_prep_req_last) begin
                    ingest_state_next = WAITING;
                end
            end
            default: begin
                prep_manage_req_rdy = 'X;
                log_ctrl_realign_wr_val = 'X;

                ingest_state_next = UNDEF;
            end
        endcase
    end

    always_comb begin
        log_write_done = 1'b0;
        
        prep_log_mem_wr_val = 1'b0;
        log_ctrl_insert_rd_rdy = 1'b0;

        log_state_next = log_state_reg;
        case (log_state_reg)
            READY: begin
                log_write_done = 1'b1;
                if (start_req_ingest) begin
                    log_state_next = WRITING;
                end
            end
            WRITING: begin
                if (datap_ctrl_log_has_space) begin
                    prep_log_mem_wr_val = insert_log_ctrl_rd_val;
                    log_ctrl_insert_rd_rdy = log_mem_prep_wr_rdy;

                    if (insert_log_ctrl_rd_val & log_mem_prep_wr_rdy) begin
                        log_ctrl_datap_incr_wr_addr = 1'b1;
                        if (insert_log_ctrl_rd_last) begin
                            log_state_next = READY;
                        end
                    end
                end
                else begin
                    log_ctrl_insert_rd_rdy = 1'b1;
                    if (insert_log_ctrl_rd_val & insert_log_ctrl_rd_last) begin
                        log_state_next = READY;
                    end
                end
            end
            default: begin
                log_write_done = 'X;
                
                prep_log_mem_wr_val = 'X;
                log_ctrl_insert_rd_rdy = 'X;

                log_state_next = UNDEF;
            end
        endcase
    end
endmodule
