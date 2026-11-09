architecture rtl of i2c_master is
    type state_type is (IDLE, START, ADDRESS, SLAVE_ACK, DATA, MASTER_ACK, STOP);
    signal state : state_type := IDLE;

    signal bit_cnt  : integer range 0 to 7 := 7; 
    signal data_rx  : std_logic_vector(7 downto 0) := (others => '0');
    signal addr_rw  : std_logic_vector(7 downto 0) := (others => '0'); 
    signal sda_out  : std_logic := '1'; 
    signal scl_out  : std_logic := '1'; 
    
    -- НОВИЙ СИГНАЛ: фаза для генерації SCL. (0 - SCL падає, 1 - SCL піднімається)
    signal phase    : integer range 0 to 1 := 0; 

begin
    sda <= '0' when sda_out = '0' else 'Z';
    scl <= '0' when scl_out = '0' else 'Z';

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            busy <= '0';
            ack_error <= '0';
            sda_out <= '1';
            scl_out <= '1';
            phase <= 0; -- Скидання фази
        elsif rising_edge(clk) then
            case state is
                
                when IDLE =>
                    busy <= '0';
                    sda_out <= '1';
                    scl_out <= '1';
                    phase <= 0;
                    if enable = '1' then
                        busy <= '1';
                        addr_rw <= addr & rw; 
                        state <= START;
                    end if;

                when START =>
                    if phase = 0 then
                        sda_out <= '0'; -- СТАРТ: SDA йде в 0 при SCL=1
                        scl_out <= '1';
                        phase <= 1;
                    else
                        scl_out <= '0'; -- Опускаємо SCL для наступного біта
                        phase <= 0;
                        bit_cnt <= 7;
                        state <= ADDRESS;
                    end if;

                when ADDRESS =>
                    if phase = 0 then
                        scl_out <= '0';
                        sda_out <= addr_rw(bit_cnt); -- Виставляємо біт адреси
                        phase <= 1;
                    else
                        scl_out <= '1'; -- Піднімаємо SCL (Slave читає біт)
                        phase <= 0;
                        if bit_cnt = 0 then
                            state <= SLAVE_ACK;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when SLAVE_ACK =>
                    if phase = 0 then
                        scl_out <= '0';
                        sda_out <= '1'; -- Відпускаємо лінію для Slave
                        phase <= 1;
                    else
                        scl_out <= '1';
                        phase <= 0;
                        if sda = '0' then 
                            ack_error <= '0';
                            bit_cnt <= 7;
                            state <= DATA;
                        else
                            ack_error <= '1';
                            state <= STOP;
                        end if;
                    end if;

                when DATA =>
                    if phase = 0 then
                        scl_out <= '0';
                        if rw = '0' then
                            sda_out <= data_wr(bit_cnt);
                        else
                            sda_out <= '1'; 
                        end if;
                        phase <= 1;
                    else
                        scl_out <= '1';
                        phase <= 0;
                        if rw = '1' then
                            data_rx(bit_cnt) <= sda;
                        end if;
                        if bit_cnt = 0 then
                            state <= MASTER_ACK;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when MASTER_ACK =>
                    if phase = 0 then
                        scl_out <= '0';
                        if rw = '1' then
                            sda_out <= '0'; 
                        else
                            sda_out <= '1'; 
                        end if;
                        phase <= 1;
                    else
                        scl_out <= '1';
                        phase <= 0;
                        state <= STOP; 
                    end if;

                when STOP =>
                    if phase = 0 then
                        scl_out <= '0';
                        sda_out <= '0'; 
                        phase <= 1;
                    else
                        scl_out <= '1';
                        sda_out <= '1'; -- СТОП: SDA йде в 1 при SCL=1
                        phase <= 0;
                        data_rd <= data_rx; 
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end architecture rtl;