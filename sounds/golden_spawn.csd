<CsoundSynthesizer>
<CsOptions>
-o golden_spawn.wav -W -d
</CsOptions>
<CsInstruments>
sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

instr 1
	iamp = p4
	ifreq = p5
	ipan = p6
	aenv expseg 0.001, 0.012, iamp, p3 - 0.012, 0.001
	a1 oscili aenv, ifreq
	a2 oscili aenv * 0.24, ifreq * 2.02
	a3 oscili aenv * 0.12, ifreq * 2.71
	asig = a1 + a2 + a3
	outs asig * sqrt(1 - ipan), asig * sqrt(ipan)
endin
</CsInstruments>
<CsScore>
; Short two-tone notification for a golden food spawn.
i1 0.00 0.18 0.13 523.251 0.44
i1 0.14 0.22 0.12 659.255 0.56
e
</CsScore>
</CsoundSynthesizer>
