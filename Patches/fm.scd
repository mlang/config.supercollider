// =====================================================================
// SuperCollider Frequency Modulation Patch
// =====================================================================

var notes = Array.newClear(128);
var keys = Group.new(s);
var fxBus = Bus.audio(s, 2);
var fx;

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

SynthDef(\fx, {|out=0, in|
	var signal = In.ar(in, 1);
	signal = AllpassC.ar(
		signal,
		0.04,
		{
			Rand(0.001, 0.04)
		} ! 32,
		2
	);
	signal = Splay.ar(signal);
	Out.ar(out, signal);
}).add;
SynthDef(\reverb, {
	arg in=0, out=0, dec=4, lpf=1500, amp=0.1;
	var sig;
	sig = In.ar(in, 2).sum * amp;

	sig = DelayN.ar(sig, 0.03, 0.03);
	sig = CombN.ar(sig, 0.1, {Rand(0.01,0.099)}!32, dec);
	sig = SplayAz.ar(2, sig);
	sig = LPF.ar(sig, lpf);
	5.do{
		sig = AllpassN.ar(sig, 0.1, {Rand(0.01,0.099)}!2, 2)
	};
	sig = LPF.ar(sig, lpf);
	sig = LeakDC.ar(sig);

	Out.ar(out, sig);
}).add;

fx = Synth.after(keys, \reverb, [\in, fxBus]);

MOTOR.bend([-2.midiratio, 2.midiratio, \lin, 0.0, 1.0]).connect(keys, \detune);
MOTOR.modwheel([1, 12, \lin, 0, 1]).connect(keys, \index);
MOTOR.encoder(1, [1, 128, \lin, 0, 1]).connect(keys, \cmul);
MOTOR.encoder(2, \midi).connect(keys, \mmul);

MOTOR.noteOn(\unipolar, {|amp, num|
	num !? {|num|
		notes[num] = Synth(\fm, [
			\freq, num.midicps,
			\detune, MOTOR.bend.value,
			\amp, amp,
			\index, MOTOR.modwheel.value,
			\cmul, MOTOR.encoder(1).value,
			\mmul, MOTOR.encoder(2).value,
			\fx, fx
		], keys);
	}
});
MOTOR.noteOff({ |vel, num|
	notes[num].set(\gate, 0)
});

{
	notes.do {|synth|
		synth.set(\gate, 0)
	};
	notes.free;
	fx.free;
	fxBus.free;
	keys.free;
	notes.free;
}
