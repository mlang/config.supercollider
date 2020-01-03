var notes = Array.newClear(128);
[
	{
		MOTOR.noteOn(\unipolar, {|amp, num|
			notes[num] = Synth(\default, [
				\freq, num.midicps,
				\amp, amp
			])
		});
		MOTOR.noteOff({|vel, num| notes[num].set(\gate, 0) });
	},
	{ // free resources
		notes.do {|synth|
			synth.set(\gate, 0)
		};
		notes.free;
	}
]
