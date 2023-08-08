`include "packet_defs.vh"
module req_splitter 
import beehive_udp_msg::*;
import beehive_topology::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst

    ,input  logic                           fr_udp_beehive_vr_meta_val
    ,input  udp_info                        fr_udp_beehive_vr_meta_info
    ,output logic                           beehive_vr_fr_udp_meta_rdy

    ,input  logic                           fr_udp_beehive_vr_data_val
    ,input  logic   [NOC_DATA_W-1:0]        fr_udp_beehive_vr_data
    ,input  logic                           fr_udp_beehive_vr_data_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    fr_udp_beehive_vr_data_padbytes
    ,output logic                           beehive_vr_fr_udp_data_rdy

    ,output logic                           splitter_setup_meta_val
    ,output udp_info                        splitter_setup_meta_info
    ,input                                  setup_splitter_meta_rdy

    ,output logic                           splitter_setup_data_val
    ,output logic   [NOC_DATA_W-1:0]        splitter_setup_data
    ,output logic                           splitter_setup_data_last
    ,output logic   [NOC_PADBYTES_W-1:0]    splitter_setup_data_padbytes
    ,input  logic                           setup_splitter_data_rdy
    
    ,output logic                           splitter_manage_meta_val
    ,output udp_info                        splitter_manage_meta_info
    ,input                                  manage_splitter_meta_rdy

    ,output logic                           splitter_manage_data_val
    ,output logic   [NOC_DATA_W-1:0]        splitter_manage_data
    ,output logic                           splitter_manage_data_last
    ,output logic   [NOC_PADBYTES_W-1:0]    splitter_manage_data_padbytes
    ,input  logic                           manage_splitter_data_rdy
);

    typedef enum logic[1:0] {
        META_OUT = 2'd0,
        WAIT_DATA = 2'd1,
        UND = 'X
    } state_e;

    typedef enum logic[1:0] {
        WAITING = 2'd0,
        DATA_PASS = 2'd1,
        UNDEF = 'X
    } data_state_e;

    state_e state_reg;
    state_e state_next;

    data_state_e data_state_reg;
    data_state_e data_state_next;
    logic   start_data_out;

    logic   splitter_dst_meta_val;
    logic   dst_splitter_meta_rdy;

    logic   splitter_dst_data_val;
    logic   dst_splitter_data_rdy;

    logic   [`PORT_NUM_W-1:0]   dst_port_reg;
    logic   [`PORT_NUM_W-1:0]   dst_port_next;
    logic   store_dst_port;
    logic   dst_sel;

    assign splitter_setup_data = fr_udp_beehive_vr_data;
    assign splitter_setup_data_last = fr_udp_beehive_vr_data_last;
    assign splitter_setup_data_padbytes = fr_udp_beehive_vr_data_padbytes;
    
    assign splitter_manage_data = fr_udp_beehive_vr_data;
    assign splitter_manage_data_last = fr_udp_beehive_vr_data_last;
    assign splitter_manage_data_padbytes = fr_udp_beehive_vr_data_padbytes;

    assign dst_sel = dst_port_next == SETUP_PORT
                    ? '0
                    : 1'b1;

    demux #(
         .NUM_OUTPUTS       (2)
        ,.INPUT_WIDTH       (1)
    ) meta_val_demux (
         .input_sel   (dst_sel  )
        ,.data_input  (splitter_dst_meta_val    )
        ,.data_outputs({splitter_manage_meta_val, splitter_setup_meta_val})
    );
    
    demux #(
         .NUM_OUTPUTS       (2)
        ,.INPUT_WIDTH       (1)
    ) data_val_demux (
         .input_sel   (dst_sel  )
        ,.data_input  (splitter_dst_data_val    )
        ,.data_outputs({splitter_manage_data_val, splitter_setup_data_val})
    );

    bsg_mux #(
         .width_p   (1)
        ,.els_p     (2)
    ) meta_rdy_mux (
         .data_i    ({manage_splitter_meta_rdy, setup_splitter_meta_rdy})
        ,.sel_i     (dst_sel    )
        ,.data_o    (dst_splitter_meta_rdy  )
    );
    
    bsg_mux #(
         .width_p   (1)
        ,.els_p     (2)
    ) data_rdy_mux (
         .data_i    ({manage_splitter_data_rdy, setup_splitter_data_rdy})
        ,.sel_i     (dst_sel    )
        ,.data_o    (dst_splitter_data_rdy  )
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= META_OUT;
            data_state_reg <= WAITING;
        end
        else begin
            state_reg <= state_next;
            data_state_reg <= data_state_next;
            dst_port_reg <= dst_port_next;
        end
    end

    assign dst_port_next = store_dst_port
                           ? fr_udp_beehive_vr_meta_info.dst_port
                           : dst_port_reg;

    assign splitter_setup_meta_info = fr_udp_beehive_vr_meta_info;
    assign splitter_manage_meta_info = fr_udp_beehive_vr_meta_info;

    always_comb begin
        splitter_dst_meta_val = 1'b0;
        beehive_vr_fr_udp_meta_rdy = 1'b0;

        start_data_out = 1'b0;
        store_dst_port = 1'b0;

        state_next = state_reg;
        case (state_reg)
            META_OUT: begin
                store_dst_port = 1'b1;
                splitter_dst_meta_val = fr_udp_beehive_vr_meta_val;
                beehive_vr_fr_udp_meta_rdy = dst_splitter_meta_rdy;

                if (fr_udp_beehive_vr_meta_val & dst_splitter_meta_rdy) begin
                    start_data_out = 1'b1;
                    if (fr_udp_beehive_vr_data_val & dst_splitter_data_rdy & fr_udp_beehive_vr_data_last) begin
                        state_next = META_OUT;
                    end
                    else begin
                        state_next = WAIT_DATA;
                    end
                end
            end
            WAIT_DATA: begin
                if (data_state_next == WAITING) begin
                    state_next = META_OUT;
                end
            end
            default: begin
                splitter_dst_meta_val = 'X;
                beehive_vr_fr_udp_meta_rdy = 'X;

                start_data_out = 'X;
                store_dst_port = 'X;

                state_next = UND;
            end
        endcase
    end

    always_comb begin
        splitter_dst_data_val = 1'b0;
        beehive_vr_fr_udp_data_rdy = 1'b0;

        data_state_next = data_state_reg;
        case (data_state_reg)
            WAITING: begin
                if (start_data_out) begin
                    splitter_dst_data_val = fr_udp_beehive_vr_data_val;
                    beehive_vr_fr_udp_data_rdy = dst_splitter_data_rdy;
                    if (fr_udp_beehive_vr_data_val & dst_splitter_data_rdy & fr_udp_beehive_vr_data_last) begin
                        data_state_next = WAITING;
                    end
                    else begin
                        data_state_next = DATA_PASS;
                    end
                end
            end
            DATA_PASS: begin
                splitter_dst_data_val = fr_udp_beehive_vr_data_val;
                beehive_vr_fr_udp_data_rdy = dst_splitter_data_rdy;
                if (fr_udp_beehive_vr_data_val & dst_splitter_data_rdy & fr_udp_beehive_vr_data_last) begin
                    data_state_next = WAITING;
                end
            end
            default: begin
                splitter_dst_data_val = 'X;
                beehive_vr_fr_udp_data_rdy = 'X;

                data_state_next = UNDEF;
            end
        endcase
    end

endmodule
