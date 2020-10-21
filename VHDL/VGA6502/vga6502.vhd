library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga6502 is
    port
    (
        clk       : in std_logic;
        reset     : in std_logic;
        ma        : buffer std_logic_vector(11 downto 0);
        ra        : out std_logic_vector(3 downto 0);
        blank     : out std_logic;
        hsync     : out std_logic;
        vsync     : out std_logic;
        latch     : buffer std_logic;
        phi2      : in std_logic;
        rw        : in std_logic;
        rs        : in std_logic;
        cs        : in std_logic;
        data      : in std_logic_vector(7 downto 0);
        cursor    : out std_logic;
        bank      : out std_logic
    );

end entity;

architecture behavioral of vga6502 is
--- Mode 1 - 640x480@60Hz
--- Mode 2 - 640x400@60Hz
constant H_TOT: integer := 100;
constant H_FP:  integer := 2;
constant H_BP:  integer := 6;
constant H_SW:  integer := 12;

signal H_CNTR:  integer range 0 to 100;
signal H_END:   std_logic := '0';
signal H_BLANK: std_logic := '0';


constant V_TOT1: integer := 525;
constant V_FP1:  integer := 10;
constant V_SW1:  integer := 2;
constant V_BP1:  integer := 33;


constant V_TOT2: integer := 449;
constant V_FP2:  integer := 12;
constant V_SW2:  integer := 2;
constant V_BP2:  integer := 35;

signal V_TOT: integer;
signal V_FP: integer;
signal V_SW: integer;
signal V_BP: integer;

signal V_CNTR:  integer range 0 to 525;
signal V_BLANK: std_logic := '0';

signal CNT_CHAR:     integer range 0 to 4096;
signal REG_ROW:      integer range 0 to 4096;
signal CLK_CHARROW:  std_logic := '0';
signal CNT_SCANLINE: integer range 0 to 15;

signal CLK8:   std_logic := '0';
signal CLKDIV: std_logic_vector(2 downto 0);
signal SRDIV:  std_logic_vector(2 downto 0);

signal REG_STARTHI:         std_logic_vector(7 downto 0) := (others => '0');
signal REG_STARTLO:         std_logic_vector(7 downto 0) := (others => '0');
signal REG_CHARHEIGHT:      std_logic_vector(3 downto 0) := "0000";
signal REG_CURSORLOCATION:  std_logic_vector(11 downto 0);
signal CNT_CURSORFLASHER:   std_logic_vector(5 downto 0) := (others => '0');
signal REG_CURSENABLE:      std_logic;
signal REG_CURSORFLASHEREN: std_logic;
signal REG_BANK:            std_logic;
signal REG_MODE:            std_logic;
signal REG_PTR:             std_logic_vector(2 downto 0);

signal M_CURSOR: std_logic;
signal VIDEN: std_logic;
signal FF_CURSOR: std_logic;
signal FF_BLANK: std_logic;
signal FF_VSYNC: std_logic;
signal FF_HSYNC: std_logic;
signal M_VSYNC: std_logic;
signal M_HSYNC: std_logic;
 
begin

RA     (2 downto 0) <= std_logic_vector(to_unsigned(CNT_SCANLINE, RA'length)) (2 downto 0);
MA     <= std_logic_vector(to_unsigned(CNT_CHAR, MA'length));

VIDEN  <= (V_BLANK OR H_BLANK);
M_CURSOR <= '1' when (unsigned(REG_CURSORLOCATION) = unsigned(MA)) AND ((CNT_CURSORFLASHER(5) = '1' OR REG_CURSORFLASHEREN = '0') AND REG_CURSENABLE = '1' AND CNT_SCANLINE <= 10) else '0';

MODESWITCH:
process(REG_MODE)
begin
  if REG_MODE = '0' then
    V_TOT <= V_TOT1;
	 V_FP <= V_FP1;
	 V_SW <= V_SW1;
	 V_BP <= V_BP1;
	 RA (3) <= std_logic_vector(to_unsigned(CNT_SCANLINE, RA'length)) (3);
	 BANK <= '0';
  else
    V_TOT <= V_TOT2;
	 V_FP <= V_FP2;
	 V_SW <= V_SW2;
	 V_BP <= V_BP2;
	 RA (3) <= REG_BANK;
	 BANK <= '1';
  end if;
end process;

LATCH_PROC:
process(clk)
begin
  if rising_edge(clk) then
    if CLKDIV (2 downto 0) = "000" then
	   LATCH <= '0';
    else
	   LATCH <= '1';
	 end if;
  end if;
end process;

FF1:
process(clk)
begin
  if rising_edge(clk) then
    if LATCH = '0' then
	   FF_CURSOR <= M_CURSOR;
		FF_BLANK <= VIDEN;
		FF_VSYNC <= M_VSYNC XOR REG_MODE; /* Positive VSYNC for 640x400 mode */
		FF_HSYNC <= M_HSYNC;
	 else
	   FF_CURSOR <= FF_CURSOR;
		FF_BLANK <= FF_BLANK;
		FF_VSYNC <= FF_VSYNC;
		FF_HSYNC <= FF_HSYNC;
	 end if;
  end if;
end process;
CURSOR <= FF_CURSOR;
BLANK <= FF_BLANK;
VSYNC <= FF_VSYNC;
HSYNC <= FF_HSYNC;


DATA_PPORT:
process(phi2,cs,reset)
    begin
        if (reset = '0') then
            REG_BANK <= '0';
				REG_MODE <= '0';
            REG_CHARHEIGHT <= "1111";
            REG_CURSENABLE <= '1';
            REG_CURSORFLASHEREN <= '0';
            REG_CURSORLOCATION <= (others => '0');
        elsif (falling_edge(PHI2)) then
            if (cs = '0' and rw = '0') then
                if (rs = '0') then
                    REG_PTR <= data(2 downto 0);
                elsif (rs = '1') then
                    if (REG_PTR = "000") then
                        REG_STARTLO <= data;
                    elsif (REG_PTR = "001") then
                        REG_STARTHI <= data;
                    elsif (REG_PTR = "010") then
                        REG_BANK <= data(7);
                        REG_CURSENABLE <= data(6);
                        REG_CURSORFLASHEREN <= data(5);
                        REG_MODE <= data(4);
                        REG_CHARHEIGHT <= data(3 downto 0);
                    elsif (REG_PTR = "011") then
                        REG_CURSORLOCATION(7 downto 0) <= data;
                    elsif (REG_PTR = "100") then
                        REG_CURSORLOCATION(11 downto 8) <= data(3 downto 0);
                    end if;
                end if;
            end if;
        end if;
end process;

---
--- Clock Divider
--- Divides 25.175 Mhz Pixel clock by 8, i.e load one character every 8 clocks
---
charclk:
process(clk, reset)
begin
    if reset = '0' then
        CLKDIV <= (others => '0');
    elsif (falling_edge(clk)) then
        CLKDIV <= std_logic_vector(unsigned(CLKDIV)+1);
    end if;
end process;
CLK8 <= CLKDIV(2);

--
-- Horizontal
--

H_cnt:
process(clk8, reset)
begin
    if (reset = '0') then
        H_CNTR <= 0;
    elsif rising_edge(clk8) then
        if (H_CNTR = (H_TOT - 1)) then
            H_END <= '1';
            H_CNTR <= 0;
        else
            H_END <= '0';
            H_CNTR <= H_CNTR + 1;
        end if;
    end if;
end process;

H_display:
process(clk8)
begin
    if rising_edge(clk8) then
        if (H_CNTR >= (H_SW + H_BP)) AND (H_CNTR < (H_TOT - H_FP)) then
            H_BLANK <= '0';
        else
            H_BLANK <= '1';
        end if;
    end if;
end process;

H_sync:
process(clk8)
begin
    if rising_edge(clk8) then
        if (H_CNTR < H_SW) then
            M_HSYNC <= '0';
        else
            M_HSYNC <= '1';
        end if;
    end if;
end process;

---
--- Vertical
---

V_cnt:
process (H_END, reset)
begin
    if (reset = '0') then
        V_CNTR <= 0;
    elsif falling_edge(H_END) then
        if (V_CNTR = (V_TOT - 1)) then
            V_CNTR <= 0;
            CNT_CURSORFLASHER <= std_logic_vector(unsigned(CNT_CURSORFLASHER)+1);
        else
            V_CNTR <= V_CNTR +1;
        end if;
    end if;
end process;

V_display:
process(H_END)
begin
    if falling_edge(H_END) then
        if (V_CNTR >= (V_SW + V_BP)) AND (V_CNTR < (V_TOT - V_FP)) then
            V_BLANK <= '0';
        else
            V_BLANK <= '1';
        end if;
    end if;
end process;

V_SYNC:
process(H_END)
begin
    if falling_edge(H_END) then
        if (V_CNTR < V_SW) then
            M_VSYNC <= '0';
        else
            M_VSYNC <= '1';
        end if;
    end if;
end process;

---
--- Scanline Counter
--- Outputs RA row address to Char Rom
---
SL_cnt:
process(H_END, reset)
begin
    if (reset = '0') then
        CNT_SCANLINE <= 0;
    elsif falling_edge(H_END) then
        if (V_BLANK = '1') or (CNT_SCANLINE = unsigned(REG_CHARHEIGHT)) then
            CNT_SCANLINE <= 0;
        else
            CNT_SCANLINE <= CNT_SCANLINE + 1;
        end if;
   end if;
end process;

---
--- Char Row Clock
--- increment row count every CHARHEIGHT scanlines
---
CHARROW_CLK:
process(CNT_SCANLINE,REG_CHARHEIGHT)
begin
    if (CNT_SCANLINE = unsigned(REG_CHARHEIGHT)) then
        CLK_CHARROW <= '1';
    else
        CLK_CHARROW <= '0';
    end if;
end process;


---
--- Row Count
--- Start from REG_START for each frame, incrementing by 80 every time CLK_CHARROW increments
--- REG_START(H/L) Handles hard vertical scrolling by starting each frame from the specified memory offset.
---

ROW_CNT:
process(CLK_CHARROW)
begin
    if (V_BLANK = '1' OR RESET = '0')  then
        REG_ROW <= to_integer(unsigned(REG_STARTHI & REG_STARTLO));
    elsif falling_edge(CLK_CHARROW) then
        REG_ROW <= REG_ROW + 80;
    else
        REG_ROW <= REG_ROW;
    end if;
end process;

---
--- Char Counter
--- Generates linear memory addresses
---

CHAR_CNT:
process(reset,CLK8,H_END)
begin
    if (reset = '0') then
        CNT_CHAR <= 0;
    elsif rising_edge(CLK8) then
        if (H_BLANK = '0') then
            CNT_CHAR <= CNT_CHAR + 1;
        else
            CNT_CHAR <= REG_ROW;
        end if;
    end if;
end process;

end behavioral;