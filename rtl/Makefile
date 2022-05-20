PROJECT=vga6502
ATFPART=1508AS
WORKDIR=tmp
BINDIR=../bin
POF2JEDFLAGS=-device $(ATFPART) -slew slow -JTAG ON

.PHONY:	all clean flash

all:	$(BINDIR)/ATF$(ATFPART)/$(PROJECT).jed $(BINDIR)/$(PROJECT).svf $(BINDIR)/$(PROJECT).pof

$(BINDIR):
	mkdir -p $@

$(BINDIR)/ATF$(ATFPART): | $(BINDIR)
	mkdir -p $@

output_files/$(PROJECT).pof:	$(PROJECT).v $(PROJECT).qsf
	quartus_sh --flow compile $(PROJECT)

$(BINDIR)/ATF$(ATFPART)/$(PROJECT).jed:	output_files/$(PROJECT).pof | $(BINDIR)/ATF$(ATFPART)
	wine ~/.wine/drive_c/POF2JED/bin/POF2JED.exe $(POF2JEDFLAGS) -i $< -o $@
	- @rm -f $(BINDIR)/ATF$(ATFPART)/*.txt

$(BINDIR)/$(PROJECT).svf:	output_files/$(PROJECT).pof | $(BINDIR)
	quartus_cpf -c -q 100KHz -g 5 -n p $< $@

$(BINDIR)/$(PROJECT).pof:	output_files/$(PROJECT).pof | $(BINDIR)
	cp $< $@

flash:	output_files/$(PROJECT).pof
	quartus_pgm -mJTAG -o PV\;$(BINDIR)/$(PROJECT).pof

clean:
	- @rm -rf output_files ${BINDIR} incremental_db bin simulation

