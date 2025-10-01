-- VHDL-2008 testbench for CONTROL_MODULE
-- Drives the scenario:
--  - Listen duty cycle
--  - Power detected → START_UP_FSK → START_UP_BACKSCATTER → BACKSATTER
--  - 1 repeat with 1-cycle delay
--  - Sequence advances through nibbles until sentinel 1111; then back to listen duty cycle
--
-- Checks:
--  - LED/state-proxy at key points (LISTEN, SLEEP, START_UP_FSK, START_UP_BACKSCATTER, START_UP_LISTEN)
--  - LISTEN→SLEEP duty cycle timing
--  - BACKSATTER/WAIT timing: 27 cycles per bit (1 BACK + 26 WAIT)
--  - Boundary between repeat bursts has +3 cycles between address changes
--  - Boundary between sequence bursts has +4 cycles between address changes
--
-- Notes:
--  * We set CFREG_DATA_BANK_REPEAT_i to "0001" to match "1 repeat".
--  * We treat the scenario's "START_BACKSCATTER" label as "START_UP_BACKSCATTER".
--
-- Compile with VHDL-2008.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_CONTROL_MODULE is
end entity;

architecture tb of tb_CONTROL_MODULE is
  -- Clocking
  constant T_CLK : time := 10 ns;

  signal MAIN_CLK_i   : std_logic := '0';
  signal N_MAIN_RST_i : std_logic := '0';

  -- DUT I/O
  signal ANA_INTERFACE_IN_MODSELECT_o : std_logic;
  signal ADD_PD_OUT_OUTFLAG_i         : std_logic := '0';
  signal ADD_PD_STA_OUT_READY_i       : std_logic := '0';
  signal ANA_PD_EN_o                  : std_logic;

  signal ANA_MOD_EN_o                 : std_logic;
  signal ANA_FREQ_DIVIDER_EN_o        : std_logic;

  signal DATA_REG_MUX_SEL_DATA_o      : std_logic_vector(8 downto 0);
  signal DATA_REG_MUX_EN_o            : std_logic;
  signal ANA_MUX_EN_o                 : std_logic;

  signal CFREG_DATA_BANK_REPEAT_i         : std_logic_vector(3 downto 0) := (others => '0');
  signal CFREG_DATA_BANK_SELECT_i         : std_logic_vector(3 downto 0) := (others => '0');
  signal CFREG_DATA_BANK_SEQUENCE_i       : std_logic_vector(35 downto 0) := (others => '0');
  signal CFREG_DATA_SEL_SINGLE_SEQUENCE_i : std_logic := '0';
  signal CFREG_DELAY_DATA_BANK_REPEAT_i   : std_logic_vector(4 downto 0) := (others => '0');
  signal CFREG_FORCE_STATE_FSM_i          : std_logic_vector(7 downto 0) := (others => '0');
  signal CFREG_PREAMB_i                   : std_logic := '0';
  signal CFREG_REPEAT_WITH_PREAMB_i       : std_logic := '0';

  signal PORT_STA_LED_o               : std_logic_vector(2 downto 0);
  signal FLAG_POR_i                   : std_logic := '0';

  -- Helpers
  function slv_to_str(s : std_logic_vector) return string is
    variable r : string(1 to s'length);
  begin
    for i in s'range loop
      r(s'length - (i - s'low)) := character'VALUE( integer'IMAGE( to_integer(unsigned(s(i downto i))) )(2) );
      -- The above is clunky. A simpler way:
      -- r(s'length - (i - s'low)) := (s(i) = '1') ? '1' : '0'; -- but VHDL has no ternary
      if s(i) = '1' then
        r(s'length - (i - s'low)) := '1';
      else
        r(s'length - (i - s'low)) := '0';
      end if;
    end loop;
    return r;
  end function;

  procedure tick(n : natural := 1) is
  begin
    for k in 1 to n loop
      wait until rising_edge(MAIN_CLK_i);
    end loop;
  end procedure;

  procedure expect_led(constant expected : std_logic_vector(2 downto 0); constant note : string) is
  begin
    assert PORT_STA_LED_o = expected
      report "LED mismatch at " & note &
             ". expected=" & slv_to_str(expected) & " got=" & slv_to_str(PORT_STA_LED_o)
      severity error;
  end procedure;

  procedure expect_bool(constant cond : boolean; constant msg : string) is
  begin
    assert cond report msg severity error;
  end procedure;

  -- Check one 32-bit "burst" for a given nibble:
  --  - Expects address high nibble = expected_nibble throughout
  --  - Expects low 5 bits to step 0..31
  --  - Expects 27 cycles between successive address changes (1 BACK, then 26 WAIT)
  procedure check_one_burst(constant expected_nibble : std_logic_vector(3 downto 0)) is
    variable last_addr          : std_logic_vector(8 downto 0);
    variable curr_addr          : std_logic_vector(8 downto 0);
    variable cycles_since_change: natural := 0;
    variable lsb                : unsigned(4 downto 0);
  begin
    -- We assume we've just ENTERED BACKSATTER for bit 0 before calling this.
    curr_addr := DATA_REG_MUX_SEL_DATA_o;
    expect_bool(curr_addr(8 downto 5) = expected_nibble,
                "Burst nibble mismatch at start: expected " & slv_to_str(expected_nibble) &
                " got " & slv_to_str(curr_addr(8 downto 5)));
    expect_bool(curr_addr(4 downto 0) = "00000",
                "Burst did not start at bit 0.");

    last_addr := curr_addr;

    -- For bits 1..31:
    for b in 1 to 31 loop
      cycles_since_change := 0;
      loop
        tick(1);
        cycles_since_change := cycles_since_change + 1;
        curr_addr := DATA_REG_MUX_SEL_DATA_o;
        exit when curr_addr /= last_addr;
      end loop;

      -- Expect exactly 27 cycles between changes
      expect_bool(cycles_since_change = 27,
        "Bit interval not 27 cycles between bits " & integer'image(b-1) & " -> " & integer'image(b) &
        ". got " & integer'image(cycles_since_change));

      expect_bool(curr_addr(8 downto 5) = expected_nibble,
                  "Nibble changed within burst at bit " & integer'image(b));

      lsb := unsigned(curr_addr(4 downto 0));
      expect_bool(lsb = to_unsigned(b, 5),
                  "Bit counter mismatch at bit " & integer'image(b) &
                  ". got " & integer'image(to_integer(lsb)));

      last_addr := curr_addr;
    end loop;
    -- Now we are at BACKSATTER for bit 31; next cycle should be REPEAT_DATA (no WAIT).
  end procedure;

  -- Measure cycles between the LAST change of a burst (bit 31 BACKSATTER) and
  -- the FIRST change of the next burst (bit 0 BACKSATTER of next pass).
  -- Expected:
  --   - After REPEAT_DATA + DELAY + BACKSATTER => 3 cycles between changes
  --   - After REPEAT_DATA + SEQUENCE_NEXT + DELAY + BACKSATTER => 4 cycles
  function cycles_to_next_change return natural is
    variable start_addr  : std_logic_vector(8 downto 0) := DATA_REG_MUX_SEL_DATA_o;
    variable cycle_count : natural := 0;
  begin
    loop
      tick(1);
      cycle_count := cycle_count + 1;
      exit when DATA_REG_MUX_SEL_DATA_o /= start_addr;
    end loop;
    return cycle_count;
  end function;

begin
  -- Clock generator
  clk_gen : process
  begin
    MAIN_CLK_i <= '0';
    wait for T_CLK/2;
    MAIN_CLK_i <= '1';
    wait for T_CLK/2;
  end process;

  -- DUT
  uut: entity work.CONTROL_MODULE
    port map (
      MAIN_CLK_i                   => MAIN_CLK_i,
      N_MAIN_RST_i                 => N_MAIN_RST_i,
      ANA_INTERFACE_IN_MODSELECT_o => ANA_INTERFACE_IN_MODSELECT_o,
      ADD_PD_OUT_OUTFLAG_i         => ADD_PD_OUT_OUTFLAG_i,
      ADD_PD_STA_OUT_READY_i       => ADD_PD_STA_OUT_READY_i,
      ANA_PD_EN_o                  => ANA_PD_EN_o,
      ANA_MOD_EN_o                 => ANA_MOD_EN_o,
      ANA_FREQ_DIVIDER_EN_o        => ANA_FREQ_DIVIDER_EN_o,
      DATA_REG_MUX_SEL_DATA_o      => DATA_REG_MUX_SEL_DATA_o,
      DATA_REG_MUX_EN_o            => DATA_REG_MUX_EN_o,
      ANA_MUX_EN_o                 => ANA_MUX_EN_o,
      CFREG_DATA_BANK_REPEAT_i     => CFREG_DATA_BANK_REPEAT_i,
      CFREG_DATA_BANK_SELECT_i     => CFREG_DATA_BANK_SELECT_i,
      CFREG_DATA_BANK_SEQUENCE_i   => CFREG_DATA_BANK_SEQUENCE_i,
      CFREG_DATA_SEL_SINGLE_SEQUENCE_i => CFREG_DATA_SEL_SINGLE_SEQUENCE_i,
      CFREG_DELAY_DATA_BANK_REPEAT_i   => CFREG_DELAY_DATA_BANK_REPEAT_i,
      CFREG_FORCE_STATE_FSM_i      => CFREG_FORCE_STATE_FSM_i,
      CFREG_PREAMB_i               => CFREG_PREAMB_i,
      CFREG_REPEAT_WITH_PREAMB_i   => CFREG_REPEAT_WITH_PREAMB_i,
      PORT_STA_LED_o               => PORT_STA_LED_o,
      FLAG_POR_i                   => FLAG_POR_i
    );

  -- Stimulus & checks
  stim : process
    -- Expected useful nibble sequence (last 1111 = sentinel to stop)
    type nib_arr is array (natural range <>) of std_logic_vector(3 downto 0);
    constant NIBBLES : nib_arr := (
      "0000","0001","0010","0011","0100","0101","0111","1000","1111"
    );

    variable gap : natural;
  begin
    --------------------------------------------------------------------------
    -- Configuration per scenario
    --------------------------------------------------------------------------
    CFREG_FORCE_STATE_FSM_i        <= (others => '0');                         -- 00000000
    CFREG_DATA_BANK_SEQUENCE_i     <= x"01234578F";                             -- 0000 0001 0010 0011 0100 0101 0111 1000 1111
    CFREG_DELAY_DATA_BANK_REPEAT_i <= "00001";                                  -- 1 cycle delay
    CFREG_DATA_BANK_REPEAT_i       <= "0001";                                   -- 1 repeat
    CFREG_DATA_BANK_SELECT_i       <= (others => '0');
    CFREG_DATA_SEL_SINGLE_SEQUENCE_i <= '0';
    CFREG_PREAMB_i                 <= '0';
    CFREG_REPEAT_WITH_PREAMB_i     <= '0';
    ADD_PD_OUT_OUTFLAG_i           <= '0';
    ADD_PD_STA_OUT_READY_i         <= '0';
    FLAG_POR_i                     <= '0';

    --------------------------------------------------------------------------
    -- Reset low for 10 cycles
    --------------------------------------------------------------------------
    N_MAIN_RST_i <= '0';
    tick(10);

    -- Release reset; 1 cycle → expect LISTEN (LED=001)
    N_MAIN_RST_i <= '1';
    tick(1);
    expect_led("001", "LISTEN after reset release");

    -- 2 cycles → expect LISTEN_TO_SLEEP (check interface select=1)
    tick(2);
    expect_bool(ANA_INTERFACE_IN_MODSELECT_o = '1',
      "Expected LISTEN_TO_SLEEP (ANA_INTERFACE_IN_MODSELECT_o=1)");

    -- 1 cycle → expect SLEEP (LED=111)
    tick(1);
    expect_led("111", "SLEEP entry");

    -- 15 cycles SLEEP then next cycle SLEEP_TO_LISTEN (check PD_EN=1 and interface to PD=0)
    tick(15);
    tick(1); -- enter SLEEP_TO_LISTEN
    expect_bool(ANA_PD_EN_o = '1' and ANA_INTERFACE_IN_MODSELECT_o = '0',
      "Expected SLEEP_TO_LISTEN (ANA_PD_EN_o=1 and interface select=0)");

    -- Raise PD flag
    ADD_PD_OUT_OUTFLAG_i <= '1';

    -- 1 cycle → LISTEN (LED=001)
    tick(1);
    expect_led("001", "LISTEN after SLEEP_TO_LISTEN");

    -- 1 cycle → START_UP_FSK (LED=010)
    tick(1);
    expect_led("010", "START_UP_FSK");

    -- 1 cycle → START_UP_BACKSCATTER (LED=011)
    tick(1);
    expect_led("011", "START_UP_BACKSCATTER");

    -- 1 cycle → BACKSATTER (first bit of first nibble)
    tick(1);

    --------------------------------------------------------------------------
    -- For each usable nibble until sentinel 1111:
    --   - One 32-bit burst
    --   - REPEAT + 1-cycle DELAY → next 32-bit burst (same nibble)
    --   - Then SEQUENCE_NEXT + 1-cycle DELAY → next nibble
    --------------------------------------------------------------------------
    for idx in 0 to NIBBLES'length-2 loop  -- stop before sentinel 1111
      -- Burst #1 for nibble idx
      check_one_burst(NIBBLES(idx));

      -- Measure gap to next burst: REPEAT_DATA + DELAY + BACKSATTER = 3 cycles
      gap := cycles_to_next_change;
      expect_bool(gap = 3, "Expected 3-cycle gap after REPEAT (got " & integer'image(gap) & ")");

      -- Burst #2 (repeat) for same nibble
      check_one_burst(NIBBLES(idx));

      -- After second burst, the FSM goes: REPEAT_DATA → SEQUENCE_NEXT → (DELAY=1) → BACKSATTER
      -- So gap to next nibble's first bit should be 4 cycles
      if idx < NIBBLES'length-2 then
        gap := cycles_to_next_change;
        expect_bool(gap = 4, "Expected 4-cycle gap after SEQUENCE_NEXT (got " & integer'image(gap) & ")");
      end if;
    end loop;

    -- We are about to move past the last useful nibble ("1000") to the sentinel ("1111")
    -- Per scenario, drop PD flag now
    ADD_PD_OUT_OUTFLAG_i <= '0';

    -- After sentinel path, DUT should go to START_UP_LISTEN (LED=101), then LISTEN, etc.
    -- We’ll allow a few cycles for the final transitions:
    -- We just finished the second burst of the last useful nibble, so next gap is 4 cycles to the next action.
    gap := cycles_to_next_change; -- move to next change (start of hypothetical next burst or state path)
    -- From here, we expect the FSM to unwind to START_UP_LISTEN
    -- (The exact number of cycles depends on your internal counters; we check the LED milestones.)

    -- Give a few cycles to reach START_UP_LISTEN and then LISTEN duty cycle again
    -- In the DUT code, START_UP_LISTEN sets LED=101 immediately in that state.
    -- We'll search for that LED pattern within a window.
    variable found_startup_listen : boolean := false;
    for s in 1 to 10 loop
      if PORT_STA_LED_o = "101" then
        found_startup_listen := true;
        exit;
      end if;
      tick(1);
    end loop;
    expect_bool(found_startup_listen, "Expected START_UP_LISTEN (LED=101) after finishing sequence.");

    -- Next should be LISTEN (LED=001)
    -- Advance at most a few cycles to see LISTEN LED again
    variable found_listen : boolean := false;
    for s in 1 to 5 loop
      tick(1);
      if PORT_STA_LED_o = "001" then
        found_listen := true;
        exit;
      end if;
    end loop;
    expect_bool(found_listen, "Expected LISTEN (LED=001) after START_UP_LISTEN.");

    -- Then LISTEN_TO_SLEEP (interface select = 1 after 2 cycles in LISTEN)
    tick(2);
    expect_bool(ANA_INTERFACE_IN_MODSELECT_o = '1', "Expected LISTEN_TO_SLEEP (interface select=1)");

    -- Then SLEEP (LED=111)
    tick(1);
    expect_led("111", "SLEEP at end");

    -- 15 cycles + 1 to reach SLEEP_TO_LISTEN (check PD_EN and interface)
    tick(15);
    tick(1);
    expect_bool(ANA_PD_EN_o = '1' and ANA_INTERFACE_IN_MODSELECT_o = '0',
      "Expected SLEEP_TO_LISTEN at end");

    -- One more to return to LISTEN
    tick(1);
    expect_led("001", "LISTEN end-of-test");

    report "END OF TEST: PASS" severity note;
    wait;
  end process;

end architecture tb;
