module do_change_ctrl (
     input  clk
    ,input  rst

    ,input  logic   send_do_change_req
    ,output logic   do_change_rdy

    ,output logic   init_do_change_state
    
    ,output logic   src_reader_req_val
    ,input  logic   reader_src_req_rdy

    ,output logic   decr_leader_calc
    ,input  logic   leader_found

    ,output logic   store_leader_info

    ,output logic   config_ram_rd_req_val

    ,input  logic                           insert_dst_data_val
    ,input  logic                           insert_dst_data_last
    ,output logic                           dst_insert_data_rdy
    
    ,output logic                           do_change_to_udp_meta_val
    ,input  logic                           to_udp_do_change_meta_rdy
    
    ,output logic                           do_change_to_udp_data_val
    ,output logic                           do_change_to_udp_data_last
    ,input  logic                           to_udp_do_change_data_rdy

    ,input  logic                           reader_dst_data_val
    ,output logic                           store_do_change_size
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        CALC_LEADER = 3'd1,
        REQ_LEADER_INFO = 3'd2,
        RESP_INFO = 3'd3,
        REQ_LOG = 3'd4,
        WAIT_LOG = 3'd7,
        UDP_INFO_OUT = 3'd5,
        LOG_OUT = 3'd6,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    assign do_change_to_udp_data_last = insert_dst_data_last;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    assign do_change_rdy = state_reg == READY;

    always_comb begin
        init_do_change_state = 1'b0;
        decr_leader_calc = 1'b0;

        config_ram_rd_req_val = 1'b0;
        store_leader_info = 1'b0;

        src_reader_req_val = 1'b0;

        do_change_to_udp_meta_val = 1'b0;
        do_change_to_udp_data_val = 1'b0;
        
        store_do_change_size = 1'b0;

        dst_insert_data_rdy = 1'b0;
        
        state_next = state_reg;
        case (state_reg)
            READY: begin
                init_do_change_state = 1'b1;

                if (send_do_change_req) begin
                    state_next = CALC_LEADER;
                end
            end
            CALC_LEADER: begin
                if (leader_found) begin
                    state_next = REQ_LOG;
                end
                else begin
                    decr_leader_calc = 1'b1;
                end
            end
            REQ_LEADER_INFO: begin
                config_ram_rd_req_val = 1'b1;
            end
            RESP_INFO: begin
                store_leader_info = 1'b1;
            end
            REQ_LOG: begin
                src_reader_req_val = 1'b1;
                if (reader_src_req_rdy) begin
                    state_next = WAIT_LOG;
                end
            end
            WAIT_LOG: begin
                if (reader_dst_data_val) begin
                    store_do_change_size = 1'b1;
                    state_next = UDP_INFO_OUT;
                end
            end
            UDP_INFO_OUT: begin
                do_change_to_udp_meta_val = 1'b1;
                if (to_udp_do_change_meta_rdy) begin
                    state_next = LOG_OUT;
                end
            end
            LOG_OUT: begin
                do_change_to_udp_data_val = insert_dst_data_val;
                dst_insert_data_rdy = to_udp_do_change_data_rdy;

                if (insert_dst_data_val & to_udp_do_change_data_rdy & insert_dst_data_last) begin
                    state_next = READY;
                end
            end
            default: begin
                init_do_change_state = 'X;
                decr_leader_calc = 'X;

                src_reader_req_val = 'X;

                do_change_to_udp_meta_val = 'X;
                do_change_to_udp_data_val = 'X;

                dst_insert_data_rdy = 'X;

                state_next = UND;
            end
        endcase
    end
endmodule
