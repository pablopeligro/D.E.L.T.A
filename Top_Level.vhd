----------------------------------------------------------------------------------
-- Module Name: Top_Level - Estructural
-- Description: Prueba Unitaria - Bomba y Boya
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Top_Level is
    Port (
        CLK_50MHz   : in  STD_LOGIC;
        BTNC        : in  STD_LOGIC;
        SW          : in  STD_LOGIC_VECTOR(15 downto 0);
        
        -- Pines del MAX6675 (Aunque esté desconectado, los dejamos para que no dé error)
        max6675_so  : in  STD_LOGIC;  
        max6675_cs  : out STD_LOGIC;  
        max6675_sck : out STD_LOGIC;  

        -- Actuadores y Sensores Físicos extras
        sensor_boya : in  STD_LOGIC; -- Boya en JB7
        bomba_out   : out STD_LOGIC; -- MOSFET de la Bomba en JA1
        
        -- Display
        SEG         : out STD_LOGIC_VECTOR(6 downto 0);
        AN          : out STD_LOGIC_VECTOR(3 downto 0);
        DP          : out STD_LOGIC;

        -- Leds
        LED         : out STD_LOGIC_VECTOR(15 downto 0)
    );
end Top_Level;

architecture Estructural of Top_Level is

    component FSM_Controlador is
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
    end component;

    component Generador_PWM is
        generic (PREDIVISOR : integer := 160);
        Port (
            clk        : in  STD_LOGIC;
            rst        : in  STD_LOGIC;
            duty_cycle : in  STD_LOGIC_VECTOR(7 downto 0);
            pwm_out    : out STD_LOGIC
        );
    end component;

    component Display_7Seg is
        Port (
            clk  : in  STD_LOGIC;
            rst  : in  STD_LOGIC;
            dig3 : in  STD_LOGIC_VECTOR(3 downto 0);
            dig2 : in  STD_LOGIC_VECTOR(3 downto 0);
            dig1 : in  STD_LOGIC_VECTOR(3 downto 0);
            dig0 : in  STD_LOGIC_VECTOR(3 downto 0);
            seg  : out STD_LOGIC_VECTOR(6 downto 0);
            an   : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

    -- Señales SPI
    type estado_spi_t is (IDLE, BAJAR_CS, PULSOS_SCK, SUBIR_CS);
    signal estado_spi : estado_spi_t := IDLE;
    constant PERIODO_LECTURA : integer := 50_000_000;
    signal cuenta_tiempo     : integer range 0 to PERIODO_LECTURA := 0;
    signal bit_cnt           : integer range 0 to 15 := 0;
    signal sck_cnt           : integer range 0 to 50 := 0;
    signal shift_reg         : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal temp_actual_real  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal error_tc          : STD_LOGIC := '0';

    -- Señales de control
    signal temp_objetivo_sw : STD_LOGIC_VECTOR(7 downto 0);
    signal pwm_val_interno  : STD_LOGIC_VECTOR(7 downto 0);
    signal pwm_fisico       : STD_LOGIC;  
    signal dir_A_sig        : STD_LOGIC;
    signal dir_B_sig        : STD_LOGIC;
    signal motor_sig        : STD_LOGIC;
    signal alarma_sig       : STD_LOGIC;
    
    signal alarma_global    : STD_LOGIC;
    signal agua_segura      : STD_LOGIC; 

    signal act_decenas  : STD_LOGIC_VECTOR(3 downto 0);
    signal act_unidades : STD_LOGIC_VECTOR(3 downto 0);
    signal obj_decenas  : STD_LOGIC_VECTOR(3 downto 0);
    signal obj_unidades : STD_LOGIC_VECTOR(3 downto 0);

begin

    temp_objetivo_sw <= "0" & SW(14 downto 8);
    DP <= '1';
    
    process(CLK_50MHz)
        variable temp_int : integer;
    begin
        if rising_edge(CLK_50MHz) then
            if BTNC = '1' then
                estado_spi <= IDLE;
                max6675_cs  <= '1';
                max6675_sck <= '0';
                error_tc <= '0';
                temp_actual_real <= (others => '0');
                cuenta_tiempo <= 0;
            else
                case estado_spi is
                    when IDLE =>
                        max6675_cs  <= '1';
                        max6675_sck <= '0';
                        if cuenta_tiempo = PERIODO_LECTURA then
                            cuenta_tiempo <= 0;
                            estado_spi <= BAJAR_CS;
                        else
                            cuenta_tiempo <= cuenta_tiempo + 1;
                        end if;

                    when BAJAR_CS =>
                        max6675_cs <= '0';       
                        sck_cnt <= 0;
                        bit_cnt <= 15;
                        estado_spi <= PULSOS_SCK;

                    when PULSOS_SCK =>
                        max6675_cs <= '0';
                        if sck_cnt = 25 then
                            max6675_sck <= '1';  
                            shift_reg(bit_cnt) <= max6675_so;
                            sck_cnt <= sck_cnt + 1;
                        elsif sck_cnt = 50 then
                            max6675_sck <= '0';  
                            sck_cnt <= 0;
                            if bit_cnt = 0 then
                                estado_spi <= SUBIR_CS;
                            else
                                bit_cnt <= bit_cnt - 1;
                            end if;
                        else
                            sck_cnt <= sck_cnt + 1;
                        end if;

                    when SUBIR_CS =>
                        max6675_cs <= '1'; 
                        error_tc <= shift_reg(2);
                        temp_int := to_integer(unsigned(shift_reg(14 downto 5)));
                        if temp_int > 99 then
                            temp_actual_real <= std_logic_vector(to_unsigned(99, 8));
                        else
                            temp_actual_real <= std_logic_vector(to_unsigned(temp_int, 8));
                        end if;
                        estado_spi <= IDLE;
                end case;
            end if;
        end if;
    end process;

    -- ── ¡BYPASS DE SEGURIDAD PARA LA PRUEBA UNITARIA! ──
    -- Ignoramos si el termopar está desconectado. Solo hacemos caso a la boya.
    agua_segura <= sensor_boya;

    -- ── CONEXIÓN AL PIN FÍSICO JA1 ──
    bomba_out <= motor_sig;

    -- LEDs
    LED(0)           <= alarma_sig;
    LED(1)           <= motor_sig;
    LED(2)           <= dir_A_sig;
    LED(3)           <= dir_B_sig;
    LED(6 downto 4)  <= (others => '0');
    LED(7)           <= sensor_boya; 
    LED(14 downto 8) <= (others => '0');
    LED(15)          <= error_tc; 

    process(temp_actual_real)
        variable v : integer range 0 to 127;
    begin
        v := to_integer(unsigned(temp_actual_real));
        if v > 99 then v := 99; end if;
        act_decenas  <= std_logic_vector(to_unsigned(v / 10, 4));
        act_unidades <= std_logic_vector(to_unsigned(v mod 10, 4));
    end process;

    process(temp_objetivo_sw)
        variable v : integer range 0 to 127;
    begin
        v := to_integer(unsigned(temp_objetivo_sw));
        if v > 99 then v := 99; end if;
        obj_decenas  <= std_logic_vector(to_unsigned(v / 10, 4));
        obj_unidades <= std_logic_vector(to_unsigned(v mod 10, 4));
    end process;

    Inst_FSM: FSM_Controlador
        port map (
            clk             => CLK_50MHz,
            rst             => BTNC,
            nivel_agua      => agua_segura,
            temp_actual     => temp_actual_real, 
            temp_objetivo   => temp_objetivo_sw,
            peltier_pwm_val => pwm_val_interno,
            peltier_dir_A   => dir_A_sig,
            peltier_dir_B   => dir_B_sig,
            motor_agitador  => motor_sig,
            led_alarma      => alarma_sig
        );

    Inst_PWM: Generador_PWM
        generic map (PREDIVISOR => 160)
        port map (
            clk        => CLK_50MHz,
            rst        => BTNC,
            duty_cycle => pwm_val_interno,
            pwm_out    => pwm_fisico
        );

    Inst_Display: Display_7Seg
        port map (
            clk  => CLK_50MHz,
            rst  => BTNC,
            dig3 => act_decenas,
            dig2 => act_unidades,
            dig1 => obj_decenas,
            dig0 => obj_unidades,
            seg  => SEG,
            an   => AN
        );

end Estructural;