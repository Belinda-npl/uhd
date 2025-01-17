-------------------------------------------------------------------------------
--
-- File: x3xx_wr_top.vhd
-- Author:
-- Original Project: N310
-- Date: 22 February 2018
--
-------------------------------------------------------------------------------
-- Copyright 2018 Ettus Research, A National Instruments Company
-- SPDX-License-Identifier: LGPL-3.0
-------------------------------------------------------------------------------
--
-- Purpose:
--
-- Wrapper file for the White Rabbit cores.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.wrcore_pkg.all;
use work.etherbone_pkg.all;
use work.endpoint_pkg.all;
use work.streamers_pkg.all;
use work.wr_xilinx_pkg.all;
use work.wr_board_pkg.all;
use work.axi4_pkg.all;

library unisim;
use unisim.VCOMPONENTS.all;


entity x3xx_wr_top is
  generic(
    g_simulation  : integer := 0;
    g_dpram_size  : integer := 131072/4;
    g_dpram_initf : string := "../../../../bin/wrpc/wrc_phy16.bram");
  port (
    ---------------------------------------------------------------------------
    -- Resets
    ---------------------------------------------------------------------------
    -- Reset input (active low, can be async)
    areset_n_i          : in  std_logic;

    ---------------------------------------------------------------------------
    -- Oscillators and control DACs
    ---------------------------------------------------------------------------
    wr_refclk_buf_i          : in std_logic;     -- 20MHz VCXO after IBUFGDS

    gige_refclk_buf_i        : in std_logic;     -- 125 MHz MGT Ref after IBUFDS_GTE2

    dac_sclk_o               : out    std_logic; -- N310 cWB-DAC-SCLK
    dac_din_o                : out    std_logic; -- N310 cWB-DAC-DIN
    dac_clr_n_o              : out    std_logic; -- N310 cWB-DAC-nCLR
    dac_cs_n_o               : out    std_logic; -- N310 cWB-DAC-nSYNC
    dac_ldac_n_o             : out    std_logic; -- N310 cWB-DAC-nLDAC

    eeprom_scl_o             : out    std_logic;
    eeprom_scl_i             : in     std_logic;
    eeprom_sda_o             : out    std_logic;
    eeprom_sda_i             : in     std_logic;

    ---------------------------------------------------------------------------
    -- SFP pins
    ---------------------------------------------------------------------------
    -- LEDs
    LED_ACT                  : out    std_logic; -- connect to SFP+ ACT
    LED_LINK                 : out    std_logic; -- connect to SFP+ LINK

    sfp_txp_o                : out    std_logic;
    sfp_txn_o                : out    std_logic;

    sfp_rxp_i                : in     std_logic;
    sfp_rxn_i                : in     std_logic;

    sfp_mod_def0_b           : in     std_logic;  -- sfp detect
    --sfp_mod_def1_b           : inout  std_logic;  -- scl
    --sfp_mod_def2_b           : inout  std_logic;  -- sda
    sfp_scl_o                : out    std_logic;
    sfp_scl_i                : in     std_logic;
    sfp_sda_o                : out    std_logic;
    sfp_sda_i                : in     std_logic;
    sfp_tx_fault_i           : in     std_logic;
    sfp_tx_disable_o         : out    std_logic;
    sfp_los_i                : in     std_logic;

    ---------------------------------------------------------------------------
    -- Grandmaster mode inputs, optional
    ---------------------------------------------------------------------------

    -- 10MHz clock generated by N310 when using WR in grandmaster mode
    --clk_ext_gm_i             : in     std_logic := '0';
    -- PPS generated by N310 when using WR in grandmaster mode
    --pps_ext_gm_i             : in     std_logic := '0';

    ---------------------------------------------------------------------------
    --UART
    ---------------------------------------------------------------------------
    wr_uart_rxd      : in std_logic;
    wr_uart_txd      : out std_logic;


    ------------------------------------------
    -- Axi Slave Bus Interface S00_AXI
    ------------------------------------------
    -- aclk provided by this IP, wire to master!
    s00_axi_aclk_o  : out std_logic;
    s00_axi_aresetn : in  std_logic;
    s00_axi_awaddr  : in std_logic_vector(31 downto 0);
    s00_axi_awprot  : in  std_logic_vector(2 downto 0);
    s00_axi_awvalid : in  std_logic;
    s00_axi_awready : out std_logic;
    s00_axi_wdata   : in std_logic_vector(31 downto 0);
    s00_axi_wstrb   : in std_logic_vector(3 downto 0);
    s00_axi_wvalid  : in  std_logic;
    s00_axi_wready  : out std_logic;
    s00_axi_bresp   : out std_logic_vector(1 downto 0);
    s00_axi_bvalid  : out std_logic;
    s00_axi_bready  : in std_logic;
    s00_axi_araddr  : in std_logic_vector(31 downto 0);
    s00_axi_arprot  : in std_logic_vector(2 downto 0);
    s00_axi_arvalid : in std_logic;
    s00_axi_arready : out std_logic;
    s00_axi_rdata   : out std_logic_vector(31 downto 0);
    s00_axi_rresp   : out std_logic_vector(1 downto 0);
    s00_axi_rvalid  : out std_logic;
    s00_axi_rready  : in std_logic;
    s00_axi_rlast   : out std_logic;
    axi_int_o       : out std_logic;  -- axi interrupt signal


    ---------------------------------------------------------------------------
    -- PPS and main clock
    ---------------------------------------------------------------------------
    -- PPS output from WR Core, in 125M domain
    pps_o                    : out    std_logic;
    clk_pps_o                : out    std_logic;
    link_ok_o                : out    std_logic;

    ---------------------------------------------------------------------------
    -- Debug
    ---------------------------------------------------------------------------
    clk_sys_locked_o         : out    std_logic;
    clk_dmtd_locked_o        : out    std_logic;
    wr_debug0_o              : out    std_logic;
    wr_debug1_o              : out    std_logic);
end entity x3xx_wr_top;

architecture structure of x3xx_wr_top is

  component n3xx_serial_dac_arb
    generic(
      g_invert_sclk    : boolean;
      g_num_extra_bits : integer);
    port (
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      val1_i      : in  std_logic_vector(15 downto 0);
      load1_i     : in  std_logic;
      val2_i      : in  std_logic_vector(15 downto 0);
      load2_i     : in  std_logic;
      dac_cs_n_o  : out std_logic_vector(1 downto 0);
      dac_clr_n_o : out std_logic;
      dac_sclk_o  : out std_logic;
      dac_din_o   : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------

  -- PLLs, clocks
  signal clk_pll_62m5 : std_logic;
  signal clk_pll_125m : std_logic;
  signal clk_ref_62m5 : std_logic;
  signal clk_pll_dmtd : std_logic;
  signal pll_locked   : std_logic;
  signal clk_10m_ext  : std_logic;

  -- Reset logic
  signal rst_pll_62m5_n         : std_logic;
  signal rstlogic_arst_n    : std_logic;
  signal rstlogic_clk_in    : std_logic_vector(1 downto 0);
  signal rstlogic_rst_out   : std_logic_vector(1 downto 0);

  -- PLL DAC ARB
  signal dac_hpll_load_p1 : std_logic;
  signal dac_hpll_data    : std_logic_vector(15 downto 0);
  signal dac_dpll_load_p1 : std_logic;
  signal dac_dpll_data    : std_logic_vector(15 downto 0);
  signal dac_cs_vec_n       : std_logic_vector(1 downto 0);

  -- OneWire
  signal onewire_in : std_logic_vector(1 downto 0);
  signal onewire_en : std_logic_vector(1 downto 0);

  -- PHY
  signal phy16_to_wrc   : t_phy_16bits_to_wrc;
  signal phy16_from_wrc : t_phy_16bits_from_wrc;

  -- External reference
  signal ext_ref_mul         : std_logic;
  signal ext_ref_mul_locked  : std_logic;
  signal ext_ref_mul_stopped : std_logic;
  signal ext_ref_rst         : std_logic;

  -- SFP I2C
  --signal sfp_scl_o          : std_logic;
  --signal sfp_scl_i          : std_logic;
  --signal sfp_sda_o          : std_logic;
  --signal sfp_sda_i          : std_logic;

  -- WRC WB Slave interface
  signal wb_slave_out : t_wishbone_slave_out;
  signal wb_slave_in  : t_wishbone_slave_in;
  signal zero : std_logic;


  signal ref_clk_fb_o, pps, ref_clk_fb_i, clk_ref_125m, clk_ref_125m_bufg : std_logic;


begin

  wr_debug0_o <= dac_dpll_load_p1;
  wr_debug1_o <= dac_hpll_load_p1;

  -----------------------------------------------------------------------------
  -- Platform-dependent part (PHY, PLLs, buffers, etc)
  -----------------------------------------------------------------------------

  cmp_xwrc_platform : xwrc_platform_xilinx
    generic map (
      g_fpga_family               => "kintex7",
      g_with_external_clock_input => false,
      g_use_default_plls          => TRUE,
      g_simulation                => 0,
      g_use_ibufgds               => false )
    port map (
      areset_n_i            => areset_n_i,
      clk_10m_ext_i         => '0',
      clk_20m_vcxo_i        => wr_refclk_buf_i,
      clk_125m_pllref_i     => '0', -- only used for "spartan6" g_fpga_family
      clk_125m_gtp_p_i      => gige_refclk_buf_i, -- buffered on top level with IBUFDS_GTE2
      clk_125m_gtp_n_i      => '0',
      sfp_txn_o             => sfp_txn_o,
      sfp_txp_o             => sfp_txp_o,
      sfp_rxn_i             => sfp_rxn_i,
      sfp_rxp_i             => sfp_rxp_i,
      sfp_tx_fault_i        => sfp_tx_fault_i,
      sfp_los_i             => sfp_los_i,
      sfp_tx_disable_o      => sfp_tx_disable_o,
      clk_62m5_sys_o        => clk_pll_62m5, -- gige_refclk_buf_i > BUFG > MMCM     > BUFG 62.5M
      clk_125m_ref_o        => clk_ref_62m5, -- gige_refclk_buf_i > GTX  > TXOUTCLK > BUFG 62.5M
      clk_62m5_dmtd_o       => clk_pll_dmtd, -- wr_refclk_buf_i   > BUFG > MMCM     > BUFG ~62.5M
      pll_locked_o          => pll_locked,
      clk_10m_ext_o         => clk_10m_ext,
      phy16_o               => phy16_to_wrc,
      phy16_i               => phy16_from_wrc,
      ext_ref_mul_o         => ext_ref_mul,
      ext_ref_mul_locked_o  => ext_ref_mul_locked,
      ext_ref_mul_stopped_o => ext_ref_mul_stopped,
      ext_ref_rst_i         => ext_ref_rst);

  -----------------------------------------------------------------------------
  -- Reset logic
  -----------------------------------------------------------------------------

  -- logic AND of all async reset sources (active low)
  rstlogic_arst_n <= pll_locked and areset_n_i;

  -- concatenation of all clocks required to have synced resets
  rstlogic_clk_in(0) <= clk_pll_62m5;
  rstlogic_clk_in(1) <= clk_ref_62m5;

  cmp_rstlogic_reset : gc_reset
    generic map (
      g_clocks    => 2,                           -- 62.5MHz, 125MHz
      g_logdelay  => 4,                           -- 16 clock cycles
      g_syncdepth => 3)                           -- length of sync chains
    port map (
      free_clk_i => gige_refclk_buf_i,
      locked_i   => rstlogic_arst_n,
      clks_i     => rstlogic_clk_in,
      rstn_o     => rstlogic_rst_out);

  -- distribution of resets (already synchronized to their clock domains)
  rst_pll_62m5_n <= rstlogic_rst_out(0);

  -- rst_sys_62m5_n_o <= rst_pll_62m5_n; -- reset in 62.5 MHz domain, if needed
  -- rst_ref_125m_n_o <= rstlogic_rst_out(1); -- reset in 125 MHz domain, if needed


  -----------------------------------------------------------------------------
  -- 2x SPI DAC
  -----------------------------------------------------------------------------

  cmp_dac_arb : x3xx_serial_dac_arb
    generic map (
      g_invert_sclk    => FALSE,
      g_num_extra_bits => 8)
    port map (
      clk_i         => clk_pll_62m5,
      rst_n_i       => rst_pll_62m5_n,
      val1_i        => dac_dpll_data,
      load1_i       => dac_dpll_load_p1,
      val2_i        => dac_hpll_data,
      load2_i       => dac_hpll_load_p1,
      dac_cs_n_o    => dac_cs_vec_n,
      dac_clr_n_o   => dac_clr_n_o, -- unused, always '1'
      dac_sclk_o    => dac_sclk_o,
      dac_din_o     => dac_din_o);

  -- only need one CS for the AD5663 DAC, channel is selected with data bits
  dac_cs_n_o <= dac_cs_vec_n(0);

  -- nLDAC is unused. A command embedded in the DAC SPI transaction is used instead
  -- to transfer the write from the input register to the DAC output.
  dac_ldac_n_o <= '1';



  -----------------------------------------------------------------------------
  -- The WR PTP core with optional fabric interface attached
  -----------------------------------------------------------------------------

  cmp_board_common : xwrc_board_common
    generic map (
      g_simulation                => 0,
      g_with_external_clock_input => false, -- eventually true ! DJB !
      g_board_name                => "NA  ",
      g_phys_uart                 => TRUE,
      g_virtual_uart              => false,
      g_aux_clks                  => 0,
      g_ep_rxbuf_size             => 1024,
      g_tx_runt_padding           => TRUE,
      g_dpram_initf               => g_dpram_initf,
      g_dpram_size                => 131072/4,
      g_interface_mode            => PIPELINED,
      g_address_granularity       => BYTE,
      g_aux_sdb                   => c_wrc_periph3_sdb,
      g_softpll_enable_debugger   => TRUE,  -- was FALSE
      g_vuart_fifo_size           => 1024,
      g_pcs_16bit                 => TRUE,
      g_diag_id                   => 0,   -- guessing about this
      g_diag_ver                  => 185, -- setting the version reg to 0xB9
      g_diag_ro_size              => 0,  -- not sure if this is needed to enable diag regs
      g_diag_rw_size              => 16,  -- not sure if this is needed to enable diag regs
      g_streamers_op_mode         => TX_AND_RX,
      g_tx_streamer_params        => c_tx_streamer_params_defaut,
      g_rx_streamer_params        => c_rx_streamer_params_defaut,
      g_fabric_iface              => plain
      )
    port map (
      clk_sys_i            => clk_pll_62m5,
      clk_dmtd_i           => clk_pll_dmtd,
      clk_ref_i            => clk_ref_62m5,
      clk_aux_i            => (others => '0'),
      clk_10m_ext_i        => '0', -- ! DJB ! eventually external 10 MHz clock
      clk_ext_mul_i        => ext_ref_mul,
      clk_ext_mul_locked_i => ext_ref_mul_locked,
      clk_ext_stopped_i    => ext_ref_mul_stopped,
      clk_ext_rst_o        => ext_ref_rst,
      pps_ext_i            => '0', -- ! DJB ! eventually external PPS
      rst_n_i              => rst_pll_62m5_n,
      dac_hpll_load_p1_o   => dac_hpll_load_p1,
      dac_hpll_data_o      => dac_hpll_data,
      dac_dpll_load_p1_o   => dac_dpll_load_p1,
      dac_dpll_data_o      => dac_dpll_data,
      phy16_o              => phy16_from_wrc,
      phy16_i              => phy16_to_wrc,
      scl_o                => eeprom_scl_o, -- not using the I2C bus because we don't have a
      scl_i                => eeprom_scl_i, -- dedicated EEPROm for WR Cal.  Instead plan
      sda_o                => eeprom_sda_o, -- to read cal values over the UART and store
      sda_i                => eeprom_sda_i, -- on the main uSD card.
      sfp_scl_o            => sfp_scl_o,
      sfp_scl_i            => sfp_scl_i,
      sfp_sda_o            => sfp_sda_o,
      sfp_sda_i            => sfp_sda_i,
      sfp_det_i            => sfp_mod_def0_b,
      spi_sclk_o           => open,
      spi_ncs_o            => open,
      spi_mosi_o           => open,
      spi_miso_i           => '0',
      uart_rxd_i           => wr_uart_rxd,
      uart_txd_o           => wr_uart_txd,
      owr_pwren_o          => open,
      owr_en_o             => open,
      owr_i                => "11",
      wb_slave_i           => wb_slave_in,
      wb_slave_o           => wb_slave_out,
      aux_master_o         => open,
      aux_master_i         => cc_dummy_master_in,
      wrf_src_o            => open,
      wrf_src_i            => c_dummy_src_in,
      wrf_snk_o            => open,
      wrf_snk_i            => c_dummy_snk_in,
      wrs_tx_data_i        => (others=>'0'),
      wrs_tx_valid_i       => '0',
      wrs_tx_dreq_o        => open,
      wrs_tx_last_i        => '1',
      wrs_tx_flush_i       => '0',
      wrs_tx_cfg_i         => c_tx_streamer_cfg_default,
      wrs_rx_first_o       => open,
      wrs_rx_last_o        => open,
      wrs_rx_data_o        => open,
      wrs_rx_valid_o       => open,
      wrs_rx_dreq_i        => '0',
      wrs_rx_cfg_i         => c_rx_streamer_cfg_default,
      wb_eth_master_o      => open,
      wb_eth_master_i      => cc_dummy_master_in,
      aux_diag_i           => (others=>(others=>'0')),
      aux_diag_o           => open,
      tm_dac_value_o       => open,
      tm_dac_wr_o          => open,
      tm_clk_aux_lock_en_i => (others=>'0'),
      tm_clk_aux_locked_o  => open,
      timestamps_o         => open,
      timestamps_ack_i     => '1',
      abscal_txts_o        => open,
      abscal_rxts_o        => open,
      fc_tx_pause_req_i    => '0',
      fc_tx_pause_delay_i  => (others=>'0'),
      fc_tx_pause_ready_o  => open,
      tm_link_up_o         => open,
      tm_time_valid_o      => open,
      tm_tai_o             => open,
      tm_cycles_o          => open,
      led_act_o            => LED_ACT,
      led_link_o           => LED_LINK,
      btn1_i               => '1',
      btn2_i               => '1',
      pps_p_o              => pps,
      pps_led_o            => open,
      link_ok_o            => link_ok_o);

  -- I2C interface for SFP
  --sfp_mod_def1_b <= '0' when sfp_scl_o = '0' else 'Z';
  --sfp_mod_def2_b <= '0' when sfp_sda_o = '0' else 'Z';
  --sfp_scl_i      <= sfp_mod_def1_b;
  --sfp_sda_i      <= sfp_mod_def2_b;

  s00_axi_aclk_o <= clk_pll_62m5;

  zero <= '0';
  cmp_axi4lite_wbm: wb_axi4lite_bridge
    port map (
      clk_sys_i => clk_pll_62m5,
      rst_n_i   => s00_axi_aresetn,

      AWADDR  => s00_axi_awaddr,
      AWVALID => s00_axi_awvalid,
      AWREADY => s00_axi_awready,
      WDATA   => s00_axi_wdata,
      WSTRB   => s00_axi_wstrb,
      WVALID  => s00_axi_wvalid,
      WREADY  => s00_axi_wready,
      WLAST   => zero,
      BRESP   => s00_axi_bresp,
      BVALID  => s00_axi_bvalid,
      BREADY  => s00_axi_bready,
      ARADDR  => s00_axi_araddr,
      ARVALID => s00_axi_arvalid,
      ARREADY => s00_axi_arready,
      RDATA   => s00_axi_rdata,
      RRESP   => s00_axi_rresp,
      RVALID  => s00_axi_rvalid,
      RREADY  => s00_axi_rready,
      RLAST   => s00_axi_rlast,

      wb_adr  => wb_slave_in.adr,
      wb_dat_m2s => wb_slave_in.dat,
      wb_sel => wb_slave_in.sel,
      wb_cyc => wb_slave_in.cyc,
      wb_stb => wb_slave_in.stb,
      wb_we  => wb_slave_in.we,

      wb_dat_s2m => wb_slave_out.dat,
      wb_err     => wb_slave_out.err,
      wb_rty     => wb_slave_out.rty,
      wb_ack     => wb_slave_out.ack,
      wb_stall   => wb_slave_out.stall
    );


  -- locals to outputs
  clk_pps_o <= clk_ref_62m5; -- ref_clk
  pps_o <= pps; -- pps

end architecture structure ; -- of x3xx_wr_top

