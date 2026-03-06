library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Main_Control_FSM is
    Port (
        clk                  : in  std_logic;
        reset                : in  std_logic;
        fall_trigger         : in  std_logic;
        cancel_button_pressed: in  std_logic;
        countdown_finished   : in  std_logic;

        start_countdown      : out std_logic;
        enable_alarm_leds    : out std_logic;
        reset_timer          : out std_logic
    );
end Main_Control_FSM;

architecture Behavioral of Main_Control_FSM is

    -- Define the states
    type state_type is (STATE_MONITORING, STATE_COUNTDOWN, STATE_ALARM, STATE_RESET);
    signal current_state, next_state : state_type;

begin

    ------------------------------------------------------------------------
    -- Sequential process: State Register
    ------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= STATE_MONITORING;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Combinational process: Next State Logic and Outputs
    ------------------------------------------------------------------------
    process(current_state, fall_trigger, cancel_button_pressed, countdown_finished)
    begin
        -- Default outputs (prevent latches)
        start_countdown   <= '0';
        enable_alarm_leds <= '0';
        reset_timer       <= '0';
        next_state        <= current_state;

        case current_state is

            ----------------------------------------------------------------
            when STATE_MONITORING =>
                if fall_trigger = '1' then
                    next_state <= STATE_COUNTDOWN;
                    start_countdown <= '1';
                end if;

            ----------------------------------------------------------------
            when STATE_COUNTDOWN =>
                if cancel_button_pressed = '1' then
                    next_state <= STATE_RESET;
                elsif countdown_finished = '1' then
                    next_state <= STATE_ALARM;
                end if;

            ----------------------------------------------------------------
            when STATE_ALARM =>
                enable_alarm_leds <= '1';
                if cancel_button_pressed = '1' then
                    next_state <= STATE_RESET;
                end if;

            ----------------------------------------------------------------
            when STATE_RESET =>
                reset_timer <= '1';
                next_state <= STATE_MONITORING;

            ----------------------------------------------------------------
            when others => -- @suppress "Unexpected 'others' choice, case statement covers all choices explicitly"
                next_state <= STATE_MONITORING;
        end case;
    end process;

end Behavioral;