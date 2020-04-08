----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name:
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description: Buffer to be used for sliding window
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity window_buffer is
    generic (
        FRAME_WIDTH  : positive := 520;
        PACKET_SELECT_BITS : positive := 4
    );
    port (
        clk       : in std_logic;
        rst_n     : in std_logic;

        -- Write
        wr_tdata  :  in  std_logic_vector(FRAME_WIDTH - 1 downto 0);
        wr_tvalid :  in  std_logic;
        wr_tkeep  :  in  std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

        -- Read
        rd_tdata  :  out std_logic_vector(FRAME_WIDTH - 1 downto 0);
        rd_tvalid :  out std_logic;
        rd_tkeep  :  out std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

        -- Control signals
        packet    :  in  std_logic_vector(PACKET_SELECT_BITS - 1 downto 0);
        drop      :  in  std_logic;

        -- Status signals
        count     :  out std_logic_vector(PACKET_SELECT_BITS downto 0);
        full      :  out std_logic;
        empty     :  out std_logic
    );
end window_buffer;

architecture Behavioral of window_buffer is

    constant FRAME_DEPTH : positive := 2**PACKET_SELECT_BITS;
    type window_memory_t is array (0 to FRAME_DEPTH - 1) of std_logic_vector(FRAME_WIDTH - 1 downto 0);
    type keep_memory_t is array (0 to FRAME_DEPTH - 1) of std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

    signal window_memory : window_memory_t;
    signal keep_memory : keep_memory_t;
    signal count_i : std_logic_vector(PACKET_SELECT_BITS downto 0);

    signal p_start : std_logic_vector(PACKET_SELECT_BITS-1 downto 0);
    signal p_end   : std_logic_vector(PACKET_SELECT_BITS-1 downto 0);
    signal p_ptr   : std_logic_vector(PACKET_SELECT_BITS-1 downto 0);
    signal empty_i : std_logic;
    signal full_i  : std_logic;

begin
    -- Assign output signals
    full <= full_i;
    empty <= empty_i;
    count <= count_i;

    -- Set the signals
    full_i <= '1' when rst_n = '0' or (p_start = p_end and unsigned(count_i) /= 0) else '0';
    empty_i <= '1' when rst_n = '1' and (p_start = p_end and unsigned(count_i) = 0) else '0';

    -- Always output selected packet
    p_ptr <= std_logic_vector(unsigned(p_start) + unsigned(packet));
    rd_tdata <= window_memory(to_integer(unsigned(p_ptr)));
    rd_tkeep <= keep_memory(to_integer(unsigned(p_ptr)));
    rd_tvalid <= '1' when unsigned(packet) < unsigned(count_i) else '0';

    -- Control the functionality of the memory
    mem_func : process(clk, rst_n)
        variable count_v : std_logic_vector(PACKET_SELECT_BITS downto 0);
    begin
        if (rst_n = '0') then
            -- All of the pointers start at the beginning
            p_start <= (others => '0');
            p_end <= (others => '0');
            count_v := (others => '0');
            count_i <= (others => '0');
            window_memory (0 to FRAME_DEPTH - 1) <= (others => (others => '0'));
            keep_memory   (0 to FRAME_DEPTH - 1) <= (others => (others => '0'));

        elsif (rising_edge(clk)) then
            -- Push data when write is valid
            if (wr_tvalid = '1' and full_i = '0') then
                window_memory(to_integer(unsigned(p_end))) <= wr_tdata;
                keep_memory(to_integer(unsigned(p_end))) <= wr_tkeep;
                p_end <= std_logic_vector(unsigned(p_end) + 1);
                count_v := std_logic_vector(unsigned(count_v) + 1);
            end if;

            -- Drop packets when drop signal is asserted
            if (drop = '1' and empty_i = '0') then
                p_start <= std_logic_vector(unsigned(p_start) + 1);
                count_v := std_logic_vector(unsigned(count_v) - 1);
            end if;
            count_i <= count_v;
        end if;
    end process;
end Behavioral;
-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
