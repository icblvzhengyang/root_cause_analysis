/*
 * TestBench for Ariane MMU
 * Checks Passthrough, DTLB Walk, ITLB Walk, and TLB Hits.
 */

`timescale 1ns / 1ps

import ariane_pkg::*;
import riscv::*;

module tb_mmu;

initial begin
  $fsdbDumpfile("test.fsdb");
  $fsdbDumpvars(0, tb_mmu, "+mda", "+struct", "+parameter");
  $fsdbDumpSVA;
end

    // -------------------------------------------------------------------------
    // Parameters & Configuration
    // -------------------------------------------------------------------------
    localparam int unsigned INSTR_TLB_ENTRIES = 4;
    localparam int unsigned DATA_TLB_ENTRIES  = 4;
    localparam int unsigned ASID_WIDTH        = 1;
    
    // Create a configuration object
    localparam ariane_cfg_t TEST_CFG = ArianeDefaultConfig;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic clk_i;
    logic rst_ni;
    logic flush_i;
    logic enable_translation_i;
    logic en_ld_st_translation_i;
    
    // IF Interface
    icache_areq_o_t icache_areq_i;
    icache_areq_i_t icache_areq_o;

    // LSU Interface
    exception_t             misaligned_ex_i;
    logic                   lsu_req_i;
    logic [riscv::VLEN-1:0] lsu_vaddr_i;
    logic                   lsu_is_store_i;
    logic                   lsu_dtlb_hit_o;
    logic [riscv::PLEN-13:0] lsu_dtlb_ppn_o;
    logic                   lsu_valid_o;
    logic [riscv::PLEN-1:0] lsu_paddr_o;
    exception_t             lsu_exception_o;

    // General Control
    riscv::priv_lvl_t       priv_lvl_i;
    riscv::priv_lvl_t       ld_st_priv_lvl_i;
    logic                   sum_i;
    logic                   mxr_i;
    logic [riscv::PPNW-1:0] satp_ppn_i;
    logic [ASID_WIDTH-1:0]  asid_i;
    logic [ASID_WIDTH-1:0]  asid_to_be_flushed_i;
    logic [riscv::VLEN-1:0] vaddr_to_be_flushed_i;
    logic                   flush_tlb_i;
    
    // Perf Counters
    logic itlb_miss_o;
    logic dtlb_miss_o;

    // PTW Memory Interface (The MMU acts as master, TB acts as memory)
    dcache_req_o_t req_port_i; // Response FROM memory TO mmu
    dcache_req_i_t req_port_o; // Request FROM mmu TO memory

    // PMP (Static allow for this test)
    riscv::pmpcfg_t [15:0] pmpcfg_i;
    logic [15:0][53:0]     pmpaddr_i;

    // -------------------------------------------------------------------------
    // Simulation Variables
    // -------------------------------------------------------------------------
    // Pseudo-Physical Memory to hold Page Tables
    // Key: Physical Address (64-bit aligned), Value: 64-bit Data (PTE)
    logic [63:0] phys_mem [longint]; 
    
    int tests_passed = 0;
    int tests_failed = 0;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    mmu #(
        .INSTR_TLB_ENTRIES (INSTR_TLB_ENTRIES),
        .DATA_TLB_ENTRIES  (DATA_TLB_ENTRIES),
        .ASID_WIDTH        (ASID_WIDTH),
        .ArianeCfg         (TEST_CFG)
    ) dut (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),
        .flush_i                (flush_i),
        .enable_translation_i   (enable_translation_i),
        .en_ld_st_translation_i (en_ld_st_translation_i),
        .icache_areq_i          (icache_areq_i),
        .icache_areq_o          (icache_areq_o),
        .misaligned_ex_i        (misaligned_ex_i),
        .lsu_req_i              (lsu_req_i),
        .lsu_vaddr_i            (lsu_vaddr_i),
        .lsu_is_store_i         (lsu_is_store_i),
        .lsu_dtlb_hit_o         (lsu_dtlb_hit_o),
        .lsu_dtlb_ppn_o         (lsu_dtlb_ppn_o),
        .lsu_valid_o            (lsu_valid_o),
        .lsu_paddr_o            (lsu_paddr_o),
        .lsu_exception_o        (lsu_exception_o),
        .priv_lvl_i             (priv_lvl_i),
        .ld_st_priv_lvl_i       (ld_st_priv_lvl_i),
        .sum_i                  (sum_i),
        .mxr_i                  (mxr_i),
        .satp_ppn_i             (satp_ppn_i),
        .asid_i                 (asid_i),
        .asid_to_be_flushed_i   (asid_to_be_flushed_i),
        .vaddr_to_be_flushed_i  (vaddr_to_be_flushed_i),
        .flush_tlb_i            (flush_tlb_i),
        .itlb_miss_o            (itlb_miss_o),
        .dtlb_miss_o            (dtlb_miss_o),
        .req_port_i             (req_port_i),
        .req_port_o             (req_port_o),
        .pmpcfg_i               (pmpcfg_i),
        .pmpaddr_i              (pmpaddr_i)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------

    // Helper: Reset signals
    task reset_system();
        rst_ni = 0;
        flush_i = 0;
        enable_translation_i = 0;
        en_ld_st_translation_i = 0;
        
        // ICache Init
        icache_areq_i = '0;
        
        // LSU Init
        misaligned_ex_i = '0;
        lsu_req_i = 0;
        lsu_vaddr_i = '0;
        lsu_is_store_i = 0;
        
        // Config Init
        priv_lvl_i = riscv::PRIV_LVL_M;
        ld_st_priv_lvl_i = riscv::PRIV_LVL_M;
        sum_i = 0;
        mxr_i = 0;
        satp_ppn_i = '0;
        asid_i = 0;
        asid_to_be_flushed_i = 0;
        vaddr_to_be_flushed_i = 0;
        flush_tlb_i = 0;
        
        // PMP Init (Allow all)
        pmpcfg_i = '0;
        pmpaddr_i = '0;

        // Memory Resp Init
        req_port_i.data_gnt = 0;
        req_port_i.data_rvalid = 0;
        req_port_i.data_rdata = '0;

        repeat(5) @(posedge clk_i);
        rst_ni = 1;
        repeat(2) @(posedge clk_i);
    endtask

    // Helper: Create a PTE entry
    function logic [63:0] make_pte(logic [43:0] ppn, logic valid, logic read, logic write, logic exec, logic user, logic is_global, logic accessed, logic dirty);
        riscv::pte_t pte;
        pte.reserved = '0;
        pte.ppn = ppn;
        pte.rsw = '0;
        pte.d = dirty;
        pte.a = accessed;
        pte.g = is_global;
        pte.u = user;
        pte.x = exec;
        pte.w = write;
        pte.r = read;
        pte.v = valid;
        return pte; // auto cast
    endfunction

    // Helper: Setup Page Tables in "Physical Memory" (Associative Array)
    // Maps VA 0x8000_0000 -> PA 0x9000_0000 (4KB Page)
    // Root PT is at PPN 0x10000
    task setup_sv39_tables(logic [43:0] root_ppn);
        // SV39: 9-bit VPN[2], 9-bit VPN[1], 9-bit VPN[0], 12-bit Offset
        // VA: 0x0000_0000_8000_0000
        // Binary: ... 0000 0000 1000 0000 0000 0000 0000 0000
        // VPN[2] = 0x2
        // VPN[1] = 0x0
        // VPN[0] = 0x0
        
        logic [63:0] root_pt_addr;
        logic [63:0] lvl2_pt_addr;
        logic [63:0] lvl3_pt_addr;
        
        logic [43:0] lvl2_ppn = 44'h20000;
        logic [43:0] lvl3_ppn = 44'h30000;
        logic [43:0] target_ppn = 44'h90000; // Target Physical Page

        // 1. Root Page Table (Level 1) Entry
        // Index is VPN[2] = 2
        root_pt_addr = (root_ppn << 12) + (2 * 8); 
        // Point to Level 2 PT. Valid, No R/W/X (pointer).
        // Args: ppn, valid, r, w, x, u, g, a, d
        phys_mem[root_pt_addr] = make_pte(lvl2_ppn, 1, 0, 0, 0, 0, 0, 0, 0);

        // 2. Level 2 Page Table Entry
        // Index is VPN[1] = 0
        lvl2_pt_addr = (lvl2_ppn << 12) + (0 * 8);
        // Point to Level 3 PT. Valid, No R/W/X.
        phys_mem[lvl2_pt_addr] = make_pte(lvl3_ppn, 1, 0, 0, 0, 0, 0, 0, 0);

        // 3. Level 3 Page Table Entry (Leaf)
        // Index is VPN[0] = 0
        lvl3_pt_addr = (lvl3_ppn << 12) + (0 * 8);
        // Map to Target PPN. Valid, R, W, X, A, D.
        phys_mem[lvl3_pt_addr] = make_pte(target_ppn, 1, 1, 1, 1, 0, 0, 1, 1);
        
        $display("[TB] Page Tables Initialized. Root PPN: %h", root_ppn);
        $display("[TB] Map: VA 0x80000000 -> PA %h", {target_ppn, 12'h0});
    endtask

    // -------------------------------------------------------------------------
    // Mock Memory / PTW Responder Process
    // -------------------------------------------------------------------------
    // This block monitors the request port coming OUT of the MMU (from the PTW)
    // and sends responses back INTO the MMU.
    always @(posedge clk_i) begin
        // Variable declaration moved to the top of the block
        longint phys_addr;
        
        // Default
        req_port_i.data_gnt    <= 0;
        req_port_i.data_rvalid <= 0;
        req_port_i.data_rdata  <= '0;

        if (rst_ni) begin
            // 1. Grant Phase
            if (req_port_o.data_req) begin
                req_port_i.data_gnt <= 1; // Grant immediately
                
                // 2. Read Data Phase (Simulate 1 cycle latency)
                // Extract physical address requested by PTW
                phys_addr = {req_port_o.address_tag, req_port_o.address_index};
                
                // Align to 8 bytes just in case (PTW reads 64-bit PTEs)
                phys_addr = phys_addr & 64'hFFFF_FFFF_FFFF_FFF8;

                if (phys_mem.exists(phys_addr)) begin
                    req_port_i.data_rdata <= phys_mem[phys_addr];
                    $display("[Mem] Read Access @ PA %h -> Data %h", phys_addr, phys_mem[phys_addr]);
                end else begin
                    // $error("[Mem] Read Access @ PA %h -> UNINITIALIZED/SEGFAULT", phys_addr);
                    req_port_i.data_rdata <= '0;
                end
                
                req_port_i.data_rvalid <= 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("Start Ariane MMU TestBench");
        $display("==================================================");

        reset_system();

        // ---------------------------------------------------------
        // Test Case 1: Passthrough (Translation Disabled)
        // ---------------------------------------------------------
        $display("\n--- Test Case 1: Passthrough (Translation Disabled) ---");
        enable_translation_i = 0; 
        en_ld_st_translation_i = 0;
        lsu_req_i = 1;
        lsu_vaddr_i = 64'hDEAD_BEEF; // Arbitrary address
        lsu_is_store_i = 0;          // Load

        @(posedge clk_i);
        #1; // Wait for comb logic
        
        // In passthrough, Valid should be high immediately (or next cycle) 
        // and PAddr == VAddr
        wait(lsu_valid_o == 1);
        
        // Removed [63:0] slice to be safe against PLEN width mismatches
        if (lsu_paddr_o == 64'hDEAD_BEEF) begin
            $display("PASS: Passthrough Address Match. PA: %h", lsu_paddr_o);
            tests_passed++;
        end else begin
            $display("FAIL: Passthrough Mismatch. Expected %h, Got %h", 64'hDEAD_BEEF, lsu_paddr_o);
            tests_failed++;
        end

        lsu_req_i = 0;
        @(posedge clk_i);

        // ---------------------------------------------------------
        // Test Case 2: DTLB Miss -> PTW Walk -> Hit
        // ---------------------------------------------------------
        $display("\n--- Test Case 2: DTLB Miss & Page Table Walk ---");
        
        // 1. Setup Memory
        setup_sv39_tables(44'h10000); // Root at 0x10000
        
        // 2. Configure MMU
        enable_translation_i   = 1;
        en_ld_st_translation_i = 1;
        satp_ppn_i             = 44'h10000; // Point to root
        priv_lvl_i             = riscv::PRIV_LVL_S; // Supervisor mode
        ld_st_priv_lvl_i       = riscv::PRIV_LVL_S;

        // 3. Request Load at 0x8000_0000
        lsu_req_i = 1;
        lsu_vaddr_i = 64'h0000_0000_8000_0000;
        lsu_is_store_i = 0;

        // 4. Wait for completion (PTW needs several cycles)
        // Monitor miss signal
        @(posedge clk_i);
        #1;
        if (dtlb_miss_o) $display("[Info] DTLB Miss detected, expecting PTW...");
        
        // Wait for valid output
        fork 
            begin
                wait(lsu_valid_o == 1);
            end
            begin
                repeat(100) @(posedge clk_i);
                $display("TIMEOUT: PTW took too long.");
            end
        join_any

        // 5. Verify Result (Should map to 0x9000_0000)
        // Expected PA: 0x90000000
        if (lsu_valid_o && lsu_paddr_o == 64'h0000_0000_9000_0000) begin
            $display("PASS: DTLB Walk Successful. VA %h -> PA %h", lsu_vaddr_i, lsu_paddr_o);
            tests_passed++;
        end else begin
            $display("FAIL: DTLB Walk Failed. Valid: %b, PA: %h (Expected 90000000)", lsu_valid_o, lsu_paddr_o);
            if (lsu_exception_o.valid) $display("Exception raised! Cause: %h", lsu_exception_o.cause);
            tests_failed++;
        end

        lsu_req_i = 0;
        @(posedge clk_i);

        // ---------------------------------------------------------
        // Test Case 3: DTLB Hit (Re-access same address)
        // ---------------------------------------------------------
        $display("\n--- Test Case 3: DTLB Hit ---");
        // Request same address. Should be valid IMMEDIATELY (combinational hit logic in TLB) 
        // or next cycle depending on implementation. In Ariane `lsu_dtlb_hit_o` is cycle 0.
        
        lsu_req_i = 1;
        lsu_vaddr_i = 64'h0000_0000_8000_0000;
        
        @(posedge clk_i);
        #1; 
        
        if (lsu_dtlb_hit_o) begin
             $display("PASS: DTLB Hit detected immediately.");
             tests_passed++;
        end else begin
             $display("FAIL: Expected DTLB Hit.");
             tests_failed++;
        end
        
        lsu_req_i = 0;
        @(posedge clk_i);

        // ---------------------------------------------------------
        // Test Case 4: ITLB Miss & Walk
        // ---------------------------------------------------------
        $display("\n--- Test Case 4: ITLB Miss & Walk ---");
        
        // Reset Fetch request
        icache_areq_i.fetch_req = 1;
        icache_areq_i.fetch_vaddr = 64'h0000_0000_8000_0000; // Same mapping, executable bit is set
        
        // Wait for response
        // Note: The Mock Memory is shared, so the PTW will find the same entries.
        // Since ITLB and DTLB are separate, this should trigger a new walk or at least ITLB fill.
        
        fork 
            begin
                wait(icache_areq_o.fetch_valid == 1);
            end
            begin
                repeat(100) @(posedge clk_i);
                $display("TIMEOUT: ITLB PTW took too long.");
            end
        join_any

        if (icache_areq_o.fetch_valid && icache_areq_o.fetch_paddr == 64'h0000_0000_9000_0000) begin
             $display("PASS: ITLB Walk Successful. VA %h -> PA %h", icache_areq_i.fetch_vaddr, icache_areq_o.fetch_paddr);
             tests_passed++;
        end else begin
             $display("FAIL: ITLB Walk Failed/Wrong Address. PA: %h", icache_areq_o.fetch_paddr);
             if (icache_areq_o.fetch_exception.valid) $display("Exception! Cause: %h", icache_areq_o.fetch_exception.cause);
             tests_failed++;
        end

        icache_areq_i.fetch_req = 0;
        @(posedge clk_i);

        // ---------------------------------------------------------
        // Summary
        // ---------------------------------------------------------
        $display("\n==================================================");
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", tests_failed);
        if (tests_failed == 0) 
            $display("ALL PASSED");
        else 
            $display("SOME FAILED");
        $display("==================================================");
        
        $finish;
    end

endmodule