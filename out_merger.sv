module out_merger #(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)
    import beehive_udp_msg::*;
(
     input clk
    ,input rst
    
    ,input  logic                           setup_to_udp_meta_val
    ,input  udp_info                        setup_to_udp_meta_info
    ,output logic                           to_udp_setup_meta_rdy

    ,input  logic                           setup_to_udp_data_val
    ,input  logic   [NOC_DATA_W-1:0]        setup_to_udp_data
    ,input  logic   [NOC_PADBYTES_W-1:0]    setup_to_udp_data_padbytes
    ,input  logic                           setup_to_udp_data_last
    ,output logic                           to_udp_setup_data_rdy
    
    ,input  logic                           prep_to_udp_meta_val
    ,input  udp_info                        prep_to_udp_meta_info
    ,output logic                           to_udp_prep_meta_rdy

    ,input  logic                           prep_to_udp_data_val
    ,input  logic   [NOC_DATA_W-1:0]        prep_to_udp_data
    ,input  logic   [NOC_PADBYTES_W-1:0]    prep_to_udp_data_padbytes
    ,input  logic                           prep_to_udp_data_last
    ,output logic                           to_udp_prep_data_rdy

    ,output logic                           merger_dst_meta_val
    ,output udp_info                        merger_dst_meta_info
    ,input  logic                           dst_merger_meta_rdy

    ,output logic                           merger_dst_data_val
    ,output logic   [NOC_DATA_W-1:0]        merger_dst_data
    ,output logic   [NOC_PADBYTES_W-1:0]    merger_dst_data_padbytes
    ,output logic                           merger_dst_data_last
    ,input  logic                           dst_merger_data_rdy
);

    localparam NUM_SRCS = 2;

    typedef enum logic {
        META_OUT = 1'b0,
        WAIT_DATA = 1'b1,
        UND = 'X
    } state_e;

    typedef enum logic {
        WAITING = 1'b0,
        DATA_PASS = 1'b1,
        UNDEF = 'X
    } data_state_e;

    state_e state_reg;
    state_e state_next;

    data_state_e data_state_reg;
    data_state_e data_state_next;
    
    logic   [NUM_SRCS-1:0]  grants_reg;
    logic   [NUM_SRCS-1:0]  grants_next;
    logic   [NUM_SRCS-1:0]  grants;
    logic                   grants_advance;
    logic                   store_grants;
    logic                   any_grant;

    logic   [NUM_SRCS-1:0]  src_meta_vals;
    logic   [NUM_SRCS-1:0]  src_meta_rdys;
    logic                   start_data_out;

    logic                   src_merger_meta_val;
    logic                   merger_src_meta_rdy;
    
    logic                   src_merger_data_val;
    logic                   merger_src_data_rdy;

    logic                   meta_dst_val;

    assign src_meta_vals = {setup_to_udp_meta_val, prep_to_udp_meta_val};
    assign {to_udp_setup_meta_rdy, to_udp_prep_meta_rdy} = src_meta_rdys

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY; 
            data_state_reg <= WAITING;
            grants_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            data_state_reg <= data_state_next;
            grants_reg <= grants_next;
        end
    end

    bsg_arb_round_robin #(
        .width_p    (NUM_SRCS   )
    ) arbiter (
         .clk_i     (clk    )
        ,.reset_i   (rst    )

        ,.reqs_i    (src_meta_vals  )
        ,.grants_o  (grants         )
        ,.yumi_i    (grants_advance )
    );

    always_comb begin
        store_grants = 1'b0;
        grants_advance = 1'b0;
        start_data_out = 1'b0;

        merger_src_meta_rdy = 1'b0;
        merger_dst_meta_val = 1'b0;

        state_next = state_reg;
        case (state_reg)
            META_OUT: begin
                store_grants = 1'b1;
                merger_src_meta_rdy = dst_merger_meta_rdy;
                merger_dst_meta_val = src_merger_meta_val;
                if (src_merger_meta_val & dst_merger_meta_rdy) begin
                    grants_advance = 1'b1;
                    start_data_out = 1'b1;
                    if (merger_dst_data_val & dst_merger_data_rdy & merger_dst_data_last) begin
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
                store_grants = 'X;
                grants_advance = 'X;
                start_data_out = 'X;

                merger_src_meta_rdy = 'X;
                merger_dst_meta_val = 'X;

                state_next = UND;
            end
        endcase
    end

    always_comb begin
        merger_dst_data_val = 1'b0;
        merger_src_data_rdy = 1'b0;

        data_state_next = data_state_reg;
        case (data_state_reg)
            WAITING: begin
                if (start_data_out) begin
                    merger_dst_data_val = src_merger_data_val;
                    merger_src_data_rdy = dst_merger_data_rdy;

                    if (src_merger_data_val & dst_merger_data_rdy) begin
                        if (merger_dst_data_last) begin
                            data_state_next = WAITING;
                        end
                        else begin
                            data_state_next = DATA_PASS;
                        end
                    end
                end
            end
            DATA_PASS: begin
                merger_dst_data_val = src_merger_data_val;
                merger_src_data_rdy = dst_merger_data_rdy;
                if (src_merger_data_val & dst_merger_data_rdy & merger_dst_data_last) begin
                    data_state_next = WAITING;
                end
            end
            default: begin
                merger_dst_data_val = 'X;
                merger_src_data_rdy = 'X;

                data_state_next = UNDEF;
            end
        endcase
    end

    
    bsg_mux_one_hot #(
         .width_p   (1  )
        ,.els_p     (NUM_SRCS   )
    ) meta_val_mux (
         .data_i        (src_meta_vals          )
        ,.sel_one_hot_i (grants_next            )
        ,.data_o        (src_merger_meta_val    )
    );
    
    demux_one_hot #(
         .NUM_OUTPUTS   (NUM_SRCS   )
        ,.INPUT_WIDTH   (1          )
    ) meta_rdy_demux (
         .input_sel     (grants_next            )
        ,.data_input    (merger_src_meta_rdy    )
        ,.data_outputs  (src_meta_rdys          )
    );
    
    bsg_mux_one_hot #(
         .width_p   (1  )
        ,.els_p     (NUM_SRCS   )
    ) data_val_mux (
         .data_i        ({setup_to_udp_data_val, prep_to_udp_data_val})
        ,.sel_one_hot_i (grants_next            )
        ,.data_o        (src_merger_meta_val    )
    );
    
    demux_one_hot #(
         .NUM_OUTPUTS   (NUM_SRCS   )
        ,.INPUT_WIDTH   (1          )
    ) data_rdy_demux (
         .input_sel     (grants_next            )
        ,.data_input    (merger_src_data_rdy    )
        ,.data_outputs  ({to_udp_setup_data_rdy, to_udp_prep_data_rdy})
    );
    
    bsg_mux_one_hot #(
         .width_p   (1  )
        ,.els_p     (NUM_SRCS   )
    ) data_last_mux (
         .data_i        ({setup_to_udp_data_last, prep_to_udp_data_last})
        ,.sel_one_hot_i (grants_next            )
        ,.data_o        (merger_dst_data_last   )
    );
    
    bsg_mux_one_hot #(
         .width_p   (NOC_PADBYTES_W )
        ,.els_p     (NUM_SRCS       )
    ) data_last_mux (
         .data_i        ({setup_to_udp_data_padbytes, prep_to_udp_data_padbytes})
        ,.sel_one_hot_i (grants_next                )
        ,.data_o        (merger_dst_data_padbytes   )
    );
    
    bsg_mux_one_hot #(
         .width_p   (NOC_DATA_W )
        ,.els_p     (NUM_SRCS   )
    ) data_mux (
         .data_i        ({setup_to_udp_data, prep_to_udp_data})
        ,.sel_one_hot_i (grants_next        )
        ,.data_o        (merger_dst_data    )
    );
endmodule
