module setup_eng 
import beehive_vr_pkg::*;
import beehive_udp_msg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst

    ,input  logic                           src_setup_msg_val
    ,input  udp_info                        src_setup_pkt_info
    ,output logic                           setup_src_msg_rdy

    ,input  logic                           src_setup_req_val
    ,input  logic   [NOC_DATA_W-1:0]        src_setup_req
    ,input  logic                           src_setup_req_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    src_setup_req_padbytes
    ,output logic                           setup_src_req_rdy

    ,output logic                           setup_vr_state_wr_val
    ,output vr_state                        setup_vr_state_wr_data

    ,output logic                           setup_to_udp_meta_val
    ,output udp_info                        setup_to_udp_meta_info
    ,input  logic                           to_udp_setup_meta_rdy

    ,output logic                           setup_to_udp_data_val
    ,output logic   [NOC_DATA_W-1:0]        setup_to_udp_data
    ,output logic   [NOC_PADBYTES_W-1:0]    setup_to_udp_data_padbytes
    ,output logic                           setup_to_udp_data_last
    ,input  logic                           to_udp_setup_data_rdy

    ,output logic                           setup_eng_rdy
);

    localparam NOC_DATA_BYTES = NOC_DATA_W/8;

    typedef enum logic[1:0] {
        READY = 2'd0,
        WR_STATE = 2'd1,
        REPLY_META = 2'd2,
        REPLY_DATA = 2'd3,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    udp_info info_reg;
    udp_info info_next;
    logic   store_info;

    assign setup_eng_rdy = state_reg == READY;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            info_reg <= info_next;
        end
    end

    assign setup_vr_state_wr_data = src_setup_req[NOC_DATA_W-BEEHIVE_HDR_W-1 -: VR_STATE_W];
    assign info_next = store_info
                    ? src_setup_pkt_info
                    : info_reg;

    always_comb begin
        store_info = 1'b0;

        setup_src_msg_rdy = 1'b0;
        setup_src_req_rdy = 1'b0;
        setup_to_udp_meta_val = 1'b0;
        setup_to_udp_data_val = 1'b0;
        setup_to_udp_data_last = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                store_info = 1'b1;
                setup_src_msg_rdy = 1'b1;
                if (src_setup_msg_val) begin
                    state_next = WR_STATE;
                end
            end
            WR_STATE: begin
                setup_vr_state_wr_val = src_setup_req_val;
                setup_src_req_rdy = 1'b1;
                if (src_setup_req_val) begin
                    state_next = REPLY_META;
                end
            end
            REPLY_META: begin
                setup_to_udp_meta_val = 1'b1;
                if (to_udp_setup_meta_rdy) begin
                    state_next = REPLY_DATA;
                end
            end
            REPLY_DATA: begin
                setup_to_udp_data_val = 1'b1;
                setup_to_udp_data_last = 1'b1;
                if (to_udp_setup_data_rdy) begin
                    state_next = READY;
                end
            end
            default: begin
                store_info = 'X;

                setup_src_msg_rdy = 'X;
                setup_src_req_rdy = 'X;
                setup_to_udp_meta_val = 'X;
                setup_to_udp_data_val = 'X;
                setup_to_udp_data_last = 'X;

                state_next = UND;
            end
        endcase
    end

    always_comb begin
        setup_to_udp_meta_info = info_reg;
        setup_to_udp_meta_info.src_ip = info_reg.dst_ip;
        setup_to_udp_meta_info.dst_ip = info_reg.src_ip;
        setup_to_udp_meta_info.src_port = info_reg.dst_port;
        setup_to_udp_meta_info.dst_port = info_reg.src_port;
        setup_to_udp_meta_info.data_length = 1;
    end

    assign setup_to_udp_data = {8'd1, {(NOC_DATA_W-8){1'b0}}};
    assign setup_to_udp_data_padbytes = NOC_DATA_BYTES - 1;
endmodule
