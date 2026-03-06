library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fall_pkg is

    
    -------------------------------------------------------------------------
    -- Free-fall threshold (matches comment): 3500
    constant FREE_FALL_THRESHOLD : unsigned(31 downto 0) := to_unsigned(1500, 32);
    
    
    -- Impact threshold (matches comment): 4500
    constant IMPACT_THRESHOLD    : unsigned(31 downto 0) := to_unsigned(7000, 32);

end package fall_pkg;