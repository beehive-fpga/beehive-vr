module manage_eng 
import beehive_udp_msg::*;
import beehive_vr_pkg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst
    
    ,input  logic                           fr_udp_manage_meta_val
    ,input  udp_info                        fr_udp_manage_meta_info
    ,output logic                           manage_fr_udp_meta_rdy

    ,input  logic                           fr_udp_manage_data_val
    ,input  logic   [NOC_DATA_W-1:0]        fr_udp_manage_data
    ,input  logic                           fr_udp_manage_data_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    fr_udp_manage_data_padbytes
    ,output logic                           manage_fr_udp_data_rdy
    
    ,output logic                           manage_setup_msg_val
    ,output udp_info                        manage_setup_pkt_info
    ,input  logic                           setup_manage_msg_rdy

    ,output logic                           manage_setup_req_val
    ,output logic   [NOC_DATA_W-1:0]        manage_setup_req
    ,output logic                           manage_setup_req_last
    ,output logic   [NOC_PADBYTES_W-1:0]    manage_setup_req_padbytes
    ,input  logic                           setup_manage_req_rdy

    ,output logic                           manage_prep_msg_val
    ,output udp_info                        manage_prep_pkt_info
    ,input  logic                           prep_manage_msg_rdy

    ,output logic                           manage_prep_req_val
    ,output msg_type_e                      manage_prep_msg_type
    ,output logic   [NOC_DATA_W-1:0]        manage_prep_req
    ,output logic                           manage_prep_req_last
    ,output logic   [NOC_PADBYTES_W-1:0]    manage_prep_req_padbytes
    ,input  logic                           prep_manage_req_rdy
    
    ,output logic                           manage_commit_msg_val
    ,output udp_info                        manage_commit_pkt_info
    ,input  logic                           commit_manage_msg_rdy

    ,output logic                           manage_commit_req_val
    ,output logic   [NOC_DATA_W-1:0]        manage_commit_req
    ,output logic                           manage_commit_req_last
    ,output logic   [NOC_PADBYTES_W-1:0]    manage_commit_req_padbytes
    ,input  logic                           commit_manage_req_rdy
    
    ,output logic                           manage_vc_msg_val
    ,output udp_info                        manage_vc_pkt_info
    ,input  logic                           vc_manage_msg_rdy

    ,output logic                           manage_vc_req_val
    ,output msg_type_e                      manage_vc_msg_type
    ,output logic   [NOC_DATA_W-1:0]        manage_vc_req
    ,output logic                           manage_vc_req_last
    ,output logic   [NOC_PADBYTES_W-1:0]    manage_vc_req_padbytes
    ,input  logic                           vc_manage_req_rdy

    ,input                                  all_eng_rdy
);
    localparam FIFO_ELS = 4;
    localparam FIFO_ELS_W = $clog2(FIFO_ELS);

    typedef enum logic[2:0] {
        PREPARE = 3'd0,
        COMMIT = 3'd1,
        VIEW_CHANGE = 3'd2,
        SETUP = 3'd3,
        NONE = 3'd4
    } dst_sel_e;

    typedef enum logic[1:0] {
        READY = 2'd0,
        GRAB_MSG_HDR = 2'd1,
        DATA_PASS = 2'd2,
        WAIT_ENG = 2'd3,
        UND = 'X
    } state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        META_OUT = 2'd1,
        UNDEF = 'X
    } meta_state_e;

    beehive_hdr msg_hdr_reg;
    beehive_hdr msg_hdr_next;
    beehive_hdr msg_hdr;
    logic       store_msg_hdr;

    udp_info    udp_info_reg;
    udp_info    udp_info_next;
    logic       store_udp_info;

    state_e     state_reg;
    state_e     state_next;

    meta_state_e    meta_state_reg;
    meta_state_e    meta_state_next;

    logic           meta_out;

    dst_sel_e   dst_sel;
    
    logic                           manage_dst_msg_val;
    udp_info                        manage_dst_pkt_info;
    logic                           dst_manage_msg_rdy;

    logic                           manage_dst_req_val;
    logic   [NOC_DATA_W-1:0]        manage_dst_req;
    logic                           manage_dst_req_last;
    logic   [NOC_PADBYTES_W-1:0]    manage_dst_req_padbytes;
    logic                           dst_manage_req_rdy;
    
    logic                           manage_ctrl_req_val;
    logic                           ctrl_manage_req_rdy;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
            meta_state_reg <= WAITING;
        end
        else begin
            state_reg <= state_next;
            meta_state_reg <= meta_state_next;
            udp_info_reg <= udp_info_next;
            msg_hdr_reg <= msg_hdr_next;
        end
    end

    assign udp_info_next = store_udp_info
                        ? fr_udp_manage_meta_info
                        : udp_info_reg;

    assign msg_hdr_next = store_msg_hdr
                        ? msg_hdr
                        : msg_hdr_reg;

    always_comb begin
        manage_dst_pkt_info = udp_info_reg;
        manage_dst_pkt_info.data_length = udp_info_reg.data_length - BEEHIVE_HDR_BYTES;
    end

    assign manage_vc_msg_type = msg_hdr_next.msg_type;
    assign manage_prep_msg_type = msg_hdr_next.msg_type;
    
    assign manage_setup_pkt_info = manage_dst_pkt_info;
    assign manage_setup_req = manage_dst_req;
    assign manage_setup_req_padbytes = manage_dst_req_padbytes;
    assign manage_setup_req_last = manage_dst_req_last;

    assign manage_prep_pkt_info = manage_dst_pkt_info;
    assign manage_prep_req = manage_dst_req;
    assign manage_prep_req_padbytes = manage_dst_req_padbytes;
    assign manage_prep_req_last = manage_dst_req_last;
    
    assign manage_commit_pkt_info = manage_dst_pkt_info;
    assign manage_commit_req = manage_dst_req;
    assign manage_commit_req_padbytes = manage_dst_req_padbytes;
    assign manage_commit_req_last = manage_dst_req_last;
    
    assign manage_vc_pkt_info = manage_dst_pkt_info;
    assign manage_vc_req = manage_dst_req;
    assign manage_vc_req_padbytes = manage_dst_req_padbytes;
    assign manage_vc_req_last = manage_dst_req_last;

    realign_compile #(
         .REALIGN_W     (BEEHIVE_HDR_W  )
        ,.DATA_W        (NOC_DATA_W     )
        ,.BUF_STAGES    (4) 
    ) beehive_msg_hdr (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_realign_data_val      (fr_udp_manage_data_val     )
        ,.src_realign_data          (fr_udp_manage_data         )
        ,.src_realign_data_padbytes (fr_udp_manage_data_padbytes)
        ,.src_realign_data_last     (fr_udp_manage_data_last    )
        ,.realign_src_data_rdy      (manage_fr_udp_data_rdy     )
    
        ,.realign_dst_data_val      (manage_ctrl_req_val        )
        ,.realign_dst_data          (manage_dst_req             )
        ,.realign_dst_data_padbytes (manage_dst_req_padbytes    )
        ,.realign_dst_data_last     (manage_dst_req_last        )
        ,.dst_realign_data_rdy      (ctrl_manage_req_rdy        )
    
        ,.realign_dst_removed_data  (msg_hdr                    )
    );

    assign dst_sel = (msg_hdr_next.msg_type == Prepare) || (msg_hdr_next.msg_type == ValidateReadRequest)
                    ? PREPARE
                    : msg_hdr_next.msg_type == Commit
                        ? COMMIT
                        : (msg_hdr_next.msg_type == StartViewChange) || (msg_hdr_next.msg_type == StartView)
                            ? VIEW_CHANGE
                            : msg_hdr_next.msg_type == SetupBeehive
                                ? SETUP
                                : NONE;

    logic   dump_msg_val;
    logic   dump_req_val;

    demux #(
         .NUM_OUTPUTS   (5  )
        ,.INPUT_WIDTH   (1  )
    ) meta_val_demux (
         .input_sel     (dst_sel            )
        ,.data_input    (manage_dst_msg_val )
        ,.data_outputs  ({dump_msg_val, manage_setup_msg_val, manage_vc_msg_val, manage_commit_msg_val, manage_prep_msg_val})
    );
    
    demux #(
         .NUM_OUTPUTS   (5  )
        ,.INPUT_WIDTH   (1  )
    ) data_val_demux (
         .input_sel     (dst_sel            )
        ,.data_input    (manage_dst_req_val )
        ,.data_outputs  ({dump_req_val, manage_setup_req_val, manage_vc_req_val, manage_commit_req_val, manage_prep_req_val})
    );

    bsg_mux #(
         .width_p   (1)
        ,.els_p     (5)
    ) meta_rdy_mux (
         .data_i    ({1'b1, setup_manage_msg_rdy, vc_manage_msg_rdy, commit_manage_msg_rdy, prep_manage_msg_rdy})
        ,.sel_i     (dst_sel)
        ,.data_o    (dst_manage_msg_rdy)
    );
    
    bsg_mux #(
         .width_p   (1)
        ,.els_p     (5)
    ) data_rdy_mux (
         .data_i    ({1'b1, setup_manage_req_rdy, vc_manage_req_rdy, commit_manage_req_rdy, prep_manage_req_rdy})
        ,.sel_i     (dst_sel)
        ,.data_o    (dst_manage_req_rdy)
    );
   
    always_comb begin
        store_msg_hdr = 1'b0;
        store_udp_info = 1'b0;
        meta_out = 1'b0;

        manage_fr_udp_meta_rdy = 1'b0;
        manage_dst_req_val = 1'b0;
        ctrl_manage_req_rdy = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                store_udp_info = 1'b1;
                manage_fr_udp_meta_rdy = 1'b1;
                if (fr_udp_manage_meta_val) begin
                    meta_out = 1'b1;
                    state_next = GRAB_MSG_HDR;
                end
            end
            GRAB_MSG_HDR: begin
                store_msg_hdr = 1'b1;
                manage_dst_req_val = manage_ctrl_req_val;
                ctrl_manage_req_rdy = dst_manage_req_rdy;
                if (manage_ctrl_req_val & dst_manage_req_rdy) begin
                    if (manage_dst_req_last) begin
                        state_next = WAIT_ENG;
                    end
                    else begin
                        state_next = DATA_PASS;
                    end
                end
            end
            DATA_PASS: begin
                manage_dst_req_val = manage_ctrl_req_val;
                ctrl_manage_req_rdy = dst_manage_req_rdy;
                if (manage_dst_req_val & dst_manage_req_rdy & manage_dst_req_last) begin
                    state_next = WAIT_ENG;
                end
            end
            WAIT_ENG: begin
                if (all_eng_rdy && (meta_state_reg == WAITING)) begin
                    state_next = READY;
                end
            end
            default: begin
                store_msg_hdr = 'X;
                store_udp_info = 'X;
                meta_out = 'X;

                manage_fr_udp_meta_rdy = 'X;

                state_next = UND;
            end
        endcase
    end

    always_comb begin
        manage_dst_msg_val = 1'b0;

        meta_state_next = meta_state_reg;
        case (meta_state_reg) 
            WAITING: begin
                if (meta_out) begin
                    meta_state_next = META_OUT;
                end
            end
            META_OUT: begin
                manage_dst_msg_val = 1'b1;

                if (dst_manage_msg_rdy) begin
                    meta_state_next = WAITING;
                end
            end
            default: begin
                manage_dst_msg_val = 'X;

                meta_state_next = UNDEF;
            end
        endcase
    end

endmodule
