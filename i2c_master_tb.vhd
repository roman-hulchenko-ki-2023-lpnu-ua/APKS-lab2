library ieee;
use ieee.std_logic_1164.all;

entity i2c_master_tb is
end entity i2c_master_tb;

architecture sim of i2c_master_tb is
    -- Компонент, який ми тестуємо
    component i2c_master is
        port (
            clk       : in    std_logic;
            reset_n   : in    std_logic;
            enable    : in    std_logic;
            rw        : in    std_logic;
            addr      : in    std_logic_vector(6 downto 0);
            data_wr   : in    std_logic_vector(7 downto 0);
            busy      : out   std_logic;
            data_rd   : out   std_logic_vector(7 downto 0);
            ack_error : out   std_logic;
            sda       : inout std_logic;
            scl       : inout std_logic
        );
    end component;

    -- Сигнали для симуляції
    signal clk_sig       : std_logic := '0';
    signal reset_n_sig   : std_logic := '0';
    signal enable_sig    : std_logic := '0';
    signal rw_sig        : std_logic := '0';
    signal addr_sig      : std_logic_vector(6 downto 0) := "1010101";
    signal data_wr_sig   : std_logic_vector(7 downto 0) := "11001100";
    signal busy_sig      : std_logic;
    signal data_rd_sig   : std_logic_vector(7 downto 0);
    signal ack_error_sig : std_logic;
    signal sda_sig       : std_logic;
    signal scl_sig       : std_logic;

    constant clk_period : time := 10 ns;

begin
    -- Підключення тестованого модуля (Device Under Test)
    DUT: i2c_master
        port map (
            clk       => clk_sig,
            reset_n   => reset_n_sig,
            enable    => enable_sig,
            rw        => rw_sig,
            addr      => addr_sig,
            data_wr   => data_wr_sig,
            busy      => busy_sig,
            data_rd   => data_rd_sig,
            ack_error => ack_error_sig,
            sda       => sda_sig,
            scl       => scl_sig
        );

    -- Генерація тактового сигналу
    clk_process : process
    begin
        clk_sig <= '0';
        wait for clk_period/2;
        clk_sig <= '1';
        wait for clk_period/2;
    end process;

    -- Основний процес тестування
    stimulus_process : process
    begin
        -- Ініціалізація (Reset)
        reset_n_sig <= '0';
        wait for 20 ns;
        reset_n_sig <= '1';
        wait for 20 ns;

        -- Тест 1: Запис даних (Master -> Slave)
        enable_sig <= '1';
        rw_sig <= '0'; -- Запис
        wait for clk_period;
        enable_sig <= '0'; -- Знімаємо enable, транзакція вже почалася

        -- Імітація відповіді Slave (підтягуємо SDA до '0' для ACK)
        wait for 200 ns; -- Затримка, щоб дочекатися стану SLAVE_ACK
        sda_sig <= '0';  -- Імітуємо ACK від Slave
        wait for 20 ns;
        sda_sig <= 'Z';  -- Відпускаємо лінію

        -- Завершення тесту
        wait for 500 ns;
        assert false report "Simulation Finished" severity failure;
    end process;

end architecture sim; 