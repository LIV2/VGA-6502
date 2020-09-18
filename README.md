# VGA-6502
#### 16 colours, 640x480 or 640x400
## Description
A VGA card for my homebrew computer using the Altera EPM7128 CPLD  

![PCB](https://raw.githubusercontent.com/LIV2/VGA-6502/master/Images/pcb.png)  
![Palette](https://raw.githubusercontent.com/LIV2/VGA-6502/master/Images/palette.png)  
![Fractal](https://raw.githubusercontent.com/LIV2/VGA-6502/master/Images/fractal.png)  

Features:
* 16 Colors
* 640x480 and 640x400 modes
* Dual-port RAM
## Palette
|Low intensity|High Intensity|
|------|------|
| 0 - Black| 8 - Dark Gray|
| 1 - Red| 9 - Light Red|
| 2 - Green| 10 - Light Green|
| 3 - Yellow| 11 - Light Yellow|
| 4 - Blue| 12 - Light Blue|
| 5 - Magenta| 13- Light Magenta|
| 6 - Cyan| 14 - Light Cyan|
| 7 - Light Gray| 15 - White|

## Memory layout

### Memory map
GPU: $DF00 (configurable with J5-8)  
RAM: $A000-$BFFF (configurable with J2-4)

### Video RAM
Characters are stored on even addresses, followed by their colour on odd addresses.  
Foreground colour is stored in the lower nibble of the colour byte(s) while background colour is stored in the higher nibble of the colour byte(s)

Example: "Hello world!" with a green foreground and black background would be stored in memory as follows:

|$00|$01|$02|$03|$04|$05|$06|$07|$08|$09|$0A|$0B|$0C|$0D|$0E|$0F|$10|$11|$12|$13|$14|$15|$16|$17|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
'H'|$0A|'e'|$0A|'l'|$0A|'l'|$0A|'o'|$0A|' '|$0A|'w'|$0A|'o'|$0A|'r'|$0A|'l'|$0A|'d'|$0A|'!'|$0A|

## Registers  
**All registers are currently write-only as I did not have enough space in the CPLD to allow reading from the registers.**  
$DF00: Register Pointer  
$DF01: Register set by Register pointer  

|Register|Description|
|--------|-----------|
|$00|Memory start address(Low byte)|
|$01|Memory start address(High byte)|
|$02|Control register|
|$03|Cursor location (Low byte)|
|$04|Cursor location (High byte)|

### Register pointer (write only)
To access a register you first need to write the register address to the register pointer (default: $DF00), then read/write the register at (default: $DF01)

### Memory Start address (write only)
This register pair forms a 16-bit memory address defining the start of the visual screen, i.e at the start of each frame the VGA controller begins reading characters from here
### Control Register (write only)
The control register configures various settings for the VGA controller 


|Bit(s)|Description|
|------|-----------|
|7|Character ROM bank select|
|6|Cursor Enable|
|5|Cursor Flash|
|4|Mode|
|3..0|Character Height|

**Bank Select:** Switch font (only valid in Mode 1, 8 Pixel character height)  
**Cursor enable**: Enable the cursor  
**Cursor Flash**: Enable cursor flashing  
**Mode**: Mode 0: 640x480, Mode 1: 640x400  (mode 1 will select the 8x8 fonts from the CGROM)  
**Character Height**: Character height, Default: 0xF (16 pixels)

### Cursor location (write only)
This register pair forms a 16-bit address defining where the cursor should be displayed
