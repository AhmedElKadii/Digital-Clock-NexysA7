library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock is
    port(
        clk    : in  std_logic;                -- 100 MHz
        btnRst : in  std_logic;
        btnSel : in  std_logic;
        btnInc : in  std_logic;
        seg    : out std_logic_vector(6 to 0); -- active low
        an     : out std_logic_vector(7 downto 0)  -- active low
    );
end entity;

architecture myArch of clock is

    type selState is (NONE, HOUR_SEL, MIN_SEL);
    signal currentState : selState := NONE;

    -- 1 second tick @ 100 MHz
    constant SEC_COUNT : unsigned(26 downto 0)
        := to_unsigned(99_999_999, 27);

    signal sec_cnt   : unsigned(26 downto 0) := (others => '0');

    signal secPulse  : unsigned(5 downto 0) := (others => '0');
    signal minPulse  : unsigned(5 downto 0) := (others => '0');
    signal hourPulse : unsigned(4 downto 0) := (others => '0');

    -- Display mux
    signal mux_cnt   : unsigned(18 downto 0) := (others => '0');
    signal digit_sel : unsigned(2 downto 0);
    signal digit_val : unsigned(3 downto 0);

begin
    ----------------------------------------------------------------
    -- Timekeeping + buttons (SYNC RESET)
    ----------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if btnRst = '1' then
                sec_cnt      <= (others => '0');
                secPulse     <= (others => '0');
                minPulse     <= (others => '0');
                hourPulse    <= (others => '0');
                currentState <= NONE;
            else
                -- Mode select
                if btnSel = '1' then
                    case currentState is
                        when NONE     => currentState <= HOUR_SEL;
                        when HOUR_SEL => currentState <= MIN_SEL;
                        when MIN_SEL  => currentState <= NONE;
                    end case;
                end if;

                -- Increment
                if btnInc = '1' then
                    case currentState is
                        when HOUR_SEL =>
                            hourPulse <= (hourPulse + 1) mod 24;
                        when MIN_SEL =>
                            minPulse  <= (minPulse + 1) mod 60;
                        when others =>
                            null;
                    end case;
                end if;

                -- 1 second tick
                if sec_cnt = SEC_COUNT then
                    sec_cnt <= (others => '0');

                    if secPulse = 59 then
                        secPulse <= (others => '0');
                        if minPulse = 59 then
                            minPulse <= (others => '0');
                            hourPulse <= (hourPulse + 1) mod 24;
                        else
                            minPulse <= minPulse + 1;
                        end if;
                    else
                        secPulse <= secPulse + 1;
                    end if;
                else
                    sec_cnt <= sec_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Display multiplex counter (~1 kHz refresh)
    ----------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            mux_cnt <= mux_cnt + 1;
        end if;
    end process;

    digit_sel <= mux_cnt(18 downto 16); -- 0..7

    ----------------------------------------------------------------
    -- Digit decode
    ----------------------------------------------------------------
    process(hourPulse, minPulse, secPulse, digit_sel)
        variable h, m, s : integer;
    begin
        h := to_integer(hourPulse);
        m := to_integer(minPulse);
        s := to_integer(secPulse);

        case digit_sel is
            when "000" => digit_val <= to_unsigned(h / 10, 4);
            when "001" => digit_val <= to_unsigned(h mod 10, 4);
            when "010" => digit_val <= to_unsigned(m / 10, 4);
            when "011" => digit_val <= to_unsigned(m mod 10, 4);
            when "100" => digit_val <= to_unsigned(s / 10, 4);
            when "101" => digit_val <= to_unsigned(s mod 10, 4);
            when others => digit_val <= (others => '0');
        end case;
    end process;

    ----------------------------------------------------------------
    -- 7-segment decoder (CA..CG, active low)
    ----------------------------------------------------------------
    process(digit_val)
    begin
        case digit_val is
            when "0000" => seg <= "0000001";
            when "0001" => seg <= "1001111";
            when "0010" => seg <= "0010010";
            when "0011" => seg <= "0000110";
            when "0100" => seg <= "1001100";
            when "0101" => seg <= "0100100";
            when "0110" => seg <= "0100000";
            when "0111" => seg <= "0001111";
            when "1000" => seg <= "0000000";
            when "1001" => seg <= "0000100";
            when others => seg <= "1111111";
        end case;
    end process;

    ----------------------------------------------------------------
    -- Anode control (AN7..AN0, active low)
    ----------------------------------------------------------------
    process(digit_sel)
    begin
        an <= "11111111";
        case digit_sel is
            when "000" => an <= "11101111"; -- H tens
            when "001" => an <= "11011111"; -- H ones
            when "010" => an <= "10111111"; -- M tens
            when "011" => an <= "01111111"; -- M ones
            when "100" => an <= "11111110"; -- S tens
            when "101" => an <= "11111101"; -- S ones
            when others => null;
        end case;
    end process;

end architecture;
