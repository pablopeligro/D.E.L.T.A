library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSM_Controlador is
    Port (
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC;
        nivel_agua      : in  STD_LOGIC;
        temp_actual     : in  STD_LOGIC_VECTOR(7 downto 0);
        temp_objetivo   : in  STD_LOGIC_VECTOR(7 downto 0);
        peltier_pwm_val : out STD_LOGIC_VECTOR(7 downto 0);
        peltier_dir_A   : out STD_LOGIC;
        peltier_dir_B   : out STD_LOGIC;
        motor_agitador  : out STD_LOGIC;
        led_alarma      : out STD_LOGIC
    );
end FSM_Controlador;

architecture Behavioral of FSM_Controlador is

    type estado_t is (SEGURO, EVALUANDO, CALENTANDO, ENFRIANDO);
    signal estado_actual, estado_siguiente : estado_t;

begin

    -- Registro de estado
    process(clk, rst)
    begin
        if rst = '1' then
            estado_actual <= SEGURO;
        elsif rising_edge(clk) then
            estado_actual <= estado_siguiente;
        end if;
    end process;

    -- Lógica de transición y salidas
    process(estado_actual, nivel_agua, temp_actual, temp_objetivo)
        variable t_act : integer;
        variable t_obj : integer;
    begin
        -- Valores por defecto
        peltier_pwm_val <= x"00";
        peltier_dir_A   <= '0';
        peltier_dir_B   <= '0';
        motor_agitador  <= '0';
        led_alarma      <= '0';
        estado_siguiente <= estado_actual;
        
        t_act := to_integer(unsigned(temp_actual));
        t_obj := to_integer(unsigned(temp_objetivo));

        -- Siempre que falte agua o haya error, forzamos SEGURO
        if nivel_agua = '0' then
            estado_siguiente <= SEGURO;
            led_alarma <= '1';
        else
            case estado_actual is
                when SEGURO =>
                    led_alarma <= '1';
                    if nivel_agua = '1' then
                        estado_siguiente <= EVALUANDO;
                    end if;

                when EVALUANDO =>
                    motor_agitador <= '1'; -- La bomba de agua arranca
                    if t_act < (t_obj - 1) then
                        estado_siguiente <= CALENTANDO;
                    elsif t_act > (t_obj + 1) then
                        estado_siguiente <= ENFRIANDO;
                    end if;

                when CALENTANDO =>
                    motor_agitador <= '1';
                    peltier_dir_A  <= '1';
                    peltier_dir_B  <= '0';
                    peltier_pwm_val <= x"FF"; -- 100% de potencia
                    if t_act >= t_obj then
                        estado_siguiente <= EVALUANDO;
                    end if;

                when ENFRIANDO =>
                    motor_agitador <= '1';
                    peltier_dir_A  <= '0';
                    peltier_dir_B  <= '1';
                    peltier_pwm_val <= x"FF"; -- 100% de potencia
                    if t_act <= t_obj then
                        estado_siguiente <= EVALUANDO;
                    end if;
            end case;
        end if;
    end process;

end Behavioral;