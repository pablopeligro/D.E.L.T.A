library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Generador_PWM is
    generic (PREDIVISOR : integer := 160);
    Port (
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        duty_cycle : in  STD_LOGIC_VECTOR(7 downto 0);
        pwm_out    : out STD_LOGIC
    );
end Generador_PWM;

architecture Behavioral of Generador_PWM is
    signal contador_ciclos : integer range 0 to PREDIVISOR - 1 := 0;
    signal tick_pwm        : STD_LOGIC := '0';
    signal contador_pwm    : unsigned(7 downto 0) := (others => '0');
begin

    -- Divisor de reloj
    process(clk, rst)
    begin
        if rst = '1' then
            contador_ciclos <= 0;
            tick_pwm <= '0';
        elsif rising_edge(clk) then
            if contador_ciclos = PREDIVISOR - 1 then
                contador_ciclos <= 0;
                tick_pwm <= '1';
            else
                contador_ciclos <= contador_ciclos + 1;
                tick_pwm <= '0';
            end if;
        end if;
    end process;

    -- Contador PWM y comparador
    process(clk, rst)
    begin
        if rst = '1' then
            contador_pwm <= (others => '0');
            pwm_out <= '0';
        elsif rising_edge(clk) then
            if tick_pwm = '1' then
                contador_pwm <= contador_pwm + 1;
                
                if contador_pwm < unsigned(duty_cycle) then
                    pwm_out <= '1';
                else
                    pwm_out <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;