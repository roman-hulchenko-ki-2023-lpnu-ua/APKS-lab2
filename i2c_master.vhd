library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
    port (
        clk       : in    std_logic;                    -- Системний тактовий сигнал
        reset_n   : in    std_logic;                    -- Асинхронне скидання 
        enable    : in    std_logic;                    -- Сигнал запуску транзакції
        rw        : in    std_logic;                    -- Напрямок: 0 = Запис, 1 = Читання
        addr      : in    std_logic_vector(6 downto 0); -- 7-бітна адреса Slave-пристрою
        data_wr   : in    std_logic_vector(7 downto 0); -- Дані для передачі (Tx)
        busy      : out   std_logic;                    -- Індикатор зайнятості шини
        data_rd   : out   std_logic_vector(7 downto 0); -- Прийняті дані (Rx)
        ack_error : out   std_logic;                    -- Індикатор помилки 
        sda       : inout std_logic;                    -- Двонаправлена лінія даних I2C
        scl       : inout std_logic                     -- Двонаправлена лінія тактів I2C
    );
end entity i2c_master;

architecture rtl of i2c_master is
    -- Визначення станів нашого скінченного автомата
    type state_type is (IDLE, START, ADDRESS, SLAVE_ACK, DATA, MASTER_ACK, STOP);
    signal state : state_type := IDLE;

    -- Внутрішні регістри
    signal bit_cnt  : integer range 0 to 7 := 7;      -- Лічильник бітів
    signal data_rx  : std_logic_vector(7 downto 0);   -- Буфер приймача (Rx)
    signal addr_rw  : std_logic_vector(7 downto 0);   -- Адреса + біт R/W
    signal sda_out  : std_logic := '1';               -- Вихідний сигнал для SDA
    signal scl_out  : std_logic := '1';               -- Вихідний сигнал для SCL

begin
    -- Двонаправлені лінії I2C 
    sda <= '0' when sda_out = '0' else 'Z';
    scl <= '0' when scl_out = '0' else 'Z';

    -- Основний процес FSM
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            busy <= '0';
            ack_error <= '0';
            sda_out <= '1';
            scl_out <= '1';
        elsif rising_edge(clk) then
            case state is
                
                when IDLE =>
                    busy <= '0';
                    sda_out <= '1';
                    scl_out <= '1';
                    if enable = '1' then
                        busy <= '1';
                        addr_rw <= addr & rw; -- Формуємо 8 біт: 7 біт адреси + 1 біт R/W
                        state <= START;
                    end if;

                when START =>
                    sda_out <= '0'; -- Генерація умови СТАРТ (SDA йде в 0 при SCL=1)
                    scl_out <= '1';
                    bit_cnt <= 7;
                    state <= ADDRESS;

                when ADDRESS =>
                    scl_out <= '0';
                    sda_out <= addr_rw(bit_cnt); -- Передача бітів адреси
                    if bit_cnt = 0 then
                        state <= SLAVE_ACK;
                    else
                        bit_cnt <= bit_cnt - 1;
                    end if;

                when SLAVE_ACK =>
                    scl_out <= '0';
                    sda_out <= '1'; 

                    if sda = '0' then 
                        ack_error <= '0';
                        bit_cnt <= 7;
                        state <= DATA; -- Отримали ACK, йдемо далі
                    else
                        ack_error <= '1';
                        state <= STOP; -- Отримали NACK, перериваємось
                    end if;

                when DATA =>
                    scl_out <= '0';
                    if rw = '0' then
                        sda_out <= data_wr(bit_cnt); -- Режим передавача (Tx)
                    else
                        sda_out <= '1'; -- Режим приймача (Rx): відпускаємо лінію
                        data_rx(bit_cnt) <= sda; -- Читаємо дані зі Slave
                    end if;
                    
                    if bit_cnt = 0 then
                        state <= MASTER_ACK;
                    else
                        bit_cnt <= bit_cnt - 1;
                    end if;

                when MASTER_ACK =>
                    scl_out <= '0';
                    if rw = '1' then
                        sda_out <= '0'; -- Генеруємо ACK (0) якщо ми читали і хочемо ще
                    else
                        sda_out <= '1'; -- Відпускаємо лінію, чекаємо ACK від Slave при записі
                    end if;
                    state <= STOP; 

                when STOP =>
                    scl_out <= '1';
                    sda_out <= '1'; -- умова СТОП (SDA йде в 1 при SCL=1)
                    data_rd <= data_rx; -- прочитані дані на вихід
                    state <= IDLE;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end architecture rtl;