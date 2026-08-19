<CsoundSynthesizer>
<CsOptions>
-o golden_food.wav -W -d
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
	aenv expseg 0.001, 0.018, iamp, p3 - 0.018, 0.001
	a1 oscili aenv, ifreq
	a2 oscili aenv * 0.36, ifreq * 2.01
	a3 oscili aenv * 0.24, ifreq * 2.72
	a4 oscili aenv * 0.13, ifreq * 3.88
	asig = a1 + a2 + a3 + a4
	aleft = asig * sqrt(1 - ipan)
	aright = asig * sqrt(ipan)
	outs aleft, aright
endin

instr 2
	iamp = p4
	ifreq = p5
	aenv expseg 0.001, 0.025, iamp, p3 - 0.025, 0.001
	a1 oscili aenv, ifreq
	a2 oscili aenv * 0.28, ifreq * 1.505
	outs (a1 + a2) * 0.32, (a1 + a2) * 0.32
endin
</CsInstruments>
<CsScore>
; Warm, compact bell gesture for golden food.
i1 0.00 0.58 0.17 440.000 0.42
i1 0.10 0.54 0.13 554.365 0.57
i1 0.20 0.50 0.11 659.255 0.48
i2 0.02 0.62 0.08 880.000
e
</CsScore>
</CsoundSynthesizer>
