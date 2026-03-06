-- File: button_debouncer.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_debouncer is
    port(
        clk_50mhz   : in  std_logic;
        reset_n     : in  std_logic;
        button_in   : in  std_logic; -- Raw, active-low button input
        button_out  : out std_logic  -- Debounced, active-high output
    );
end entity;

architecture rtl of button_debouncer is
    -- 20ms debounce time @ 50MHz = 1000000 cycles
    constant DEBOUNCE_LIMIT : integer := 1000000;
    signal counter          : integer range 0 to DEBOUNCE_LIMIT := 0;
    signal stable_state     : std_logic := '1';
    signal debounced_level  : std_logic := '1';
begin

    process(clk_50mhz, reset_n)
    begin
        if reset_n = '0' then
            stable_state    <= '1';
            debounced_level <= '1';
            counter         <= 0;
        elsif rising_edge(clk_50mhz) then
            if button_in = stable_state then
                -- Button state matches stable state, reset counter
                counter <= 0;
            else
                -- Button state has changed, start counting
                if counter = DEBOUNCE_LIMIT then
                    -- Timer expired, update the stable state
                    stable_state <= button_in;
                    counter      <= 0;
                else
                    counter <= counter + 1;
                end if;
            end if;
            
            -- Update the final output level
            debounced_level <= stable_state;
        end if;
    end process;
    
    -- Invert the active-low stable state to create an active-high output
    -- '1' = pressed, '0' = released
    button_out <= not debounced_level;

end architecture;