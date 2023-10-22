module start_change_broadcast 
import beehive_vr_pkg::*;
(
     input clk
    ,input rst

    ,input  logic   [CONFIG_NODE_CNT_W-1:0] cluster_size
    ,input  logic   [INT_W-1:0]             my_index

    ,input  logic                           start_broadcast
    ,output logic                           broadcast_rdy

    ,output logic                           config_ram_rd_req
    ,output logic   [CONFIG_ADDR_W-1:0]     config_ram_rd_req_addr
    ,input  logic                           config_ram_rd_req_rdy
    
    ,output logic                           start_change_to_udp_meta_val
    ,input  logic                           to_udp_start_change_meta_rdy

    ,output logic                           start_change_to_udp_data_val
    ,output logic                           start_change_to_udp_data_last
    ,input  logic                           to_udp_start_change_data_rdy

    ,output logic                           store_config_ram_rd
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        RD_CONFIG = 3'd1,
        STORE_CONFIG = 3'd2,
        SEND_META = 3'd3,
        SEND_DATA = 3'd4,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    logic   reset_index;
    logic   incr_index;

    logic   [CONFIG_ADDR_W-1:0] index_reg;
    logic   [CONFIG_ADDR_W-1:0] index_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            index_reg <= index_next;
        end
    end

    assign start_change_to_udp_data_last = 1'b1;

    assign config_ram_rd_req_addr = index_reg;

    assign index_next = reset_index
                        ? '0
                        : incr_index
                            ? index_reg + 1'b1
                            : index_reg;

    assign broadcast_rdy = state_reg == READY;

    always_comb begin
        reset_index = 1'b0;
        incr_index = 1'b0;

        config_ram_rd_req = 1'b0;
        store_config_ram_rd = 1'b0;

        start_change_to_udp_meta_val = 1'b0;
        start_change_to_udp_data_val = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                reset_index = 1'b1;
                if (start_broadcast) begin
                    state_next = RD_CONFIG;
                end
            end
            RD_CONFIG: begin
                // don't send to ourselves
                if (index_reg == my_index) begin
                    incr_index = 1'b1;
                end
                else begin
                    config_ram_rd_req = 1'b1;
                    state_next = STORE_CONFIG;
                end
            end
            STORE_CONFIG: begin
                store_config_ram_rd = 1'b1;
                state_next = SEND_META;
            end
            SEND_META: begin
                start_change_to_udp_meta_val = 1'b1;
                if (to_udp_start_change_meta_rdy) begin
                    state_next = SEND_DATA;
                end
            end
            SEND_DATA: begin
                start_change_to_udp_data_val = 1'b1;
                if (to_udp_start_change_data_rdy) begin
                    incr_index = 1'b1;
                    if (index_reg == (cluster_size-1)) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = RD_CONFIG;
                    end
                end
            end
            default: begin
                reset_index = 'X;
                incr_index = 'X;

                config_ram_rd_req = 'X;
                store_config_ram_rd = 'X;

                start_change_to_udp_meta_val = 'X;
                start_change_to_udp_data_val = 'X;

                state_next = UND;
            end
        endcase
    end
endmodule
