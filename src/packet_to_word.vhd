----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name: Packet to Word
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description: used to convert a packet into multiple words. Assumes each
-- packet is a frame.
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

entity packet_to_word is
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
end packet_to_word;

architecture Behavioral of packet_to_word is

    -- Derived constants from generics
    constant WORDS_IN_FRAME : positive := FRAME_SIZE/WORD_SIZE;
    constant FRAME_KEEP_BITS : positive := (integer(FRAME_SIZE) / 8);
    constant WORD_KEEP_BITS : positive := (integer(WORD_SIZE) / 8);

    -- State variables
    type state_t is (STATE_READY, STATE_SENDING);
    signal state : state_t;

    -- Storage for the packet
    type axis_frame_t is array (0 to WORDS_IN_FRAME-1) of std_logic_vector(WORD_SIZE - 1 downto 0);
    type axis_frame_keep_t is array (0 to WORDS_IN_FRAME-1) of std_logic_vector(WORD_KEEP_BITS - 1 downto 0);
    signal axis_frame : axis_frame_t;
    signal axis_frame_keep : axis_frame_keep_t;

    -- Word location being sent out.
    signal word_loc      : integer range 0 to WORDS_IN_FRAME-1;

    -- Number or words in the current packet
    signal words_in_curr : integer range 0 to WORDS_IN_FRAME;

begin

    -- Process to drive axi output based on state and word location.
    output_combinatorial : process (rst_n, state, word_loc)
    begin
        if (rst_n = '0') then
            m_axi_tdata <= (others => '0');
            m_axi_tvalid <= '0';
            m_axi_tkeep <= (others => '0');
            m_axi_tlast <= '0';
            s_axi_tready <= '0';
        else
            case state is
                -- Ready for next packet when in the ready state
                when STATE_READY =>
                    s_axi_tready <= '1';
                    m_axi_tdata <= (others => '0');
                    m_axi_tvalid <= '0';
                    m_axi_tkeep <= (others => '0');
                    m_axi_tlast <= '0';

                -- Output the word when sending
                when STATE_SENDING =>
                    s_axi_tready <= '0';
                    m_axi_tdata <= axis_frame(word_loc);
                    m_axi_tvalid <= '1';
                    m_axi_tkeep <= axis_frame_keep(word_loc);

                    -- tlast when on the last word
                    if (word_loc = words_in_curr-1) then
                        m_axi_tlast <= '1';
                    else
                        m_axi_tlast <= '0';
                    end if;
            end case;
        end if;
    end process;

    -- State machine to shift through the words.
    shifter_state : process(clk, rst_n)
        -- Variable to calculate the number of words in the current packet.
        variable words_in_curr_v : integer range 0 to WORDS_IN_FRAME;
    begin
        if (rst_n = '0') then
            state <= STATE_READY;

            for i in 0 to WORDS_IN_FRAME-1 loop
                axis_frame(i) <= (others => '0');
            end loop;

            word_loc <= 0;
            words_in_curr <= 0;

        elsif (rising_edge(clk)) then
            case state is

                when STATE_READY =>
                    word_loc <= 0;
                    -- When the packet is valid read it in.
                    if (s_axi_tvalid = '1') then
                        words_in_curr_v := 0;
                        -- Store all of the words.
                        for i in 0 to WORDS_IN_FRAME-1 loop
                            axis_frame(i)      <= s_axi_tdata((i+1) * WORD_SIZE - 1      downto i*WORD_SIZE);
                            axis_frame_keep(i) <= s_axi_tkeep((i+1) * WORD_KEEP_BITS - 1 downto i*WORD_KEEP_BITS);
                            -- Calculate the number of words in the frame by
                            -- adding 1 when tkeep is not 0x00. This assumes that
                            -- the unused words will be at the back of the packet.
                            if (s_axi_tkeep((i+1) * WORD_KEEP_BITS - 1 downto i*WORD_KEEP_BITS) /= std_logic_vector(to_unsigned(0,WORD_KEEP_BITS))) then
                                words_in_curr_v := words_in_curr_v + 1;
                            end if;
                        end loop;
                        words_in_curr <= words_in_curr_v;
                        state <= STATE_SENDING;
                    end if;

                when STATE_SENDING =>
                    -- Move to the next word when the receiver is ready.
                    if (m_axi_tready = '1') then
                        -- Last word so go back to the ready state.
                        if (word_loc = words_in_curr-1) then
                            state <= STATE_READY;
                            word_loc <= 0;
                        else
                            word_loc <= word_loc + 1;
                        end if;
                    end if;
            end case;
        end if;
    end process;
end Behavioral;
-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
