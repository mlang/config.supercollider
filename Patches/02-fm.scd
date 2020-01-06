// Frequency Modulation
// =====================================================================
var notes = Array.newClear(128);
var fxBus = Bus.audio(s, 2);
var keys;
var reverb;

SynthDef("fm", {
	arg	freq=440, detune=1, cmul=1, mmul=1, index=1,
	    gate=1, amp=0.5, pan=0, out=0, fx;
	var modulator, env, indexenv, ampenv, sig;

	freq = freq * detune;
    env = Env.adsr(0.01, 0.25, 0.325, 0.5);
	indexenv = EnvGen.ar(env, gate) * index;
	ampenv = EnvGen.kr(env, gate, amp, doneAction: Done.freeSelf);
	modulator = SinOsc.ar(freq*mmul, 0, freq*mmul*indexenv);
	sig = SinOsc.ar(freq*cmul+modulator, 0, ampenv);
	sig = Pan2.ar(sig, pan);
	Out.ar(fx, sig);
	Out.ar(out, sig);
}).add;

SynthDef(\reverb, {
	arg in=0, out=0, dec=4, lpf=1500, amp=0.1;
	var sig;

	sig = In.ar(in, 2).sum * amp;
	sig = DelayN.ar(sig, 0.03, 0.03);
	sig = CombN.ar(sig, 0.1, {Rand(0.01,0.099)} ! 32, dec);
	sig = SplayAz.ar(2, sig);
	sig = LPF.ar(sig, lpf);
	5.do {
		sig = AllpassN.ar(sig, 0.1, {Rand(0.01,0.099)} ! 2, 2)
	};
	sig = LPF.ar(sig, lpf);
	sig = LeakDC.ar(sig);

	Out.ar(out, sig);
}).add;

(
play: {
	keys = Group.new(s);
	reverb = Synth.after(keys, \reverb, [\in, fxBus]);

	MOTOR.bend(
		ControlSpec(-2.midiratio, 2.midiratio, \lin, default: 1.0)
	).connect(keys, \detune);
	MOTOR.modwheel(
		ControlSpec(1, 12, \lin, default: 1)
	).connect(keys, \index);
	MOTOR.encoder(1,
		ControlSpec(1, 128, \lin, step: 1, default: 1)
	).connect(keys, \cmul);
	MOTOR.encoder(2,
		ControlSpec(0, 127, \lin, step: 1, default: 0)
	).connect(keys, \mmul);
	
	MOTOR.noteOn(\unipolar, {|amp, num|
		num !? {|num|
			notes[num] = Synth(\fm, [
				\freq, num.midicps,
				\detune, MOTOR.bend.value,
				\amp, amp,
				\index, MOTOR.modwheel.value,
				\cmul, MOTOR.encoder(1).value,
				\mmul, MOTOR.encoder(2).value,
				\fx, fxBus
			], keys);
		}
	});
	MOTOR.noteOff { |vel, num|
		notes[num].set(\gate, 0)
	};
},
free: {
	notes.do {|synth| synth.set(\gate, 0) };
	notes.free;
	reverb.free;
	fxBus.free;
	keys.free;
}
)
