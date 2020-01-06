// BBCut
// =====================================================================

var clock, loops;
(
play: {
	clock = ExternalClock(TempoClock.default);
	clock.play;
	loops = [
		BBCut2(CutBuf1(~loop[4]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[4]), WarpCutProc1.new),
		BBCut2(CutBuf1(~loop[78]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[78]), WarpCutProc1.new),
		BBCut2(CutBuf1(~loop[46]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[68]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[38]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[11]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[10]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[32]), BBCutProc11.new),
		BBCut2(CutBuf1(~loop[7]), BBCutProc11.new)
	];
	loops.do {| loop, i |
		MOTOR.padOn(i+1, \midi) {
			loops[i].play(clock)
		}
	}
},
free: {
	loops.do {| loop |
		loop.free
	}
}
)
