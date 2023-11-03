module setup_eng 
import beehive_vr_pkg::*;
import beehive_udp_msg::*;
import packet_struct_pkg::*;
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

    ,output logic                           wr_config_val
    ,output logic   [CONFIG_NODE_CNT_W-1:0] wr_node_count
    ,output machine_tuple                   wr_our_tuple

    ,input  logic   [CONFIG_NODE_CNT_W-1:0] node_count

    ,output logic                           wr_machine_data_val
    ,output machine_tuple                   wr_machine_data
    ,output logic   [CONFIG_ADDR_W-1:0]     wr_machine_data_addr
    ,input  logic                           wr_machine_data_rdy

    ,output logic                           setup_eng_rdy
);

    localparam NOC_DATA_BYTES = NOC_DATA_W/8;

    typedef enum logic[2:0] {
        READY = 3'd0,
        WR_STATE = 3'd1,
        SAVE_CONFIG = 3'd2,
        WR_CONFIG = 3'd3,
        REPLY_META = 3'd4,
        REPLY_DATA = 3'd5,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    udp_info info_reg;
    udp_info info_next;
    logic   store_info;
    logic                           store_config;
    logic   [MACHINE_INFO_W-1:0]    config_line_reg;
    logic   [MACHINE_INFO_W-1:0]    config_line_next;

    config_pkt                  cluster_config;

    logic                           next_machine;
    logic   [CONFIG_NODE_CNT_W-1:0] configs_written_reg;
    logic   [CONFIG_NODE_CNT_W-1:0] configs_written_next;

    assign setup_eng_rdy = state_reg == READY;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            info_reg <= info_next;
            config_line_reg <= config_line_next;
            configs_written_reg <= configs_written_next;
        end
    end

    assign wr_machine_data_addr = configs_written_reg;
    assign wr_machine_data = config_line_reg[MACHINE_INFO_W-1 -: MACHINE_TUPLE_W];
    assign wr_node_count = cluster_config.node_cnt;
    assign wr_our_tuple = cluster_config.our_tuple;

    assign setup_vr_state_wr_data = src_setup_req[NOC_DATA_W-1 -: VR_STATE_W];
    assign info_next = store_info
                    ? src_setup_pkt_info
                    : info_reg;

    assign cluster_config = src_setup_req;

    assign config_line_next = store_config
                            ? cluster_config.machine_config
                            : next_machine
                                ? config_line_reg << (MACHINE_TUPLE_W)
                                : config_line_reg;

    assign configs_written_next = store_info
                                ? '0
                                : next_machine
                                    ? configs_written_reg + 1'b1
                                    : configs_written_reg;
                            

    always_comb begin
        store_info = 1'b0;

        setup_vr_state_wr_val = 1'b0;

        setup_src_msg_rdy = 1'b0;
        setup_src_req_rdy = 1'b0;
        setup_to_udp_meta_val = 1'b0;
        setup_to_udp_data_val = 1'b0;
        setup_to_udp_data_last = 1'b0;

        wr_config_val = 1'b0;
        wr_machine_data_val = 1'b0;
        next_machine = 1'b0;
        store_config = 1'b0;

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
                    state_next = SAVE_CONFIG;
                end
            end
            SAVE_CONFIG: begin
                wr_config_val = 1'b1;
                store_config = 1'b1;
                setup_src_req_rdy = 1'b1;

                if (src_setup_req_val) begin
                    state_next = WR_CONFIG;
                end
            end
            WR_CONFIG: begin
                wr_machine_data_val = 1'b1;
                
                if (wr_machine_data_rdy) begin
                    next_machine = 1'b1;
                    if (configs_written_reg == (node_count - 1)) begin
                        state_next = REPLY_META;
                    end
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
        setup_to_udp_meta_info.data_length = BEEHIVE_HDR_BYTES;
    end

    beehive_hdr resp_hdr_cast;
    assign resp_hdr_cast.frag_num = NONFRAG_MAGIC;
    assign resp_hdr_cast.msg_type = SetupBeehiveResp;
    assign resp_hdr_cast.msg_len = 0;

    assign setup_to_udp_data = {resp_hdr_cast, {(NOC_DATA_W-BEEHIVE_HDR_W){1'b0}}};
    assign setup_to_udp_data_padbytes = NOC_DATA_BYTES - BEEHIVE_HDR_BYTES;
endmodule
