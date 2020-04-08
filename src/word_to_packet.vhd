----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name: Word to Packet
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description:
--   Used to convert multiple words into data packet.
--   Uses fall through to allow the frame to be available when tlast is high.
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity word_to_packet is
    generic (
        FRAME_SIZE : positive := 512;
        WORD_SIZE  : positive := 64
    );
    port (
        clk                : in  std_logic;
        rst_n              : in  std_logic;

        s_axi_tdata        : in  std_logic_vector(WORD_SIZE - 1 downto 0);
        s_axi_tkeep        : in  std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
        s_axi_tready       : out std_logic;
        s_axi_tvalid       : in  std_logic;
        s_axi_tlast        : in  std_logic;

        m_axi_tdata        : out std_logic_vector(FRAME_SIZE - 1 downto 0);
        m_axi_tvalid       : out std_logic;
        m_axi_tready       : in  std_logic;
        m_axi_tkeep        : out std_logic_vector((integer(FRAME_SIZE) / 8) - 1 downto 0);
        m_axi_tlast        : out std_logic
    );
end word_to_packet;

architecture Behavioral of word_to_packet is

    -- Derived constants from generics
    constant WORDS_IN_FRAME : positive := FRAME_SIZE/WORD_SIZE;
    constant KEEP_BITS : positive := (integer(FRAME_SIZE) / 8);

    signal ONE_WORD : std_logic_vector((integer(FRAME_SIZE)/8)-1 downto 0);

    -- Storage for the packet
    type axis_frame_t is array (0 to WORDS_IN_FRAME-1) of std_logic_vector(WORD_SIZE - 1 downto 0);
    signal axis_frame : axis_frame_t;

    -- Word location in the packet being read in
    signal word_loc         : integer range 0 to WORDS_IN_FRAME-1;

    -- Internal instance of tkeep
    signal m_axi_tkeep_i    : std_logic_vector((integer(FRAME_SIZE) / 8) - 1 downto 0);

begin

    -- Constant assignment of ONE_WORD
    ONE_WORD_P : process(clk)
    begin
        ONE_WORD <= (others => '0');
        ONE_WORD(WORD_SIZE/8-1 downto 0) <= (others => '1');
    end process;

    -- Generate the tdata line from the frame. The current word at word location is assigned directly.
    -- This fall through allows the width conversion to avoid adding a cycle delay.
    GEN_TDATA : for i in 0 to WORDS_IN_FRAME-1 generate
        m_axi_tdata((i+1) * WORD_SIZE - 1 downto i*WORD_SIZE) <= s_axi_tdata when word_loc = i else axis_frame(i);
    end generate GEN_TDATA;

    -- Pass through the axi signals other than tdata and tkeep
    m_axi_tvalid <= s_axi_tvalid and s_axi_tlast;
    m_axi_tlast  <= s_axi_tlast;
    s_axi_tready <= m_axi_tready;

    -- Set the tkeep signal
    m_axi_tkeep  <= m_axi_tkeep_i;

    -- State machine to shift the words into the frame.
    shifter_state : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            for i in 0 to WORDS_IN_FRAME-1 loop
                axis_frame(i) <= (others => '0');
            end loop;
            m_axi_tkeep_i <= ONE_WORD;
            word_loc <= 0;

        elsif (rising_edge(clk)) then
            -- If tvalid then shift in word
            if (s_axi_tvalid = '1') then
                -- Store the word into the frame.
                axis_frame(word_loc) <= s_axi_tdata;

                -- If it is the last word then start back at the beginning
                if (s_axi_tlast = '1') then
                    m_axi_tkeep_i <= ONE_WORD;
                    word_loc <= 0;

                -- If the memory is full, drop off of the front
                elsif (word_loc = WORDS_IN_FRAME-1) then
                    for i in 1 to WORDS_IN_FRAME-2 loop
                        axis_frame(i-1) <= axis_frame(i);
                    end loop;
                    axis_frame(WORDS_IN_FRAME-2) <= s_axi_tdata;

                -- Move to the next word location
                else
                    m_axi_tkeep_i <= m_axi_tkeep_i(KEEP_BITS - 8 - 1 downto 0) & x"ff";
                    word_loc <= word_loc + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
