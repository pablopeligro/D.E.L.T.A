library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Display_7Seg is
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
end Display_7Seg;

architecture Behavioral of Display_7Seg is
    signal refresh_counter : unsigned(19 downto 0) := (others => '0');
    signal active_digit    : STD_LOGIC_VECTOR(1 downto 0);
    signal current_val     : STD_LOGIC_VECTOR(3 downto 0);
begin

    -- Generador de refresco (Aprox 95 Hz para evitar parpadeos)
    process(clk, rst)
    begin
        if rst = '1' then
            refresh_counter <= (others => '0');
        elsif rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
        end if;
    end process;

    active_digit <= std_logic_vector(refresh_counter(19 downto 18));

    -- Multiplexor de Ánodos y Datos
    process(active_digit, dig3, dig2, dig1, dig0)
    begin
        case active_digit is
            when "00" =>
                an <= "0111"; 
                current_val <= dig3;
            when "01" =>
                an <= "1011"; 
                current_val <= dig2;
            when "10" =>
                an <= "1101"; 
                current_val <= dig1;
            when "11" =>
                an <= "1110"; 
                current_val <= dig0;
            when others =>
                an <= "1111";
                current_val <= "0000";
        end case;
    end process;

    -- Decodificador BCD a 7 Segmentos (Ánodo Común)
    process(current_val)
    begin
        case current_val is
            when "0000" => seg <= "1000000"; -- 0
            when "0001" => seg <= "1111001"; -- 1
            when "0010" => seg <= "0100100"; -- 2
            when "0011" => seg <= "0110000"; -- 3
            when "0100" => seg <= "0011001"; -- 4
            when "0101" => seg <= "0010010"; -- 5
            when "0110" => seg <= "0000010"; -- 6
            when "0111" => seg <= "1111000"; -- 7
            when "1000" => seg <= "0000000"; -- 8
            when "1001" => seg <= "0010000"; -- 9
            when others => seg <= "1111111"; -- Apagado
        end case;
    end process;

end Behavioral;