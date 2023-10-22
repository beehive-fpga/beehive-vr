// we need to insert the entry header on each entry
// we also need to insert end of the last entry onto the front of the next entry
// it needs to be dynamic width
// we can use the realigners if we put the actual data we want in the first line
// in the bottom bits instead of the top
`include "packet_defs.vh"
module log_reader 
import beehive_vr_pkg::*;
#(
    parameter LOG_PADBYTES_W = $clog2(LOG_W/8)
)(
     input clk
    ,input rst

    ,input  logic                           src_reader_req_val
    ,input  logic   [LOG_HDR_DEPTH_W:0]     src_reader_addr_start
    ,input  logic   [LOG_HDR_DEPTH_W:0]     src_reader_addr_end
    ,output logic                           reader_src_req_rdy

    ,output logic                           reader_log_hdr_mem_rd_req_val
    ,output logic   [LOG_HDR_DEPTH_W-1:0]   reader_log_hdr_mem_rd_req_addr
    ,input  logic                           log_hdr_mem_reader_rd_req_rdy

    ,input  logic                           log_hdr_mem_reader_rd_resp_val
    ,input  log_entry_hdr                   log_hdr_mem_reader_rd_resp_data
    ,output logic                           reader_log_hdr_mem_rd_resp_rdy

    ,output logic                           reader_log_data_mem_rd_req_val
    ,output logic   [LOG_DEPTH_W-1:0]       reader_log_data_mem_rd_req_addr
    ,input  logic                           log_data_mem_reader_rd_req_rdy

    ,input  logic                           log_data_mem_reader_rd_resp_val
    ,input  logic   [LOG_W-1:0]             log_data_mem_reader_rd_resp_data
    ,output logic                           reader_log_data_mem_rd_resp_rdy

    ,output logic                           reader_dst_data_val
    ,output logic   [INT_W-1:0]             reader_dst_last_view
    ,output logic   [`UDP_LENGTH_W-1:0]     reader_dst_entries_len
    ,output logic   [LOG_W-1:0]             reader_dst_data
    ,output logic   [LOG_PADBYTES_W-1:0]    reader_dst_data_padbytes
    ,output logic                           reader_dst_data_last
    ,input  logic                           dst_reader_data_rdy
);
    localparam  SHIFT_WIDTH = $clog2(LOG_W);
    localparam  HDR_LINE_PADDING = LOG_W - WIRE_LOG_ENTRY_HDR_W;
    logic                           in_write_hdr_fifo_wr_val;
    logic                           in_write_hdr_wr_entry_hdr;
    logic                           write_hdr_fifo_in_rdy;

    logic                           store_req_info;
    logic                           store_log_hdr;
    logic                           store_data_line;
    logic                           incr_log_resp_size;
    logic                           reset_in_hdr_rd_addr;
    logic                           incr_in_hdr_rd_addr;
    logic                           reset_in_data_rd_addr;
    logic                           incr_in_data_rd_addr;

    logic                           output_done;
    logic                           last_hdr_in_rd;
    logic                           last_data_in_rd;

    logic   [LOG_W-1:0]             data_line_reg;
    logic   [LOG_W-1:0]             data_line_next;
    
    logic   [LOG_HDR_DEPTH_W:0] hdr_addr_start_reg;
    logic   [LOG_HDR_DEPTH_W:0] hdr_addr_end_reg;
    logic   [LOG_HDR_DEPTH_W:0] hdr_addr_start_next;
    logic   [LOG_HDR_DEPTH_W:0] hdr_addr_end_next;

    logic   [LOG_HDR_DEPTH_W:0] in_hdr_rd_addr_reg;
    logic   [LOG_HDR_DEPTH_W:0] in_hdr_rd_addr_next;
    
    logic   [LOG_HDR_DEPTH_W:0] out_entry_addr_reg;
    logic   [LOG_HDR_DEPTH_W:0] out_entry_addr_next;

    logic   [LOG_W-1:0]         out_entry_line_reg;
    logic   [LOG_W-1:0]         out_entry_line_next;

    logic   [LOG_PADBYTES_W-1:0]    out_entry_line_padbytes_reg;
    logic   [LOG_PADBYTES_W-1:0]    out_entry_line_padbytes_next;

    logic   [LOG_DEPTH_W:0]     in_data_rd_addr_reg;
    logic   [LOG_DEPTH_W:0]     in_data_rd_addr_next;
    logic   [LOG_DEPTH_W:0]     next_entry_addr_reg;
    logic   [LOG_DEPTH_W:0]     next_entry_addr_next;
    logic   [LOG_DEPTH_W:0]     log_entry_line_cnt;


    logic   [`UDP_LENGTH_W-1:0] log_length_reg;
    logic   [`UDP_LENGTH_W-1:0] log_length_next;

    log_entry_hdr               log_entry_hdr_reg;
    log_entry_hdr               log_entry_hdr_next;

    wire_log_entry_hdr          log_entry_hdr_cast;
    logic   [LOG_W-1:0]         log_hdr_line;

    logic   [LOG_W-1:0]             write_hdr_fifo_wr_data;
    logic   [LOG_PADBYTES_W-1:0]    write_hdr_fifo_wr_data_padbytes;
    logic                           write_hdr_fifo_wr_data_last;
    logic   [LOG_PADBYTES_W:0]      write_hdr_fifo_padbytes_calc;
    
    logic                           write_hdr_fifo_out_rd_val;
    logic                           write_hdr_fifo_out_rd_data_last;
    logic   [LOG_W-1:0]             write_hdr_fifo_out_rd_data;
    logic   [LOG_PADBYTES_W-1:0]    write_hdr_fifo_out_rd_data_padbytes;
    logic                           out_write_hdr_fifo_rd_rdy;

    logic                           out_condense_entries_wr_val;
    logic   [LOG_W-1:0]             out_condense_entries_wr_data;
    logic   [LOG_PADBYTES_W-1:0]    out_condense_entries_wr_padbytes;
    logic                           out_condense_entries_wr_last;
    logic                           condense_entries_out_wr_rdy;

    logic                           condense_entries_out_rd_val;
    logic   [LOG_W-1:0]             condense_entries_out_rd_data;
    logic   [LOG_PADBYTES_W-1:0]    condense_entries_out_rd_data_padbytes;
    logic                           condense_entries_out_rd_data_last;
    logic                           out_condense_entries_rd_rdy;
    
    logic                           out_reset_entry_addr;
    logic                           out_incr_entry_addr;
    logic                           save_last_entry_line;
    logic                           reuse_entry_line;
    logic                           output_done;
    
    logic                           last_entry_out;

    logic   [SHIFT_WIDTH-1:0]       out_entry_shift_calc;
    logic   [LOG_PADBYTES_W-1:0]    out_condense_entries_wr_realign_bytes;

    logic   [INT_W-1:0]             last_log_view_reg;
    logic   [INT_W-1:0]             last_log_view_next;


    assign log_entry_hdr_cast.view = log_entry_hdr_reg.view;
    assign log_entry_hdr_cast.op_num = log_entry_hdr_reg.op_num;
    assign log_entry_hdr_cast.log_entry_state = log_entry_hdr_reg.log_entry_state;
    assign log_entry_hdr_cast.hash_num_bytes = '0;

    assign log_hdr_line = {{(HDR_LINE_PADDING){1'b0}}, log_entry_hdr_cast};

    assign log_entry_hdr_next = store_log_hdr
                                ? log_hdr_mem_reader_rd_resp_data
                                : log_entry_hdr_reg;

    assign hdr_addr_start_next = store_req_info
                                ? src_reader_addr_start
                                : hdr_addr_start_reg;

    assign hdr_addr_end_next = store_req_info
                            ? src_reader_addr_end
                            : hdr_addr_end_reg;

    assign in_hdr_rd_addr_next = reset_in_hdr_rd_addr
                                ? hdr_addr_start_next
                                : incr_in_hdr_rd_addr
                                    ? in_hdr_rd_addr_reg + 1'b1
                                    : in_hdr_rd_addr_reg;

    assign in_data_rd_addr_next = reset_in_data_rd_addr
                                ? log_entry_hdr_next.payload_addr
                                : incr_in_data_rd_addr
                                    : in_data_rd_addr_reg + 1'b1
                                    : in_data_rd_addr_reg;

    assign log_entry_line_cnt = log_entry_hdr_next.payload_len[LOG_W_BYTES_W-1:0] == 0
                        ? log_entry_hdr_next.payload_len >> LOG_W_BYTES_W
                        : (log_entry_hdr_next.payload_len >> LOG_W_BYTES_W) + 1'b1;

    assign next_entry_addr_next = reset_in_hdr_rd_addr
                                ? log_entry_hdr_next.payload_addr + log_entry_line_cnt
                                : next_entry_addr_reg;

    assign log_length_next = store_req_info
                            ? '0
                            : incr_log_resp_size
                                ? WIRE_LOG_ENTRY_HDR_BYTES + log_entry_hdr_next.payload_len
                                : log_length_reg;

    assign reader_dst_entries_len = log_length_reg;

    assign data_line_next = store_data_line
                        ? log_data_mem_reader_rd_resp_data
                        : data_line_reg;

    assign last_hdr_in_rd = (in_hdr_rd_addr_reg + 1'b1) == hdr_addr_end_reg;
    assign last_data_in_rd = (in_data_rd_addr_reg + 1'b1) == next_entry_addr_reg;

    assign out_entry_addr_next = out_reset_entry_addr
                            ? hdr_addr_start_reg
                            : out_incr_entry_addr
                                ? out_entry_addr_reg + 1'b1
                                : out_entry_addr_reg;

    assign out_entry_line_next = save_last_entry_line
                                ? write_hdr_fifo_out_rd_data
                                : out_entry_addr_reg;

    assign out_entry_line_padbytes_next = out_reset_entry_addr
                                        ? '0
                                        : save_last_entry_line
                                            ? write_hdr_fifo_out_rd_data_padbytes
                                            : out_entry_line_padbytes_reg;

    assign last_entry_out = out_entry_addr_reg == hdr_addr_end_reg;

    always_ff @(posedge clk) begin
        hdr_addr_start_reg <= hdr_addr_start_next;
        hdr_addr_end_reg <= hdr_addr_end_next;
        in_hdr_rd_addr_reg <= in_hdr_rd_addr_next;
        log_entry_hdr_reg <= log_entry_hdr_next;
        in_data_rd_addr_reg <= in_data_rd_addr_next;
        next_entry_addr_reg <= next_entry_addr_next;
        log_length_reg <= log_length_next;
        data_line_reg <= data_line_next;

        out_entry_addr_reg <= out_entry_addr_next;
        out_entry_line_reg <= out_entry_line_next;
        out_entry_line_padbytes_reg <= out_entry_line_padbytes_next;

        last_log_view_reg <= last_log_view_next; 
    end

    assign last_log_view_next = store_last_view
                            ? log_entry_hdr_next.view
                            : last_log_view_reg;

    assign reader_dst_last_view = last_log_view_reg;


    assign write_hdr_fifo_padbytes_calc = LOG_W_BYTES - log_entry_hdr_reg.payload_len[LOG_PADBYTES_W-1:0];

    always_comb begin
        if (in_write_hdr_wr_entry_hdr) begin
            write_hdr_fifo_wr_data = log_hdr_line;
            write_hdr_fifo_wr_data_last = 1'b0;
            write_hdr_fifo_wr_data_padbytes = '0;
        end
        else begin
            write_hdr_fifo_wr_data = data_line_reg;
            write_hdr_fifo_wr_data_last = last_data_in_rd;
            write_hdr_fifo_wr_data_padbytes = last_data_in_rd
                                        ? write_hdr_fifo_padbytes_calc
                                        : '0;
        end
    end

    log_reader_in_ctrl in_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.src_reader_req_val                (src_reader_req_val                 )
        ,.reader_src_req_rdy                (reader_src_req_rdy                 )
                                                                                
        ,.reader_log_hdr_mem_rd_req_val     (reader_log_hdr_mem_rd_req_val      )
        ,.log_hdr_mem_reader_rd_req_rdy     (log_hdr_mem_reader_rd_req_rdy      )
                                                                                
        ,.log_hdr_mem_reader_rd_resp_val    (log_hdr_mem_reader_rd_resp_val     )
        ,.reader_log_hdr_mem_rd_resp_rdy    (reader_log_hdr_mem_rd_resp_rdy     )
                                                                                
        ,.reader_log_data_mem_rd_req_val    (reader_log_data_mem_rd_req_val     )
        ,.log_data_mem_reader_rd_req_rdy    (log_data_mem_reader_rd_req_rdy     )
                                                                                
        ,.log_data_mem_reader_rd_resp_val   (log_data_mem_reader_rd_resp_val    )
        ,.reader_log_data_mem_rd_resp_rdy   (reader_log_data_mem_rd_resp_rdy    )
                                                                                
        ,.in_write_hdr_fifo_wr_val          (in_write_hdr_fifo_wr_val           )
        ,.in_write_hdr_wr_entry_hdr         (in_write_hdr_wr_entry_hdr          )
        ,.write_hdr_fifo_in_wr_rdy          (write_hdr_fifo_in_wr_rdy           )
                                                                                
        ,.store_req_info                    (store_req_info                     )
        ,.store_log_hdr                     (store_log_hdr                      )
        ,.store_data_line                   (store_data_line                    )
        ,.incr_log_resp_size                (incr_log_resp_size                 )
        ,.reset_in_hdr_rd_addr              (reset_in_hdr_rd_addr               )
        ,.incr_in_hdr_rd_addr               (incr_in_hdr_rd_addr                )
        ,.reset_in_data_rd_addr             (reset_in_data_rd_addr              )
        ,.incr_in_data_rd_addr              (incr_in_data_rd_addr               )
                                                                                
        ,.output_done                       (output_done                        )
        ,.last_hdr_in_rd                    (last_hdr_in_rd                     )
        ,.last_data_in_rd                   (last_data_in_rd                    )
    );

    log_reader_out_ctrl out_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.write_hdr_fifo_out_rd_val             (write_hdr_fifo_out_rd_val          )
        ,.write_hdr_fifo_out_rd_data_last       (write_hdr_fifo_out_rd_data_last    )
        ,.write_hdr_fifo_out_rd_data_padbytes   (write_hdr_fifo_out_rd_data_padbytes)
        ,.out_write_hdr_fifo_rd_rdy             (out_write_hdr_fifo_rd_rdy          )
                                                                                    
        ,.out_condense_entries_wr_val           (out_condense_entries_wr_val        )
        ,.out_condense_entries_wr_last          (out_condense_entries_wr_last       )
        ,.condense_entries_out_wr_rdy           (condense_entries_out_wr_rdy        )
                                                                                    
        ,.out_reset_entry_addr                  (out_reset_entry_addr               )
        ,.out_incr_entry_addr                   (out_incr_entry_addr                )
        ,.save_last_entry_line                  (save_last_entry_line               )
        ,.reuse_entry_line                      (reuse_entry_line                   )
        ,.output_done                           (output_done                        )
                                                                                    
        ,.last_entry_out                        (last_entry_out                     )
    );

    realign_compile #(
         .REALIGN_W         (HDR_LINE_PADDING   )
        ,.DATA_W            (LOG_W              )
        ,.BUF_STAGES        (4                  )
    ) insert_wire_hdr (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_realign_data_val      (in_write_hdr_fifo_wr_val               )
        ,.src_realign_data          (write_hdr_fifo_wr_data                 )
        ,.src_realign_data_padbytes (write_hdr_fifo_wr_data_padbytes        )
        ,.src_realign_data_last     (write_hdr_fifo_wr_data_last            )
        ,.realign_src_data_rdy      (write_hdr_fifo_in_wr_rdy               )
    
        ,.realign_dst_data_val      (write_hdr_fifo_out_rd_val              )
        ,.realign_dst_data          (write_hdr_fifo_out_rd_data             )
        ,.realign_dst_data_padbytes (write_hdr_fifo_out_rd_data_padbytes    )
        ,.realign_dst_data_last     (write_hdr_fifo_out_rd_data_last        )
        ,.dst_realign_data_rdy      (out_write_hdr_fifo_rd_rdy              )
    
        ,.realign_dst_removed_data  ()
    );

    assign out_entry_shift_calc = out_entry_line_padbytes_reg << 3;

    always_comb begin
        if (reuse_entry_line) begin
            out_condense_entries_wr_data = out_entry_line_reg >> out_entry_shift_calc;
            out_condense_entries_wr_padbytes = '0;
            out_condense_entries_wr_realign_bytes = out_entry_line_padbytes_reg;
        end
        else begin
            out_condense_entries_wr_data = write_hdr_fifo_out_rd_data;
            out_condense_entries_wr_padbytes = write_hdr_fifo_out_rd_data_padbytes;
            out_condense_entries_wr_realign_bytes = '0;
        end
    end

    realign_runtime #(
         .DATA_W            (LOG_W  )
        ,.BUF_STAGES        (4      )
    ) coalesce_entries (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.realign_bytes             (out_entry_line_padbytes_reg            )
        ,.src_realign_data_val      (out_condense_entries_wr_val            )
        ,.src_realign_data          (out_condense_entries_wr_data           )
        ,.src_realign_data_padbytes (out_condense_entries_wr_padbytes       )
        ,.src_realign_data_last     (out_condense_entries_wr_last           )
        ,.realign_src_data_rdy      (condense_entries_out_wr_rdy            )
    
        ,.realign_dst_data_val      (condense_entries_out_rd_val            )
        ,.realign_dst_data          (condense_entries_out_rd_data           )
        ,.realign_dst_data_padbytes (condense_entries_out_rd_data_padbytes  )
        ,.realign_dst_data_last     (condense_entries_out_rd_data_last      )
        ,.dst_realign_data_rdy      (out_condense_entries_rd_rdy            )
    
        ,.full_line                 ()
    );

    assign reader_dst_data = condense_entries_out_rd_data;
    assign reader_dst_data_padbytes = reader_dst_data_last
                                    ? condense_entries_out_rd_data_padbytes
                                    : '0;

endmodule
