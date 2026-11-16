----------------------------------------------------------------------------------
-- Module Name: Top_Level - Estructural
-- Description: Archivo principal del proyecto D.E.L.T.A.
--              Instancia y cablea todos los submódulos.
--              Marcar este archivo como "Top Module" en Vivado/Quartus.
--
-- Jerarquía de módulos:
--   Top_Level
--   ├── Antirrebote      (limpia la señal del sensor de boya)
--   ├── Lector_SPI       (lee temperatura del MCP3004 por SPI)
--   ├── FSM_Controlador  (máquina de estados principal)
--   └── Generador_PWM    (genera la señal PWM para el BTS7960)
--
-- Pines físicos que hay que asignar en el .xdc (Vivado) o .qsf (Quartus):
--   CLK_50MHz   → Pin del oscilador de la placa
--   RST_BTN     → Un botón de reset
--   SENSOR_NIVEL→ Pin conectado al sensor de boya
--   SPI_CS      → Pin GPIO → MCP3004 pin 1
--   SPI_CLK     → Pin GPIO → MCP3004 pin 10
--   SPI_MOSI    → Pin GPIO → MCP3004 pin 11
--   SPI_MISO    → Pin GPIO ← MCP3004 pin 12
--   PELTIER_PWM → Pin GPIO → BTS7960 (RPWM y LPWM juntos, o por separado)
--   PELTIER_R_EN→ Pin GPIO → BTS7960 R_EN (dirección A)
--   PELTIER_L_EN→ Pin GPIO → BTS7960 L_EN (dirección B)
--   MOTOR_AGUA  → Pin GPIO → Módulo MOSFET IRF520 (bomba/motor)
--   ALARM_LED   → LED de la placa
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Top_Level is
    Port (
        CLK_50MHz    : in  STD_LOGIC;
        RST_BTN      : in  STD_LOGIC;
        SENSOR_NIVEL : in  STD_LOGIC;

        -- Puerto SPI al MCP3004
        SPI_CS       : out STD_LOGIC;
        SPI_CLK      : out STD_LOGIC;
        SPI_MOSI     : out STD_LOGIC;
        SPI_MISO     : in  STD_LOGIC;

        -- Salidas físicas a los actuadores
        PELTIER_PWM  : out STD_LOGIC;
        PELTIER_R_EN : out STD_LOGIC;  -- Dir A al BTS7960
        PELTIER_L_EN : out STD_LOGIC;  -- Dir B al BTS7960
        MOTOR_AGUA   : out STD_LOGIC;
        ALARM_LED    : out STD_LOGIC
    );
end Top_Level;

architecture Estructural of Top_Level is

    -- ══════════════════════════════════════════════
    -- Declaración de los componentes (submódulos)
    -- ══════════════════════════════════════════════

    component Antirrebote is
        generic (LIMITE : integer := 500000);
        Port (
            clk      : in  STD_LOGIC;
            boton_in : in  STD_LOGIC;
            senal_out: out STD_LOGIC
        );
    end component;

    component Lector_SPI is
        generic (
            CLK_DIV   : integer := 25;
            INTERVALO : integer := 500000
        );
        Port (
            clk        : in  STD_LOGIC;
            rst        : in  STD_LOGIC;
            SPI_CS     : out STD_LOGIC;
            SPI_CLK    : out STD_LOGIC;
            SPI_MOSI   : out STD_LOGIC;
            SPI_MISO   : in  STD_LOGIC;
            dato_10bit : out STD_LOGIC_VECTOR(9 downto 0);
            temp_byte  : out STD_LOGIC_VECTOR(7 downto 0);
            dato_listo : out STD_LOGIC
        );
    end component;

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

    -- ══════════════════════════════════════════════
    -- Señales internas ("cables" entre módulos)
    -- ══════════════════════════════════════════════

    -- Salida limpia del antirrebote
    signal nivel_agua_limpio : STD_LOGIC;

    -- Temperatura leída por el SPI, ya escalada a 8 bits
    signal temp_actual_interna : STD_LOGIC_VECTOR(7 downto 0);

    -- Señal de nuevo dato disponible del SPI (no la usamos en la FSM
    -- porque la FSM lee temp_actual directamente, pero está disponible
    -- si en el futuro quieres sincronizar la lectura con el dato_listo)
    signal spi_dato_listo : STD_LOGIC;

    -- Resultado ADC crudo de 10 bits (útil para depuración)
    signal spi_dato_crudo : STD_LOGIC_VECTOR(9 downto 0);

    -- Valor de duty cycle que decide la FSM y consume el Generador_PWM
    signal valor_pwm_interno : STD_LOGIC_VECTOR(7 downto 0);

    -- Temperatura objetivo: aquí puedes conectarla a switches de la placa
    -- para pruebas, o fijarla a un valor constante (ej. 30°C = "00011110").
    -- Para un sistema real, vendrá de una interfaz de usuario (botonera, UART).
    signal temp_objetivo_interna : STD_LOGIC_VECTOR(7 downto 0) := "00011110"; -- 30°C

begin

    -- ══════════════════════════════════════════════
    -- Instancia 1: Antirrebote del sensor de nivel
    -- ══════════════════════════════════════════════
    -- Limpia los rebotes mecánicos del interruptor de boya.
    -- LIMITE = 500000 ciclos a 50MHz = 10ms de tiempo de estabilización.
    Inst_Antirrebote: Antirrebote
        generic map (LIMITE => 500000)
        port map (
            clk       => CLK_50MHz,
            boton_in  => SENSOR_NIVEL,
            senal_out => nivel_agua_limpio
        );

    -- ══════════════════════════════════════════════
    -- Instancia 2: Lector SPI del MCP3004
    -- ══════════════════════════════════════════════
    -- Lee el canal CH0 del ADC a 1 MHz de reloj SPI, cada 10ms.
    -- Produce temp_actual_interna en °C (escala 0-255).
    Inst_SPI: Lector_SPI
        generic map (
            CLK_DIV   => 25,      -- 50MHz / (2*25) = 1 MHz SPI
            INTERVALO => 500000   -- Lectura cada 10ms
        )
        port map (
            clk        => CLK_50MHz,
            rst        => RST_BTN,
            SPI_CS     => SPI_CS,
            SPI_CLK    => SPI_CLK,
            SPI_MOSI   => SPI_MOSI,
            SPI_MISO   => SPI_MISO,
            dato_10bit => spi_dato_crudo,
            temp_byte  => temp_actual_interna,
            dato_listo => spi_dato_listo
        );

    -- ══════════════════════════════════════════════
    -- Instancia 3: FSM Controlador (el cerebro)
    -- ══════════════════════════════════════════════
    Inst_FSM: FSM_Controlador
        port map (
            clk             => CLK_50MHz,
            rst             => RST_BTN,
            nivel_agua      => nivel_agua_limpio,
            temp_actual     => temp_actual_interna,
            temp_objetivo   => temp_objetivo_interna,
            peltier_pwm_val => valor_pwm_interno,
            peltier_dir_A   => PELTIER_R_EN,
            peltier_dir_B   => PELTIER_L_EN,
            motor_agitador  => MOTOR_AGUA,
            led_alarma      => ALARM_LED
        );

    -- ══════════════════════════════════════════════
    -- Instancia 4: Generador PWM para la Peltier
    -- ══════════════════════════════════════════════
    -- Convierte el valor 0-255 de la FSM en una señal PWM física.
    -- PREDIVISOR=160 -> F_pwm = 50MHz / (160*256) ≈ 1.22 kHz
    Inst_PWM: Generador_PWM
        generic map (PREDIVISOR => 160)
        port map (
            clk        => CLK_50MHz,
            rst        => RST_BTN,
            duty_cycle => valor_pwm_interno,
            pwm_out    => PELTIER_PWM
        );

end Estructural;
