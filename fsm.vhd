library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CONTROL_MODULE is 
  port (
  	MAIN_CLK_i                          : in std_logic;         -- main clock (freqdivider low frequency/250Hz)
  	N_MAIN_RST_i                        : in std_logic;         -- reset FSM (back to state INTERFACE)
-- Interface Antenna
  	ANA_INTERFACE_IN_MODSELECT_o        : out std_logic;        -- connect antenna to modulator (1) or power detector (0)
-- Power detector
  	ADD_PD_OUT_OUTFLAG_i                : in std_logic;         -- output flag of power detector (1 for power detected)
    ADD_PD_STA_OUT_READY_i              : in std_logic;         -- power detector ready (to wait a few cycles after enable before reading output flag)
    ANA_PD_EN_o                         : out std_logic;        -- start power detector
-- Modulator
    ANA_MOD_EN_o                     		: out std_logic;        -- start modulator
-- Oscillator

-- Frequency divider
    ANA_FREQ_DIVIDER_EN_o               : out std_logic; -- b'0 freqdivider low frequency b'1 : high and low frequency
-- Oscillator selection MUX

-- Data register MUX et MUX
    DATA_REG_MUX_SEL_DATA_o             : out std_logic_vector(8 downto 0); -- Address for data selection MUX
    DATA_REG_MUX_EN_o                   : out std_logic;                    -- start MUX (supplied frequency keuys to modulator)
	ANA_MUX_EN_o                     		: out std_logic;        -- start modulator

-- LDO

-- Register inputs 
    CFREG_DATA_BANK_REPEAT_i            : in std_logic_vector(3 downto 0);
    CFREG_DATA_BANK_SELECT_i            : in std_logic_vector(3 downto 0);
    CFREG_DATA_BANK_SEQUENCE_i          : in std_logic_vector(35 downto 0);
    CFREG_DATA_SEL_SINGLE_SEQUENCE_i    : in std_logic;
    CFREG_DELAY_DATA_BANK_REPEAT_i      : in std_logic_vector(4 downto 0);
    CFREG_FORCE_STATE_FSM_i             : in std_logic_vector(7 downto 0);
    CFREG_PREAMB_i                      : in std_logic;
    CFREG_REPEAT_WITH_PREAMB_i          : in std_logic;
		
		PORT_STA_LED_o											: out std_logic_vector(2 downto 0);
		
		FLAG_POR_i													: in std_logic
  );
end entity CONTROL_MODULE;

architecture rtl of CONTROL_MODULE is
  type state_t is (INTERFACE, LISTEN, LISTEN_TO_SLEEP, SLEEP_TO_LISTEN, START_UP_FSK, START_UP_BACKSCATTER, SEQUENCE_NEXT, BACKSATTER, REPEAT_DATA, WAIT_BACKSATTER, DELAY, START_UP_LISTEN, SLEEP);
  signal i_CURRENT_STATE                  									: state_t;
  signal i_NEXT_STATE                     									: state_t;
	signal i_ANA_INTERFACE_IN_MODSELECT										: std_logic;
	signal i_ADD_PD_OUT_OUTFLAG												: std_logic;
	signal i_ADD_PD_STA_OUT_READY											: std_logic;
	signal i_ANA_PD_EN														: std_logic;
	signal i_ANA_FREQ_DIVIDER_EN											: std_logic;
	signal i_DATA_REG_MUX_SEL_DATA											: std_logic_vector(8 downto 0);
	signal i_DATA_REG_MUX_EN												: std_logic;
	signal i_CFREG_DATA_BANK_REPEAT											: std_logic_vector(3 downto 0);
	signal i_CFREG_DATA_BANK_SELECT											: std_logic_vector(3 downto 0);
	signal i_CFREG_DATA_BANK_SEQUENCE										: std_logic_vector(35 downto 0);
	signal i_CFREG_DATA_SEL_SINGLE_SEQUENCE									: std_logic;
	signal i_CFREG_DELAY_DATA_BANK											: std_logic_vector(4 downto 0);
	signal i_CFREG_FORCE_STATE_FSM											: std_logic_vector(7 downto 0);
	signal i_CFREG_PREAMB													: std_logic;
	signal i_CFREG_REPEAT_WITH_PREAMB										: std_logic;
	signal i_COUNT_DUTY_CYCLE												: std_logic_vector(3 downto 0);
	signal i_PORT_STA_LED													: std_logic_vector(2 downto 0);
	signal i_CONCATEN_PD_INTERFACE_STA										: std_logic_vector(2 downto 0);
	signal i_COUNT_BB_DATA													: std_logic_vector(4 downto 0);
	signal i_COUNT_IDLE_BACKSAT												: std_logic_vector(4 downto 0);
	signal i_COUNT_SEQUENCE_VECTOR											: std_logic_vector(3 downto 0);
	signal i_COUNT_DATA_BANK_REPEAT											: std_logic_vector(3 downto 0);
	signal i_ANA_MUX_EN														: std_logic;
	signal i_ANA_MOD_EN														: std_logic;
	signal i_DELAY_DATA_BANK_COUNTER										: std_logic_vector(3 downto 0);
	signal i_FLAG_POR														: std_logic;
begin

-- IOs definition
i_ADD_PD_OUT_OUTFLAG 								<= ADD_PD_OUT_OUTFLAG_i;
i_ADD_PD_STA_OUT_READY 							<= ADD_PD_STA_OUT_READY_i;
i_CFREG_DATA_BANK_REPEAT	         	<= CFREG_DATA_BANK_REPEAT_i;        
i_CFREG_DATA_BANK_SELECT	         	<= CFREG_DATA_BANK_SELECT_i;       
i_CFREG_DATA_BANK_SEQUENCE	       	<= CFREG_DATA_BANK_SEQUENCE_i;      
i_CFREG_DATA_SEL_SINGLE_SEQUENCE	 	<= CFREG_DATA_SEL_SINGLE_SEQUENCE_i;
i_CFREG_DELAY_DATA_BANK	   					<= CFREG_DELAY_DATA_BANK_REPEAT_i;  
i_CFREG_FORCE_STATE_FSM	          	<= CFREG_FORCE_STATE_FSM_i;         
i_CFREG_PREAMB	                   	<= CFREG_PREAMB_i;                  
i_CFREG_REPEAT_WITH_PREAMB	       	<= CFREG_REPEAT_WITH_PREAMB_i;
i_FLAG_POR													<= FLAG_POR_i;

ANA_INTERFACE_IN_MODSELECT_o				<= i_ANA_INTERFACE_IN_MODSELECT;
ANA_FREQ_DIVIDER_EN_o								<= i_ANA_FREQ_DIVIDER_EN;
ANA_PD_EN_o													<= i_ANA_PD_EN;
DATA_REG_MUX_SEL_DATA_o							<= i_DATA_REG_MUX_SEL_DATA;
DATA_REG_MUX_EN_o										<= i_DATA_REG_MUX_EN;
PORT_STA_LED_o											<= i_PORT_STA_LED;
ANA_MUX_EN_o												<= i_ANA_MUX_EN;
ANA_MOD_EN_o												<= i_ANA_MOD_EN;

  process(MAIN_CLK_i, N_MAIN_RST_i)
  begin
    if N_MAIN_RST_i = '0' then
      i_CURRENT_STATE <= INTERFACE;
    elsif rising_edge(MAIN_CLK_i) then
      i_CURRENT_STATE <= i_NEXT_STATE;
    end if;
  end process;

  process(i_CURRENT_STATE, i_ADD_PD_OUT_OUTFLAG, i_COUNT_DUTY_CYCLE, i_COUNT_BB_DATA, i_COUNT_DATA_BANK_REPEAT, i_COUNT_SEQUENCE_VECTOR, i_COUNT_SEQUENCE_VECTOR, i_COUNT_IDLE_BACKSAT, i_DELAY_DATA_BANK_COUNTER, i_CFREG_FORCE_STATE_FSM, i_ADD_PD_STA_OUT_READY)
  begin	
		i_ANA_PD_EN <= '0';
		
    case i_CURRENT_STATE is
			
      --when IDLE =>
      when INTERFACE => -- initial state (reset): intialize listen duty cycle counter and enable power detector
        i_ANA_INTERFACE_IN_MODSELECT <= '0';
				i_NEXT_STATE <= LISTEN;
				i_COUNT_DUTY_CYCLE <= (others => '0');
				i_ANA_PD_EN <= '1';
				
      when LISTEN => -- increment counter for 3 cycles (wait for power detected), when cycles are finished go to sleep state, if power is detected go to backscatter state
				i_PORT_STA_LED <= "001";
				i_ANA_PD_EN <= '1';
				i_COUNT_DUTY_CYCLE <= std_logic_vector(unsigned(i_COUNT_DUTY_CYCLE) + 1);
				if i_ADD_PD_OUT_OUTFLAG = '0' then
					if unsigned(i_COUNT_DUTY_CYCLE) >= 2 then
						if i_CFREG_FORCE_STATE_FSM /= "00000011" then
							i_NEXT_STATE <= LISTEN_TO_SLEEP;
						else
							i_NEXT_STATE <= LISTEN;
						end if;
					else
						i_NEXT_STATE <= LISTEN;
					end if;
				elsif i_ADD_PD_OUT_OUTFLAG = '1' then
					if i_CFREG_FORCE_STATE_FSM /= "00000010" then
						i_NEXT_STATE <= START_UP_FSK;
					else
						i_NEXT_STATE <= LISTEN;
					end if;
				else
					i_NEXT_STATE <= LISTEN;
				end if;
				
      when LISTEN_TO_SLEEP => -- transistion from listen to sleep: reset duty cycle counter, connect interface to modulator 
				i_COUNT_DUTY_CYCLE <= (others => '0');
				i_ANA_INTERFACE_IN_MODSELECT <= '1';
				i_NEXT_STATE <= SLEEP;
			
			when SLEEP => -- count 16 cycles then go back to listen state 
				i_PORT_STA_LED <= "111";
				i_COUNT_DUTY_CYCLE <= std_logic_vector(unsigned(i_COUNT_DUTY_CYCLE) + 1);
				if unsigned(i_COUNT_DUTY_CYCLE) >= 15 then
					i_NEXT_STATE <= SLEEP_TO_LISTEN;
				else 
					i_NEXT_STATE <= SLEEP;
				end if;
				
      when SLEEP_TO_LISTEN => -- transistion from sleep to listen: reset duty cycle counter, connect antenna to power detector, enable power detector
				i_COUNT_DUTY_CYCLE <= (others => '0');
				i_ANA_PD_EN <= '1';
				i_ANA_INTERFACE_IN_MODSELECT <= '0';
				i_NEXT_STATE <= LISTEN;
				
      when START_UP_FSK => -- transistion from listen to backscatter: when power is detected, turn on high frequency of freqdivider
				i_PORT_STA_LED <= "010";
				i_ANA_FREQ_DIVIDER_EN <= '1'; 
				i_NEXT_STATE <= START_UP_BACKSCATTER;
				
      when START_UP_BACKSCATTER => -- transistion from listen to backscatter: connect antenna to modulator, enable modulator and MUX initialize bit counter, repeat counter and sequence counter
				i_ANA_INTERFACE_IN_MODSELECT <= '0';
				i_PORT_STA_LED <= "011";
				i_COUNT_BB_DATA <= (others => '0');
				i_COUNT_DATA_BANK_REPEAT <= (others => '0');
				i_ANA_MOD_EN <= '1';
				i_ANA_MUX_EN <= '1';
				i_DATA_REG_MUX_EN <= '1';
				i_COUNT_SEQUENCE_VECTOR <= (others => '0');
				i_NEXT_STATE <= BACKSATTER;
				
      -- when BACKSATTER_PREAMBLE =>
			-- 	i_PORT_STA_LED <= "100";
			-- 	i_COUNT_IDLE_BACKSAT <= (others => '0');
			-- 	i_ANA_MUX_DATA_IN_SELECT <= SHIFT_BB_DATA_0[COUNT_BB_DATA] -- a voir
			-- 	i_COUNT_BB_DATA <= std_logic_vector(unsigned(i_COUNT_BB_DATA) + 1);
			-- 	if unsigned(i_COUNT_BB_DATA) >= 31 then
			-- 		i_NEXT_STATE <= RESET_DATA_COUNTER;
			-- 	else
			-- 		i_NEXT_STATE <= WAIT_BACKSATTER_PREAMBLE;
			-- 	end if;
			-- 	
      -- when WAIT_BACKSATTER_PREAMBLE =>
			-- 	i_COUNT_IDLE_BACKSAT <= std_logic_vector(unsigned(i_COUNT_IDLE_BACKSAT) + 1);
			-- 	if unsigned(i_COUNT_IDLE_BACKSAT) >= 26 then 
			-- 		i_NEXT_STATE <= BACKSATTER_PREAMBLE;
			-- 	else
			-- 		i_NEXT_STATE <= WAIT_BACKSATTER_PREAMBLE;
			-- 	end if;
			-- 	
			-- 	when RESET_DATA_COUNTER =>
			-- 		i_COUNT_BB_DATA <= (others => '0');
			-- 		i_NEXT_STATE <= BACKSATTER;
			
      when BACKSATTER => -- adress of each bit from concatenation of (MSB) sequence and (LSB) bit counter, increment bit counter, initialize idle counter (for 40ms bit duration) and switch to idle state (wait backscatter) after each bit counter increment, switch to next 32 bits register after all bits sent
				i_DATA_REG_MUX_SEL_DATA <= i_CFREG_DATA_BANK_SEQUENCE((to_integer(unsigned(i_COUNT_SEQUENCE_VECTOR))+1)*4-1 downto to_integer(unsigned(i_COUNT_SEQUENCE_VECTOR))*4) & i_COUNT_BB_DATA;
				i_COUNT_BB_DATA <= std_logic_vector(unsigned(i_COUNT_BB_DATA) + 1);
				i_COUNT_IDLE_BACKSAT <= (others => '0');
				if unsigned(i_COUNT_BB_DATA) >= 31 then 
					i_NEXT_STATE <= REPEAT_DATA;
				else
					i_NEXT_STATE <= WAIT_BACKSATTER;
				end if;
				
      when WAIT_BACKSATTER => -- idle state to count 40ms between each bit
				i_COUNT_IDLE_BACKSAT <= std_logic_vector(unsigned(i_COUNT_IDLE_BACKSAT) + 1);
				if unsigned(i_COUNT_IDLE_BACKSAT) >= 26 then 
					i_NEXT_STATE <= BACKSATTER;
				else
					i_NEXT_STATE <= WAIT_BACKSATTER;
				end if;
			
			when REPEAT_DATA => -- reset bit counter, increment repeat counter, go to backscatter state if repeat, to delay state if delay, else to SEQUENCE_NEXT
				i_COUNT_BB_DATA <= (others => '0');
				i_COUNT_DATA_BANK_REPEAT <= std_logic_vector(unsigned(i_COUNT_DATA_BANK_REPEAT) + 1);
				i_DELAY_DATA_BANK_COUNTER <= (others => '0');
				if unsigned(i_COUNT_DATA_BANK_REPEAT) < unsigned(i_CFREG_DATA_BANK_REPEAT) then
					if i_CFREG_DELAY_DATA_BANK = "00000" then
						i_NEXT_STATE <= BACKSATTER;
					else
						i_NEXT_STATE <= DELAY;
					end if;
				else
					i_NEXT_STATE <= SEQUENCE_NEXT;
				end if;
				
			when SEQUENCE_NEXT => -- increment sequence counter, go to listen state if at the end of sequence or if rest of sequence is 1111 (skipped)
				i_COUNT_SEQUENCE_VECTOR <= std_logic_vector(unsigned(i_COUNT_SEQUENCE_VECTOR) + 1);
				if (unsigned(i_COUNT_SEQUENCE_VECTOR)) >= 9 or (i_CFREG_DATA_BANK_SEQUENCE((to_integer(unsigned(i_COUNT_SEQUENCE_VECTOR))+1)*4-1 downto to_integer(unsigned(i_COUNT_SEQUENCE_VECTOR))*4) = "1111") then
					i_NEXT_STATE <= START_UP_LISTEN;
				else
					if i_CFREG_DELAY_DATA_BANK = "00000" then
						i_NEXT_STATE <= BACKSATTER;
					else
						i_NEXT_STATE <= DELAY;
					end if;
				end if;
					
      when DELAY =>  -- increment delay counter until equal to i_CFREG_DELAY_DATA_BANK, then goes back to backscatter
			i_DELAY_DATA_BANK_COUNTER <= std_logic_vector(unsigned(i_DELAY_DATA_BANK_COUNTER) + 1);
			if unsigned(i_DELAY_DATA_BANK_COUNTER) < unsigned(i_CFREG_DELAY_DATA_BANK) then
				i_NEXT_STATE <= DELAY;
			else
				i_NEXT_STATE <= BACKSATTER;
			end if;
			
      when START_UP_LISTEN => -- transistion from backscatter to listen duty cycle, connect antenna to modulator (sleep state), turn off modulator and MUX
				i_ANA_INTERFACE_IN_MODSELECT <= '0';
				i_PORT_STA_LED <= "101";
				i_ANA_FREQ_DIVIDER_EN <= '0';
				i_ANA_MOD_EN <= '0';
				i_ANA_MUX_EN <= '0';
				i_NEXT_STATE <= LISTEN;

		end case;
	end process;              


end architecture rtl;

