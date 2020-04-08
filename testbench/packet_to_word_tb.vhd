library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use std.env.stop;

entity packet_to_word_tb is
    end packet_to_word_tb;

architecture testbench of packet_to_word_tb is
    component packet_to_word
    generic (
        FRAME_SIZE : positive := 512;
        WORD_SIZE  : positive := 64
    );
    port (
        clk                : in  std_logic;
        rst_n              : in  std_logic;

        s_axi_tdata        : in  std_logic_vector(FRAME_SIZE - 1 downto 0);
        s_axi_tkeep        : in  std_logic_vector((integer(FRAME_SIZE) / 8) - 1 downto 0);
        s_axi_tready       : out std_logic;
        s_axi_tvalid       : in  std_logic;
        s_axi_tlast        : in  std_logic;

        m_axi_tdata        : out std_logic_vector(WORD_SIZE - 1 downto 0);
        m_axi_tvalid       : out std_logic;
        m_axi_tready       : in  std_logic;
        m_axi_tkeep        : out std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
        m_axi_tlast        : out std_logic
    );
    end component;

    constant FRAME_SIZE : positive := 512+64;
    constant WORD_SIZE  : positive := 64;

    -- Inputs
    signal rst_n           : std_logic;

    signal s_axi_tdata        : std_logic_vector(FRAME_SIZE - 1 downto 0);
    signal s_axi_tkeep        : std_logic_vector((integer(FRAME_SIZE) / 8) - 1 downto 0);
    signal s_axi_tvalid       : std_logic;
    signal s_axi_tlast        : std_logic;
    signal m_axi_tready       : std_logic;

    -- Outputs
    signal s_axi_tready       : std_logic;
    signal m_axi_tdata        : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal m_axi_tvalid       : std_logic;
    signal m_axi_tkeep        : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal m_axi_tlast        : std_logic;

    -- Clock
    signal   clk : STD_LOGIC;
    constant clk_period : time := 10 ns;

begin
    clock : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    UUT : packet_to_word
    generic map (
        FRAME_SIZE => FRAME_SIZE,
        WORD_SIZE  => WORD_SIZE
    )
    port map (
        clk                => clk,
        rst_n              => rst_n,

        s_axi_tdata        => s_axi_tdata,
        s_axi_tkeep        => s_axi_tkeep,
        s_axi_tready       => s_axi_tready,
        s_axi_tvalid       => s_axi_tvalid,
        s_axi_tlast        => s_axi_tlast,

        m_axi_tdata        => m_axi_tdata,
        m_axi_tvalid       => m_axi_tvalid,
        m_axi_tready       => m_axi_tready,
        m_axi_tkeep        => m_axi_tkeep,
        m_axi_tlast        => m_axi_tlast
    );


    test : process

    begin
        -- Set initial values
        rst_n <= '1';
        s_axi_tdata <= (others => '0');
        s_axi_tkeep <= (others => '0');
        s_axi_tvalid <= '0';
        s_axi_tlast <= '0';
        m_axi_tready <= '0';

        -- Reset
        report "Sending reset";
        rst_n <= '1';
        wait for 1 * clk_period;
        rst_n <= '0';
        wait for 10 * clk_period;
        rst_n <= '1';
        wait for 1 * clk_period;

        m_axi_tready <= '1';
        wait for 1 * clk_period;

        -- Send full Packet
        s_axi_tkeep <= (others => '1');
        s_axi_tvalid <= '1';
        s_axi_tdata <= std_logic_vector(to_unsigned(1,FRAME_SIZE));
        s_axi_tlast <= '1';
        wait for 1 * clk_period;
        s_axi_tvalid <= '0';
        s_axi_tlast <= '0';
        wait for 1 * clk_period;
        wait for 30 * clk_period;

        -- Send Partial Packet
        s_axi_tkeep((integer(WORD_SIZE) / 8) - 1 downto 0) <= (others => '1');
        s_axi_tkeep((integer(FRAME_SIZE) / 8) - 1 downto (integer(WORD_SIZE) / 8)) <= (others => '0');
        s_axi_tvalid <= '1';
        s_axi_tdata <= std_logic_vector(to_unsigned(2,FRAME_SIZE));
        s_axi_tlast <= '1';
        wait for 1 * clk_period;
        s_axi_tvalid <= '0';
        s_axi_tlast <= '0';
        wait for 1 * clk_period;
        wait for 30 * clk_period;

        report "Simulation Finished";
        stop(0);
    end process;

end testbench;
