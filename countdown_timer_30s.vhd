-- File: countdown_timer_30s.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity countdown_timer_30s is
    port(
        clk_50mhz   : in  std_logic;
        reset_n     : in  std_logic;
        
        -- Control signals from Main_Control_FSM (Block 3)
        start_pulse : in  std_logic; -- 1-cycle pulse to start
        reset_pulse : in  std_logic; -- 1-cycle pulse to reset
        
        -- Outputs
        seconds_count : out integer range 0 to 30;
        is_counting   : out std_logic;
        finished_pulse: out std_logic
    );
end entity;

architecture rtl of countdown_timer_30s is
    -- 50,000,000 cycles = 1 second @ 50MHz
    constant ONE_SECOND_COUNT : integer := 49999999;
    signal clk_divider        : integer range 0 to ONE_SECOND_COUNT;
    signal clk_1hz_enable     : std_logic;
    
    type state_type is (S_IDLE, S_COUNTING);
    signal current_state : state_type := S_IDLE;
    
    signal seconds_internal : integer range 0 to 30 := 30;

begin

    -- 1Hz Clock Enable Generator
    process(clk_50mhz, reset_n)
    begin
        if reset_n = '0' then
            clk_divider    <= 0;
            clk_1hz_enable <= '0';
        elsif rising_edge(clk_50mhz) then
            if clk_divider = ONE_SECOND_COUNT then
                clk_divider    <= 0;
                clk_1hz_enable <= '1';
            else
                clk_divider    <= clk_divider + 1;
                clk_1hz_enable <= '0';
            end if;
        end if;
    end process;


    -- Timer FSM and Counter
    process(clk_50mhz, reset_n)
    begin
        if reset_n = '0' then
            current_state      <= S_IDLE;
            seconds_internal   <= 30;
            finished_pulse     <= '0';
            is_counting        <= '0';
        elsif rising_edge(clk_50mhz) then
            -- Default: clear the pulse
            finished_pulse <= '0';
            
            -- Priority 1: Synchronous 1-cycle reset from FSM
            if reset_pulse = '1' then
                current_state    <= S_IDLE;
                seconds_internal <= 30;
                is_counting      <= '0';
                
            -- Priority 2: Synchronous 1-cycle start from FSM
            elsif start_pulse = '1' then
                current_state    <= S_COUNTING;
                seconds_internal <= 30;
                is_counting      <= '1';

            -- Priority 3: Normal 1Hz operation
            elsif clk_1hz_enable = '1' then
                if current_state = S_COUNTING then
                    if seconds_internal > 0 then
                        seconds_internal <= seconds_internal - 1;
                    else -- We are at 0
                        current_state    <= S_IDLE;
                        is_counting      <= '0';
                        finished_pulse   <= '1'; -- Fire the 1-cycle finished pulse
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Assign final output
    seconds_count <= seconds_internal;

end architecture;