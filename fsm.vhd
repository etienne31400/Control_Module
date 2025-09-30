library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CONTROL_MODULE is 
  port (
  	MAIN_CLK_i                          : in std_logic;         -- Horloge principale
  	N_MAIN_CLR_i                        : in std_logic;         -- Reset proncipal
-- Interface Antenna
  	ADD_INTERFACE_STA_OUT_READY_i       : in std_logic;         -- Antenne bien connectée
  	ANA_INTERFACE_IN_MODSELECT_o        : out std_logic;        -- Connexion de l'antenne au modulator b'0 ou au power detector b'1
-- Power detector
  	ADD_PD_OUT_OUTFLAG_i                : in std_logic;         -- Puissance détectée 
    ADD_PD_STA_OUT_READY_i              : in std_logic;         -- Power detector operationnel
    ANA_PD_EN_o                         : out std_logic;        -- Allumage du power detector
-- Modulator
    ANA_MOD_FORCE_o                     : out std_logic;        -- Mise en route du modulator
-- Oscillator

-- Frequency divider
    ANA_FREQ_DIVIDER_EN_i               : out std_logic_vector(1 downto 0); -- b'00 freqdivider eteint b'01 : freq basse b'10 : basse + haute
-- Oscillator selection MUX

-- Data register MUX et MUX
    DATA_REG_MUX_SEL_DATA_o             : out std_logic_vector(8 downto 0); -- Adresse du bit selectionné du MUX des datas
    DATA_REG_MUX_EN_o                   : out std_logic;                    -- Démarrage des deux MUX

-- LDO

-- Register inputs 
    CFREG_DATA_BANK_REPEAT_i            : in std_logic_vector(1 downto 0);
    CFREG_DATA_BANK_SELECT_i            : in std_logic_vector(3 downto 0);
    CFREG_DATA_BANK_SEQUENCE_i          : in std_logic_vector(15 downto 0);
    CFREG_DATA_SEL_SINGLE_SEQUENCE_i    : in std_logic;
    CFREG_DELAY_DATA_BANK_REPEAT_i      : in std_logic_vector(4 downto 0);
    CFREG_FORCE_STATE_FSM_i             : in std_logic_vector(7 downto 0);
    CFREG_PREAMB_i                      : in std_logic;
    CFREG_REPEAT_WITH_PREAMB_i          : in std_logic;
		
		PORT_SAT_LED_o											: out std_logic_vector(2 downto 0);
  );
end entity CONTROL_MODULE;

architecture rtl of CONTROL_MODULE is
  type state_t is (IDLE, SUPPLY_START_UP, INTERFACE, LISTEN, LISTEN_TO_SLEEP, SLEEP_TO_LISTEN, START_UP_CLOCK, START_UP_BACKSCATTER, BACKSATTER_PREAMBLE, WAIT_BACKSATTER_PREAMBLE, RESET_DATA_COUNTER, BACKSATTER, REPEAT_DATA, WAIT_BACKSATTER, DELAY, START_UP_LISTEN, SLEEP);
  signal i_CURRENT_STATE                  									: state_t;
  signal i_NEXT_STATE                     									: state_t;
	signal i_ADD_INTERFACE_STA_OUT_READY											: std_logic;
	signal i_ANA_INTERFACE_IN_MODSELECT												: std_logic;
	signal i_ADD_PD_OUT_OUTFLAG																: std_logic;
	signal i_ADD_PD_STA_OUT_READY															: std_logic;
	signal i_ANA_PD_EN																				: std_logic;
	signal i_ANA_MOD_FORCE																		: std_logic;
	signal i_ANA_FREQ_DIVIDER_EN															: std_logic_vector(1 downto 0);
	signal i_DATA_REG_MUX_SEL_DATA														: std_logic_vector(8 downto 0);
	signal i_DATA_REG_MUX_EN																	: std_logic;
	signal i_CFREG_DATA_BANK_REPEAT														: std_logic_vector(1 downto 0);
	signal i_CFREG_DATA_BANK_SELECT														: std_logic_vector(3 downto 0);
	signal i_CFREG_DATA_BANK_SEQUENCE													: std_logic_vector(15 downto 0);
	signal i_CFREG_DATA_SEL_SINGLE_SEQUENCE										: std_logic;
	signal i_CFREG_DELAY_DATA_BANK_REPEAT											: std_logic_vector(4 downto 0);
	signal i_CFREG_FORCE_STATE_FSM														: std_logic_vector(7 downto 0);
	signal i_CFREG_PREAMB																			: std_logic;
	signal i_CFREG_REPEAT_WITH_PREAMB													: std_logic;
	signal i_COUNT_DUTY_CYCLE																	: std_logic_vector(1 downto 0);
	signal i_PORT_STA_LED																			: std_logic_vector(2 downto 0);
	signal i_CONCATEN_PD_INTERFACE_STA												: std_logic_vector(2 downto 0);
	signal i_CONCATEN_ADD_PD_FLAG_POR_ADD_INTERFACE 					: std_logic_vector(3 downto 0);
	signal i_CONCATEN_CLOCKGEN_FREQDIVIDER 										: std_logic_vector(2 downto 0);
	signal i_COUNT_BB_DATA																		: std_logic_vector(4 downto 0);
	signal i_COUNT_IDLE_BACKSAT																: std_logic_vector(4 downto 0);
	signal i_CONCATEN_FREQDIVIDER_POWERREG_INTERFACE					: std_logic_vector(4 downto 0);
begin

-- IOs definition
i_ADD_INTERFACE_STA_OUT_READY 			<= ADD_INTERFACE_STA_OUT_READY_i;
i_ADD_PD_OUT_OUTFLAG 								<= ADD_PD_OUT_OUTFLAG_i;
i_ADD_PD_STA_OUT_READY 							<= ADD_PD_STA_OUT_READY_i;
i_ANA_FREQ_DIVIDER_EN								<= ANA_FREQ_DIVIDER_EN_i;
i_CFREG_DATA_BANK_REPEAT	         	<= CFREG_DATA_BANK_REPEAT_i;        
i_CFREG_DATA_BANK_SELECT	         	<= CFREG_DATA_BANK_SELECT_i;       
i_CFREG_DATA_BANK_SEQUENCE	       	<= CFREG_DATA_BANK_SEQUENCE_i;      
i_CFREG_DATA_SEL_SINGLE_SEQUENCE	 	<= CFREG_DATA_SEL_SINGLE_SEQUENCE_i;
i_CFREG_DELAY_DATA_BANK_REPEAT	   	<= CFREG_DELAY_DATA_BANK_REPEAT_i;  
i_CFREG_FORCE_STATE_FSM	          	<= CFREG_FORCE_STATE_FSM_i;         
i_CFREG_PREAMB	                   	<= CFREG_PREAMB_i;                  
i_CFREG_REPEAT_WITH_PREAMB	       	<= CFREG_REPEAT_WITH_PREAMB_i;

ANA_INTERFACE_IN_MODSELECT_o				<= i_ANA_INTERFACE_IN_MODSELECT;
ANA_PD_EN_o													<= i_ANA_PD_EN;
ANA_MOD_FORCE_o											<= i_ANA_MOD_FORCE;
DATA_REG_MUX_SEL_DATA_o							<= i_DATA_REG_MUX_SEL_DATA;
DATA_REG_MUX_EN_o										<= i_DATA_REG_MUX_EN;
PORT_SAT_LED_o											<= i_PORT_STA_LED;

  process(MAIN_CLK_i, N_MAIN_CLR_i)
  begin
          if N_MAIN_CLR_i = '1' then
                  i_CURRENT_STATE <= SUPPLY_START_UP;
          end if;
          elsif  rising_edge(MAIN_CLK_i) then
                  i_CURRENT_STATE <= i_NEXT_STATE;
          end if;
  end process;
	
i_CONCATEN_PD_INTERFACE_STA <= i_ADD_PD_STA_OUT_READY & i_ADD_INTERFACE_STA_OUT_READY;
	
i_CONCATEN_ADD_PD_FLAG_POR_ADD_INTERFACE <= i_ADD_PD_STA_OUT_READY & i_FLAG_POR & i_ADD_INTERFACE_STA_OUT_READY;

i_CONCATEN_CLOCKGEN_FREQDIVIDER <= i_ADD_CLOCKGEN_STA_OUT_READY & i_ADD_FREQDIVIDER_STA_OUT_READY; -- a regarder

i_CONCATEN_FREQDIVIDER_POWERREG_INTERFACE <= ADD_FREQDIVIDER_STA_OUT_READY & ADD_POWERREG_STA_OUT_READY & ADD_INTERFACE_STA_OUT_READY;

  process(i_CURRENT_STATE, i_ADD_INTERFACE_STA_OUT_READY, i_ADD_PD_OUT_OUTFLAG, i_COUNT_DUTY_CYCLE, i_CFREG_FORCE_STATE_FSM, i_ADD_PD_STA_OUT_READY, )
  begin
    case i_CURRENT_STATE is
      when SUPPLY_START_UP =>
			
      --when IDLE =>
      when INTERFACE =>
        i_ANA_INTERFACE_IN_MODSELECT <= "01";
        if i_ADD_INTERFACE_STA_OUT_READY = "01" then
					i_NEXT_STATE <= LISTEN;
				end if;
				
      when LISTEN =>
				i_PORT_STA_LED <= "001";
				i_COUNT_DUTY_CYCLE <= std_logic_vector(unsigned(i_COUNT_DUTY_CYCLE) + 1);
				if i_ADD_PD_OUT_OUTFLAG = '0' then
					if i_COUNT_DUTY_CYCLE = "10" then
						if i_CFREG_FORCE_STATE_FSM /= "00000011" then
							i_NEXT_STATE <= LISTEN_TO_SLEEP;
						end if;
						else
							i_NEXT_STATE <= LISTEN;
						end if;
					else
						i_NEXT_STATE <= LISTEN;
					end if;
					end if;
				elsif i_ADD_PD_OUT_OUTFLAG = '1' then
					if i_CFREG_FORCE_STATE_FSM /= "00000010" then
						i_NEXT_STATE <= START_UP_CLOCK;
					end if;
				end if;
				
      when LISTEN_TO_SLEEP =>
				i_COUNT_DUTY_CYCLE <= (others => '0');
				i_ANA_PD_EN <= '0';
				i_ANA_INTERFACE_IN_MODSELECT <= (others => '0');
				-- i_ANA_POWERREG_MOD_SELECT <= (others => '0');
				if i_CONCATEN_PD_INTERFACE_STA = "000" then
					i_NEXT_STATE <= SLEEP;
				else 
					i_NEXT_STATE <= LISTEN_TO_SLEEP;
				end if;
			
			when SLEEP =>
				i_PORT_STA_LED <= "111";
				i_COUNT_DUTY_CYCLE <= std_logic_vector(unsigned(i_COUNT_DUTY_CYCLE) + 1);
				if unsigned(i_COUNT_DUTY_CYCLE) >= 15 then
					i_NEXT_STATE <= SLEEP_TO_LISTEN;
				else 
					i_NEXT_STATE <= SLEEP;
				end if;
				
      when SLEEP_TO_LISTEN =>
				i_COUNT_DUTY_CYCLE <= (others => '0');
				i_ANA_PD_EN <= '1';
				i_ANA_INTERFACE_IN_MODSELECT <= "01";
				-- i_ANA_POWERREG_MODSELECT
				if i_CONCATEN_ADD_PD_FLAG_POR_ADD_INTERFACE = "1101" then
					i_NEXT_STATE <= LISTEN;
				else 
					i_NEXT_STATE <= SLEEP_TO_LISTEN;
				end if;
				
      when START_UP_CLOCK =>
				i_ANA_POWERREG_MODSELECT <= "10";
				i_PORT_STA_LED <= "010";
				i_ANA_FREQ_DIVIDER_EN <= "11";
				i_ANA_PD_EN <= '0';
				-- A revoir cet etat : trop de signaux manquants
				
      when START_UP_BACKSATTER =>
				i_ANA_INTERFACE_IN_MODSELECT <= "10";
				i_PORT_STA_LED <= "011";
				i_COUNT_BB_DATA <= (others => '0');
				i_COUNT_DATA_BANK_REPEAT <= (other => '0');
				--i_ANA_MOD_EN
				--i_ANA_MUX_EN
				if i_ADD_INTERFACE_STA_OUT_READY = "10" then
					i_NEXT_STATE <= BACKSATTER_PREAMBLE;
				else 
					i_NEXT_STATE <= START_UP_BACKSATTER;
				end if;
				
      when BACKSATTER_PREAMBLE =>
				i_PORT_STA_LED <= "100";
				i_COUNT_IDLE_BACKSAT <= (others => '0');
				i_ANA_MUX_DATA_IN_SELECT=SHIFT_BB_DATA_0[COUNT_BB_DATA] -- a voir
				i_COUNT_BB_DATA <= std_logic_vector(unsigned(i_COUNT_BB_DATA) + 1);
				if unsigned(i_COUNT_BB_DATA) >= 31 then
					i_NEXT_STATE <= RESET_DATA_COUNTER;
				else
					i_NEXT_STATE <= WAIT_BACKSATTER_PREAMBLE;
				end if;
				
      when WAIT_BACKSATTER_PREAMBLE =>
				i_COUNT_IDLE_BACKSAT <= std_logic_vector(unsigned(i_COUNT_IDLE_BACKSAT) + 1);
				if unsigned(i_COUNT_IDLE_BACKSAT) >= 26 then 
					i_NEXT_STATE <= BACKSATTER_PREAMBLE;
				else
					i_NEXT_STATE <= WAIT_BACKSATTER_PREAMBLE;
				end if;
				
				when RESET_DATA_COUNTER =>
					i_COUNT_BB_DATA <= (others => '0');
					i_NEXT_STATE <= BACKSATTER;
			
      when BACKSATTER =>
				--ANA_MUX_DATA_IN_SELECT=SHIFT_BB_DATA_(Dec(REG_DATA_BANK_SELECT))[COUNT_BB_DATA]
				i_COUNT_BB_DATA <= std_logic_vector(unsigned(i_COUNT_BB_DATA) + 1);
				i_COUNT_IDLE_BACKSAT <= (others => '0');
				if unsigned(i_COUNT_BB_DATA) >= 31 then 
					i_NEXT_STATE <= REPEAT_DATA;
				else
					i_NEXT_STATE <= WAIT_BACKSATTER
				end if;
				
      when WAIT_BACKSATTER =>
				i_COUNT_IDLE_BACKSAT <= std_logic_vector(unsigned(i_COUNT_IDLE_BACKSAT) + 1);
				if unsigned(i_COUNT_IDLE_BACKSAT) >= 26 then 
					i_NEXT_STATE <= BACKSATTER_PREAMBLE;
				else
					i_NEXT_STATE <= WAIT_BACKSATTER_PREAMBLE;
				end if;
			
			when => REPEAT_DATA
				i_COUNT_BB_DATA <= '0';
				i_COUNT_DATA_BANK_REPEAT <= std_logic_vector(unsigned(i_COUNT_DATA_BANK_REPEAT) + 1);
				i_DELAY_DATA_BANK_REPEAT_COUNTER <= '0';
				if unsigned(i_COUNT_DATA_BANK_REPEAT) < unsigned(i_CFREG_DATA_BANK_REPEAT) then
					i_NEXT_STATE <= DELAY;
				else
					i_NEXT_STATE <= START_UP_LISTEN;
				end if;
			
      when DELAY =>
			i_DELAY_DATA_BANK_REPEAT_COUNTER <= std_logic_vector(unsigned(i_DELAY_DATA_BANK_REPEAT_COUNTER) + 1);
			if unsigned(i_DELAY_DATA_BANK_REPEAT_COUNTER) < unsigned i_CFREG_DELAY_DATA_BANK_REPEAT then
				i_NEXT_STATE <= DELAY;
			else
				if i_CFREG_REPEAT_WITH_PREAMB = '1' then
					i_NEXT_STATE <= BACKSATTER_PREAMBLE;
				else 
					i_NEXT_STATE <= BACKSATTER;
				end if;
			end if;
			
      when START_UP_LISTEN =>
				i_ANA_INTERFACE_IN_MODSELECT <= (others => '0');
				-- i_ANA_POWERREG_MODSELECT
				i_PORT_STA_LED <= "101";
				i_ANA_FREQ_DIVIDER_EN <= '0';
				-- i_ANA_MOD_EN <= '0';
				-- i_ANA_MUX_EN <= '0';
				if i_CONCATEN_FREQDIVIDER_POWERREG_INTERFACE = "00000" then 
					i_NEXT_STATE <= SLEEP;
				else
					i_NEXT_STATE <= START_UP_LISTEN;
				end if;
		end case;
	end process;              

end architecture rtl;