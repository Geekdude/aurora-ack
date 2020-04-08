library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use std.env.stop;

library UNISIM;
use UNISIM.all;

entity aurora_ack_tb is
    end aurora_ack_tb;

architecture testbench of aurora_ack_tb is

--*************************Parameter Declarations**************************
    -- 156.25MHz GT Reference clock
    constant  CLOCKPERIOD_0    : time := 6.4     ns;
    constant  CLOCKPERIOD_1    : time := 6.4     ns;
    constant  DRP_CLOCKPERIOD  : time := 20.000  ns; -- GT DRP Clock
    constant  INIT_CLOCKPERIOD : time := 20.0    ns; -- Board/System Clock
    constant  clk_period       : time := 6.4     ns;

    constant  DLY              : time := 1       ns;

    constant  WORD_SIZE        : positive := 64;

--********************************Signal Declarations**********************************
    --Freerunning Clock
    signal  reference_clk_0_n_r   :  std_logic;
    signal  reference_clk_1_n_r   :  std_logic;
    signal  reference_clk_0_p_r   :  std_logic;
    signal  reference_clk_1_p_r   :  std_logic;
    signal  drp_clk_i             :  std_logic;
    signal  init_clk              :  std_logic;

    --Reset
    signal  reset_i               :  std_logic;
    signal  gt_reset_i            :  std_logic;

    --Dut1

        --Error Detection Interface
    signal  hard_err_0_i         :  std_logic;
    signal  soft_err_0_i         :  std_logic;

        --Status
    signal   channel_up_0_i      :  std_logic;
    signal   lane_up_0_i         :  std_logic_vector(0 downto 0);


        --GT Serial I/O
    signal   rxp_0_i             :  std_logic_vector(0 downto 0);
    signal   rxn_0_i             :  std_logic_vector(0 downto 0);

    signal   txp_0_i             :  std_logic_vector(0 downto 0);
    signal   txn_0_i             :  std_logic_vector(0 downto 0);

        -- Error signals from the Local Link packet checker
    signal   err_count_0_i       :  std_logic_vector(0 to 7);


    --Dut2

        --Error Detection Interface
    signal  hard_err_1_i        :  std_logic;
    signal  soft_err_1_i        :  std_logic;

        --Status
    signal   channel_up_1_i       :  std_logic;
    signal   lane_up_1_i          :  std_logic_vector(0 downto 0);


        --GT Serial I/O
    signal   rxp_1_i              :  std_logic_vector(0 downto 0);
    signal   rxn_1_i              :  std_logic_vector(0 downto 0);

    signal   txp_1_i              :  std_logic_vector(0 downto 0);
    signal   txn_1_i              :  std_logic_vector(0 downto 0);

    -- Error signals from the Local Link packet checker
    signal   err_count_1_i        :  std_logic_vector(0 to 7);

    -- Reset
    signal rst0                     : std_logic;
    signal rst1                     : std_logic;
    signal rst_n0                   : std_logic;
    signal rst_n1                   : std_logic;

    -- TX Stream Interface
    signal m_axi_tx0_tdata          : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal m_axi_tx0_tvalid         : std_logic;
    signal m_axi_tx0_tready         : std_logic;
    signal m_axi_tx0_tkeep          : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal m_axi_tx0_tlast          : std_logic;
    signal m_axi_tx1_tdata          : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal m_axi_tx1_tvalid         : std_logic;
    signal m_axi_tx1_tready         : std_logic;
    signal m_axi_tx1_tkeep          : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal m_axi_tx1_tlast          : std_logic;

    -- RX Stream Interface
    signal s_axi_rx0_tdata          : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal s_axi_rx0_tkeep          : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal s_axi_rx0_tvalid         : std_logic;
    signal s_axi_rx0_tlast          : std_logic;
    signal s_axi_rx1_tdata          : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal s_axi_rx1_tkeep          : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal s_axi_rx1_tvalid         : std_logic;
    signal s_axi_rx1_tlast          : std_logic;

    -- Send Stream Interface
    signal s_axi_send0_tdata        : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal s_axi_send0_tkeep        : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal s_axi_send0_tready       : std_logic;
    signal s_axi_send0_tvalid       : std_logic;
    signal s_axi_send0_tlast        : std_logic;
    signal s_axi_send1_tdata        : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal s_axi_send1_tkeep        : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal s_axi_send1_tready       : std_logic;
    signal s_axi_send1_tvalid       : std_logic;
    signal s_axi_send1_tlast        : std_logic;

    -- Receive Stream Interfac
    signal m_axi_recv0_tdata        : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal m_axi_recv0_tvalid       : std_logic;
    signal m_axi_recv0_tready       : std_logic;
    signal m_axi_recv0_tkeep        : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal m_axi_recv0_tlast        : std_logic;
    signal m_axi_recv1_tdata        : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal m_axi_recv1_tvalid       : std_logic;
    signal m_axi_recv1_tready       : std_logic;
    signal m_axi_recv1_tkeep        : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal m_axi_recv1_tlast        : std_logic;

    -- Receive CRC
    signal crc_pass_fail_n0         : std_logic;
    signal crc_valid0               : std_logic;
    signal crc_pass_fail_n1         : std_logic;
    signal crc_valid1               : std_logic;

    -- Clock
    signal   clk_0 : STD_LOGIC;
    signal   clk_1 : STD_LOGIC;

    -- Test Signals
    type packet_t is array(0 to 8) of std_logic_vector(WORD_SIZE - 1 downto 0);
    type packets_t is array(0 to 100) of packet_t;
    signal packets : packets_t;
    signal sent_count : integer := 0;
    signal recv_count : integer := 0;

    signal crc_pass_fail_n0_l       : std_logic;
    signal crc_pass_fail_n1_l       : std_logic;
    signal error_enabled            : std_logic;


    -- Component Declarations --

    component aurora_ack
        generic (
            WORD_SIZE          : positive := 64;
            FRAME_WIDTH        : positive := 512
        );
        Port (
            clk         : in std_logic;
            rst_n       : in std_logic;

            -- TX Stream Interface
            m_axi_tx_tdata          : out std_logic_vector(WORD_SIZE - 1 downto 0);
            m_axi_tx_tvalid         : out std_logic;
            m_axi_tx_tready         : in  std_logic;
            m_axi_tx_tkeep          : out std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            m_axi_tx_tlast          : out std_logic;

            -- RX Stream Interface
            s_axi_rx_tdata          : in  std_logic_vector(WORD_SIZE - 1 downto 0);
            s_axi_rx_tkeep          : in  std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            s_axi_rx_tvalid         : in  std_logic;
            s_axi_rx_tlast          : in  std_logic;

            -- Send Stream Interface
            s_axi_send_tdata        : in  std_logic_vector(WORD_SIZE - 1 downto 0);
            s_axi_send_tkeep        : in  std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            s_axi_send_tready       : out std_logic;
            s_axi_send_tvalid       : in  std_logic;
            s_axi_send_tlast        : in  std_logic;

            -- Receive Stream Interface
            m_axi_recv_tdata        : out std_logic_vector(WORD_SIZE - 1 downto 0);
            m_axi_recv_tvalid       : out std_logic;
            m_axi_recv_tready       : in  std_logic;
            m_axi_recv_tkeep        : out std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            m_axi_recv_tlast        : out std_logic;

            -- Receive CRC
            crc_pass_fail_n         : in std_logic;
            crc_valid               : in std_logic
        );
    end component;

    COMPONENT aurora_64b66b
        PORT (
            -- TX Stream Interface
            s_axi_tx_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            s_axi_tx_tvalid : IN STD_LOGIC;
            s_axi_tx_tready : OUT STD_LOGIC;
            s_axi_tx_tkeep          : in  std_logic_vector(7 downto 0);
            s_axi_tx_tlast          : in  std_logic;

            -- RX Stream Interface
            m_axi_rx_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axi_rx_tkeep          : out std_logic_vector(7 downto 0);
            m_axi_rx_tvalid : OUT STD_LOGIC;
            m_axi_rx_tlast          : out std_logic;

            -- GT Serial I/O
            rxp : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            rxn : IN STD_LOGIC_VECTOR(0 DOWNTO 0);

            txp : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
            txn : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);

            -- GT Reference Clock Interface
            gt_refclk1_p : IN STD_LOGIC;
            gt_refclk1_n : IN STD_LOGIC;

            -- Error Detection Interface
            hard_err : OUT STD_LOGIC;
            soft_err : OUT STD_LOGIC;

            -- CRC Status
            crc_pass_fail_n         : out std_logic;
            crc_valid               : out std_logic;

            -- Status
            channel_up : OUT STD_LOGIC;
            lane_up : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);

            -- System Interface
            init_clk : IN STD_LOGIC;
            link_reset_out : OUT STD_LOGIC;
            user_clk_out : OUT STD_LOGIC;
            sync_clk_out : OUT STD_LOGIC;
            sys_reset_out : OUT STD_LOGIC;
            reset_pb : IN STD_LOGIC;
            power_down : IN STD_LOGIC;
            pma_init : IN STD_LOGIC;
            loopback : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            tx_out_clk : OUT STD_LOGIC;
            mmcm_not_locked_out : OUT STD_LOGIC;

            -- DRP Ports
            drp_clk_in : IN STD_LOGIC;

            s_axi_awaddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axi_araddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axi_bready : IN STD_LOGIC;
            s_axi_awvalid : IN STD_LOGIC;
            s_axi_awready : OUT STD_LOGIC;
            s_axi_wvalid : IN STD_LOGIC;
            s_axi_wready : OUT STD_LOGIC;
            s_axi_bvalid : OUT STD_LOGIC;
            s_axi_arvalid : IN STD_LOGIC;
            s_axi_arready : OUT STD_LOGIC;
            s_axi_rvalid : OUT STD_LOGIC;
            s_axi_rready : IN STD_LOGIC;

            qpll_drpaddr_in : in STD_LOGIC_VECTOR ( 7 downto 0 );
            qpll_drpdi_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
            qpll_drpdo_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
            qpll_drprdy_out : out STD_LOGIC;
            qpll_drpen_in : in STD_LOGIC;
            qpll_drpwe_in : in STD_LOGIC;
            qpll_drpdo_out_quad1 : out STD_LOGIC_VECTOR ( 15 downto 0 );
            qpll_drprdy_out_quad1 : out STD_LOGIC;
            qpll_drpen_in_quad1 : in STD_LOGIC;
            qpll_drpwe_in_quad1 : in STD_LOGIC;

            -- Common Transceiver Ports
            gt_pll_lock : OUT STD_LOGIC;
            gt_qpllclk_quad1_out : OUT STD_LOGIC;
            gt_qpllrefclk_quad1_out : OUT STD_LOGIC;
            gt_qpllclk_quad7_out : OUT STD_LOGIC;
            gt_qpllrefclk_quad7_out : OUT STD_LOGIC;
            gt_rxcdrovrden_in : IN STD_LOGIC;
            gt_reset_out : OUT STD_LOGIC;
            gt_refclk1_out : OUT STD_LOGIC
        );
    END COMPONENT;

begin
    --_________________________Reset Connections________________
    rst_n0 <= not rst0;
    rst_n1 <= not rst1;

    --_________________________GT Serial Connections________________

    rxn_0_i      <=    txn_1_i;
    rxp_0_i      <=    txp_1_i;
    rxn_1_i      <=    txn_0_i;
    rxp_1_i      <=    txp_0_i;

    --____________________________Clocks____________________________

    process
    begin
        reference_clk_0_p_r <= '0';
        wait for CLOCKPERIOD_0 / 2;
        reference_clk_0_p_r <= '1';
        wait for CLOCKPERIOD_0 / 2;
    end process;

    reference_clk_0_n_r <= not reference_clk_0_p_r;


    --____________________________Clocks____________________________

    process
    begin
        reference_clk_1_p_r <= '0';
        wait for CLOCKPERIOD_1 / 2;
        reference_clk_1_p_r <= '1';
        wait for CLOCKPERIOD_1 / 2;
    end process;

    reference_clk_1_n_r <= not reference_clk_1_p_r;



    process
    begin
        drp_clk_i <= '0';
        wait for DRP_CLOCKPERIOD / 2;
        drp_clk_i <= '1';
        wait for DRP_CLOCKPERIOD / 2;
    end process;

    process
    begin
        init_clk <= '0';
        wait for INIT_CLOCKPERIOD / 2;
        init_clk <= '1';
        wait for INIT_CLOCKPERIOD / 2;
    end process;

    --____________________________Resets____________________________

    process
    begin
        reset_i <= '1';
        wait for 200 ns;
        reset_i <= '0';
        wait;
    end process;

    --____________________________Reseting PMA____________________________

    process
    begin
        gt_reset_i <= '1';
        wait for 5000 ns;
        gt_reset_i <= '0';
        wait;
    end process;

    --____________________________Instantiate UUT____________________________
    UUT0 : aurora_ack
    port map (
        clk                 => clk_0,
        rst_n               => rst_n0,
        m_axi_tx_tdata      => m_axi_tx0_tdata,
        m_axi_tx_tvalid     => m_axi_tx0_tvalid,
        m_axi_tx_tready     => m_axi_tx0_tready,
        m_axi_tx_tkeep      => m_axi_tx0_tkeep,
        m_axi_tx_tlast      => m_axi_tx0_tlast,
        s_axi_rx_tdata      => s_axi_rx0_tdata,
        s_axi_rx_tkeep      => s_axi_rx0_tkeep,
        s_axi_rx_tvalid     => s_axi_rx0_tvalid,
        s_axi_rx_tlast      => s_axi_rx0_tlast,
        s_axi_send_tdata    => s_axi_send0_tdata,
        s_axi_send_tkeep    => s_axi_send0_tkeep,
        s_axi_send_tready   => s_axi_send0_tready,
        s_axi_send_tvalid   => s_axi_send0_tvalid,
        s_axi_send_tlast    => s_axi_send0_tlast,
        m_axi_recv_tdata    => m_axi_recv0_tdata,
        m_axi_recv_tvalid   => m_axi_recv0_tvalid,
        m_axi_recv_tready   => m_axi_recv0_tready,
        m_axi_recv_tkeep    => m_axi_recv0_tkeep,
        m_axi_recv_tlast    => m_axi_recv0_tlast,
        crc_pass_fail_n     => crc_pass_fail_n0_l,
        crc_valid           => crc_valid0
    );

    UUT1 : aurora_ack
    port map (
        clk                 => clk_1,
        rst_n               => rst_n1,
        m_axi_tx_tdata      => m_axi_tx1_tdata,
        m_axi_tx_tvalid     => m_axi_tx1_tvalid,
        m_axi_tx_tready     => m_axi_tx1_tready,
        m_axi_tx_tkeep      => m_axi_tx1_tkeep,
        m_axi_tx_tlast      => m_axi_tx1_tlast,
        s_axi_rx_tdata      => s_axi_rx1_tdata,
        s_axi_rx_tkeep      => s_axi_rx1_tkeep,
        s_axi_rx_tvalid     => s_axi_rx1_tvalid,
        s_axi_rx_tlast      => s_axi_rx1_tlast,
        s_axi_send_tdata    => s_axi_send1_tdata,
        s_axi_send_tkeep    => s_axi_send1_tkeep,
        s_axi_send_tready   => s_axi_send1_tready,
        s_axi_send_tvalid   => s_axi_send1_tvalid,
        s_axi_send_tlast    => s_axi_send1_tlast,
        m_axi_recv_tdata    => m_axi_recv1_tdata,
        m_axi_recv_tvalid   => m_axi_recv1_tvalid,
        m_axi_recv_tready   => m_axi_recv1_tready,
        m_axi_recv_tkeep    => m_axi_recv1_tkeep,
        m_axi_recv_tlast    => m_axi_recv1_tlast,
        crc_pass_fail_n     => crc_pass_fail_n1_l,
        crc_valid           => crc_valid1
    );

    --____________________________Instantiate aurora 0____________________________
    aurora_0 : aurora_64b66b
        port map  (
            -- TX Stream Interface
            s_axi_tx_tdata    => m_axi_tx0_tdata,
            s_axi_tx_tvalid   => m_axi_tx0_tvalid,
            s_axi_tx_tready   => m_axi_tx0_tready,
            s_axi_tx_tkeep    => m_axi_tx0_tkeep,
            s_axi_tx_tlast    => m_axi_tx0_tlast,

            -- RX Stream Interface
            m_axi_rx_tdata    => s_axi_rx0_tdata,
            m_axi_rx_tkeep    => s_axi_rx0_tkeep,
            m_axi_rx_tvalid   => s_axi_rx0_tvalid,
            m_axi_rx_tlast    => s_axi_rx0_tlast,

            -- GT Serial I/O
            rxp => rxp_0_i,
            rxn => rxn_0_i,

            txp => txp_0_i,
            txn => txn_0_i,

            -- GT Reference Clock Interface
            gt_refclk1_p => reference_clk_0_p_r,
            gt_refclk1_n => reference_clk_0_n_r,

            -- Error Detection Interface
            hard_err    => hard_err_0_i,
            soft_err    => soft_err_0_i,

            -- CRC Status
            crc_pass_fail_n   => crc_pass_fail_n0,
            crc_valid         => crc_valid0,

            -- Status
            channel_up  => channel_up_0_i,
            lane_up     => lane_up_0_i,

            -- System Interface
            init_clk => init_clk,
            link_reset_out => open,
            user_clk_out => clk_0,
            sync_clk_out => open,
            sys_reset_out => rst0,
            reset_pb => gt_reset_i,
            power_down => '0',
            pma_init => gt_reset_i,
            loopback => "000",
            tx_out_clk => open,
            mmcm_not_locked_out => open,

            -- DRP Ports
            drp_clk_in => '0',

            s_axi_awaddr => (others => '0'),
            s_axi_rresp => open,
            s_axi_bresp => open,
            s_axi_wstrb => (others => '0'),
            s_axi_wdata => (others => '0'),
            s_axi_araddr => (others => '0'),
            s_axi_rdata => open,
            s_axi_bready => '0',
            s_axi_awvalid => '0',
            s_axi_awready => open,
            s_axi_wvalid => '0',
            s_axi_wready => open,
            s_axi_bvalid => open,
            s_axi_arvalid => '0',
            s_axi_arready => open,
            s_axi_rvalid => open,
            s_axi_rready => '0',

            qpll_drpaddr_in => (others => '0'),
            qpll_drpdi_in => (others => '0'),
            qpll_drpdo_out => open,
            qpll_drprdy_out => open,
            qpll_drpen_in => '0',
            qpll_drpwe_in => '0',
            qpll_drpdo_out_quad1 => open,
            qpll_drprdy_out_quad1 => open,
            qpll_drpen_in_quad1 => '0',
            qpll_drpwe_in_quad1 => '0',

            -- Common Transceiver Ports
            gt_pll_lock => open,
            gt_qpllclk_quad1_out => open,
            gt_qpllrefclk_quad1_out => open,
            gt_qpllclk_quad7_out => open,
            gt_qpllrefclk_quad7_out => open,
            gt_rxcdrovrden_in => '0',
            gt_reset_out => open,
            gt_refclk1_out => open
        );

    --____________________________Instantiate aurora 1____________________________
    aurora_1 : aurora_64b66b
        port map  (
            -- TX Stream Interface
            s_axi_tx_tdata    => m_axi_tx1_tdata,
            s_axi_tx_tvalid   => m_axi_tx1_tvalid,
            s_axi_tx_tready   => m_axi_tx1_tready,
            s_axi_tx_tkeep    => m_axi_tx1_tkeep,
            s_axi_tx_tlast    => m_axi_tx1_tlast,

            -- RX Stream Interface
            m_axi_rx_tdata    => s_axi_rx1_tdata,
            m_axi_rx_tkeep    => s_axi_rx1_tkeep,
            m_axi_rx_tvalid   => s_axi_rx1_tvalid,
            m_axi_rx_tlast    => s_axi_rx1_tlast,

            -- GT Serial I/O
            rxp => rxp_1_i,
            rxn => rxn_1_i,

            txp => txp_1_i,
            txn => txn_1_i,

            -- GT Reference Clock Interface
            gt_refclk1_p => reference_clk_1_p_r,
            gt_refclk1_n => reference_clk_1_n_r,

            -- Error Detection Interface
            hard_err    => hard_err_1_i,
            soft_err    => soft_err_1_i,

            -- CRC Status
            crc_pass_fail_n   => crc_pass_fail_n1,
            crc_valid         => crc_valid1,

            -- Status
            channel_up  => channel_up_1_i,
            lane_up     => lane_up_1_i,

            -- System Interface
            init_clk => init_clk,
            link_reset_out => open,
            user_clk_out => clk_1,
            sync_clk_out => open,
            sys_reset_out => rst1,
            reset_pb => gt_reset_i,
            power_down => '0',
            pma_init => gt_reset_i,
            loopback => "000",
            tx_out_clk => open,
            mmcm_not_locked_out => open,

            -- DRP Ports
            drp_clk_in => '0',

            s_axi_awaddr => (others => '0'),
            s_axi_rresp => open,
            s_axi_bresp => open,
            s_axi_wstrb => (others => '0'),
            s_axi_wdata => (others => '0'),
            s_axi_araddr => (others => '0'),
            s_axi_rdata => open,
            s_axi_bready => '0',
            s_axi_awvalid => '0',
            s_axi_awready => open,
            s_axi_wvalid => '0',
            s_axi_wready => open,
            s_axi_bvalid => open,
            s_axi_arvalid => '0',
            s_axi_arready => open,
            s_axi_rvalid => open,
            s_axi_rready => '0',

            qpll_drpaddr_in => (others => '0'),
            qpll_drpdi_in => (others => '0'),
            qpll_drpdo_out => open,
            qpll_drprdy_out => open,
            qpll_drpen_in => '0',
            qpll_drpwe_in => '0',
            qpll_drpdo_out_quad1 => open,
            qpll_drprdy_out_quad1 => open,
            qpll_drpen_in_quad1 => '0',
            qpll_drpwe_in_quad1 => '0',

            -- Common Transceiver Ports
            gt_pll_lock => open,
            gt_qpllclk_quad1_out => open,
            gt_qpllrefclk_quad1_out => open,
            gt_qpllclk_quad7_out => open,
            gt_qpllrefclk_quad7_out => open,
            gt_rxcdrovrden_in => '0',
            gt_reset_out => open,
            gt_refclk1_out => open
        );

    s_axi_send1_tdata  <= m_axi_recv1_tdata;
    s_axi_send1_tkeep  <= m_axi_recv1_tkeep;
    s_axi_send1_tvalid <= m_axi_recv1_tvalid;
    s_axi_send1_tlast  <= m_axi_recv1_tlast;
    m_axi_recv1_tready <= s_axi_send1_tready;

    simulated_error : process(error_enabled, crc_valid0, crc_valid1, crc_pass_fail_n0, crc_pass_fail_n1, clk_0, clk_1)
        variable error_n0 : std_logic := '1';
        variable error_n1 : std_logic := '1';
        variable count_e0 : integer := 0;
        variable count_e1 : integer := 0;
    begin
        if (error_enabled = '1') then
            crc_pass_fail_n0_l <= crc_pass_fail_n0 and error_n0;
            crc_pass_fail_n1_l <= crc_pass_fail_n1 and error_n1;

            if (rising_edge(clk_0) and crc_valid0 = '1') then
                error_n0 := '1';
                if (count_e0 = 7) then
                    error_n0 := '0';
                    count_e0 := 0;
                end if;
                count_e0 := count_e0 + 1;
            end if;

            if (rising_edge(clk_1) and crc_valid1 = '1') then
                error_n1 := '1';
                if (count_e1 = 7) then
                    error_n1 := '0';
                    count_e1 := 0;
                end if;
                count_e1 := count_e1 + 1;
            end if;
        else
            crc_pass_fail_n0_l <= crc_pass_fail_n0;
            crc_pass_fail_n1_l <= crc_pass_fail_n1;
        end if;
    end process;

    init_p : process
        function random_packet return packet_t is
            variable seed1 : positive;
            variable seed2 : positive;
            variable re1 : integer;
            variable re2 : real;
            variable packet : packet_t;
        begin

            for i in 0 to 8 loop
                uniform (seed1, seed2, re2);
                re1 := integer(re2 * real(2**30 -1));
                packet(i) := std_logic_vector(to_unsigned (re1,64));
            end loop;
            return packet;
        end random_packet;
    begin
        -- Generate random packets
        for i in 0 to 100 loop
            packets(i) <= random_packet;
        end loop;
        wait;
    end process;

    send_process : process(clk_0)
        variable count : integer := 0;
        variable packet : integer range 0 to 100 := 0;
    begin
        if (rst_n0 = '0') then
            s_axi_send0_tdata <= x"0000000000000000";
            s_axi_send0_tdata <= (others => '0');
            s_axi_send0_tlast <= '0';
            count := 0;
            packet := 0;
            sent_count <= 0;
        elsif (rising_edge(clk_0)) then
            if (s_axi_send0_tvalid = '1' and s_axi_send0_tready = '1') then
                count := count+1;
            end if;

            if (count = 9) then
                count := 0;
                packet := packet + 1;
                sent_count <= sent_count + 1;
                if (packet = 101) then
                    packet := 0;
                end if;
            end if;

            s_axi_send0_tlast  <= '0';
            s_axi_send0_tdata <= packets(packet)(count);


            if (count = 8) then
                s_axi_send0_tlast <= '1';
            end if;
        end if;
    end process;

    receive_process : process(clk_0)
        variable count : integer := 0;
        variable packet : integer range 0 to 100 := 0;
    begin
        if (rst_n0 = '0') then
            count := 0;
            packet := 0;
            recv_count <= 0;
        elsif (rising_edge(clk_0)) then
            if (count = 9) then
                count := 0;
            end if;

            if (m_axi_recv0_tready = '1' and m_axi_recv0_tvalid = '1') then
                assert (m_axi_recv0_tdata = packets(packet)(count))
                    report "Bad response packet"
                    severity failure;
                if (count = 8) then
                    assert (m_axi_recv0_tlast = '1')
                        report "Tlast should be 1"
                        severity failure;
                else
                    assert (m_axi_recv0_tlast = '0')
                        report "Tlast should be 0"
                        severity failure;
                end if;
                count := count+1;
                if (count = 9) then
                    count := 0;
                    packet := packet + 1;
                    recv_count <= recv_count + 1;
                    if (packet = 101) then
                        packet := 0;
                    end if;
                end if;

            end if;
        end if;
    end process;

    test : process
    begin
        -- Set initial values
        s_axi_send0_tkeep    <= (others => '0');
        s_axi_send0_tvalid   <= '0';
        m_axi_recv0_tready <= '0';
        error_enabled <= '0';
        wait for 26 us;

        -- Ready to send
        report "Getting ready to receive";
        m_axi_recv0_tready <= '1';
        wait for 1 * clk_period;

        -- Send Packet
        report "Sending packets";
        s_axi_send0_tkeep <= (others => '1');
        s_axi_send0_tvalid <= '1';


        wait until sent_count = 100;
        report "Done Sending";
        s_axi_send0_tvalid <= '0';

        wait until recv_count = 100;
        report "Done recieving";

        wait for 10 * clk_period;

        report "Send Packets with errors";
        error_enabled <= '1';
        s_axi_send0_tvalid <= '1';
        wait until sent_count = 200;
        report "Done Sending";
        s_axi_send0_tvalid <= '0';

        wait until recv_count = 200;
        report "Done recieving";

        report "Simulation Finished";
        stop(2);
    end process;

end testbench;
