var isActive = {|service, onActive, onInactive|
	[
		"systemctl", "--user", "--quiet", "is-active",
		service.asString
	].unixCmd{ |exitCode|
		if(exitCode == 0, onActive, onInactive)
	};
};
~patches = (
	thisProcess.nowExecutingPath.dirname +/+ "Patches" +/+ "*.scd"
).pathMatch.sort;
~currentPatch = 0;

c = Condition.new;
isActive.value("motu.service") {
	"Setting channels".postln;
	Server.default.options.numInputBusChannels = 8;
	Server.default.options.numOutputBusChannels = 4;
	c.test = true;
	c.signal;
} {
	Server.default.options.blockSize = 32;
	c.test = true;
	c.signal;
};

~samplesDir = "/home/mlang/annexus/samples";
// MIDI
MIDIClient.init(verbose: false);
MIDIIn.connectAll(verbose: false);
MIDIClient.destinations.detectIndex {|ep|
	ep.device == "MOTÖR49 Keyboard" and: ep.name == "MOTÖR49 Keyboard MIDI 1"
} !? {|index|
	MOTOR.midiOut = MIDIOut(0).connect(index);
	MOTOR.fader(\master, \db, s.volume = _).value = s.volume.volume;
	MOTOR.backward({
		~currentPatch = ~currentPatch - 1;
		~freePatch.value;
		~loadPatch.value;
	});
	MOTOR.forward({
		~currentPatch = ~currentPatch + 1;
		~freePatch.value;
		~loadPatch.value;
	});
	MOTOR.stop({ thisProcess.stop });
	MOTOR.play({ thisProcess.run });
	MOTOR.record({ if(s.isRecording, { s.stopRecording }, { s.record }) });
};

~brl = BrlOSC({|...args|args.postln}, {|...args|args.postln}, ":1");
~brl.addDependant({|brl, what, value|
	switch(what,
		\connected, { brl.grab },
		\acquired, { brl.write("Super Collider") }
	)
});
~loadPatch = {
	var patch = ~patches.wrapAt(~currentPatch);
	~brl.write(patch.basename);
	~freePatch = patch.load;
	Document.open(patch);
};

Routine.run( {
	c.wait;
	~brl.write("Server booting");
    s.bootSync(c);
	~brl.write("Server running");
	~loadPatch.value;
    TempoClock.default.tempo = 120/60;

	~encoder=Array.fill(4, {
		Array.fill(8, {
			Bus.control(s)
		})
	});
	32.do{|i|
		MOTOR.encoder(i+1, \unipolar, {|value, num, motor|
			var str = value.asString.keep(9).padRight(14-motor.spec.units.size) ++ motor.spec.units;
			~brl.write(str);
			~encoder[i div: 8][i % 8].value = value
		})
	};
	~fader=Array.fill(4, {
		Array.fill(8, {
			Bus.control(s)
		})
	});
	32.do{|i|
		MOTOR.fader(i+1, \unipolar, {|value, num, motor|
			var str = value.asString.keep(9).padRight(14-motor.spec.units.size) ++ motor.spec.units;
			~brl.write(str);
			~fader[i div: 8][i % 8].value = value
		})
	};

	~tabla = (~samplesDir +/+ "sounds/tabla*.wav").pathMatch.collect(
		Buffer.read(s,_)
	);
	~tabla.do {|buf, i|
		MOTOR.padOn(i+1, \unipolar, {|amp|
			Synth(\playbuf, [
				\bufnum, buf.bufnum,
				\amp, amp
			])
		})
	};

	SynthDef("playbuf", {
		arg out=0, bufnum=0, pan=0.0, rate=1.0, amp=1.0;
		var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum) * rate,
			doneAction: Done.freeSelf
		);
		sig = Pan2.ar(sig, pan, amp);
		Out.ar(out, sig)
	}).add;

	SynthDef("kick", {
		arg outBus=0;
		var env0, env1, env1m, out;

		env0 =  EnvGen.ar(Env.new([0.5, 1, 0.5, 0], [0.005, 0.06, 0.26], [-4, -2, -4]), doneAction:2);
		env1 = EnvGen.ar(Env.new([110, 59, 29], [0.005, 0.29], [-4, -5]));
		env1m = env1.midicps;

		out = LFPulse.ar(env1m, 0, 0.5, 1, -0.5);
		out = out + WhiteNoise.ar(1);
		out = LPF.ar(out, env1m*1.5, env0);
		out = out + SinOsc.ar(env1m, 0.5, env0);

		out = out * 1.2;
		out = out.clip2(1);

		Out.ar(outBus, out.dup);
	}).add;

	SynthDef("snare", {
		arg outBus=0, amp=0.8;
		var env0, env1, env2, env1m, oscs, noise, out;

		env0 = EnvGen.ar(Env.new([0.5, 1, 0.5, 0], [0.005, 0.03, 0.10], [-4, -2, -4]));
		env1 = EnvGen.ar(Env.new([110, 60, 49], [0.005, 0.1], [-4, -5]));
		env1m = env1.midicps;
		env2 = EnvGen.ar(Env.new([1, 0.4, 0], [0.05, 0.13], [-2, -2]), doneAction:2);

		oscs = LFPulse.ar(env1m, 0, 0.5, 1, -0.5) + LFPulse.ar(env1m * 1.6, 0, 0.5, 0.5, -0.25);
		oscs = LPF.ar(oscs, env1m*1.2, env0);
		oscs = oscs + SinOsc.ar(env1m, 0.8, env0);

		noise = WhiteNoise.ar(0.2);
		noise = HPF.ar(noise, 200, 2);
		noise = BPF.ar(noise, 6900, 0.6, 3) + noise;
		noise = noise * env2;

		out = oscs + noise;
		out = out.clip2(1) * amp;

		Out.ar(outBus, out.dup);
	}).add;

	SynthDef("clap", {
		arg outBus=0, amp = 0.5;
		var env1, env2, out, noise1, noise2;

		env1 = EnvGen.ar(Env.new([0, 1, 0, 1, 0, 1, 0, 1, 0], [0.001, 0.013, 0, 0.01, 0, 0.01, 0, 0.03], [0, -3, 0, -3, 0, -3, 0, -4]));
		env2 = EnvGen.ar(Env.new([0, 1, 0], [0.02, 0.3], [0, -4]), doneAction:2);

		noise1 = WhiteNoise.ar(env1);
		noise1 = HPF.ar(noise1, 600);
		noise1 = BPF.ar(noise1, 2000, 3);

		noise2 = WhiteNoise.ar(env2);
		noise2 = HPF.ar(noise2, 1000);
		noise2 = BPF.ar(noise2, 1200, 0.7, 0.7);

		out = noise1 + noise2;
		out = out * 2;
		out = out.softclip * amp;

		Out.ar(outBus, out.dup);
	}).add;

	SynthDef("hat", {
		arg outBus=0, amp=0.3;
		var env1, env2, out, oscs1, noise, n, n2;

		n = 5;
		thisThread.randSeed = 4;

		env1 = EnvGen.ar(Env.new([0, 1.0, 0], [0.001, 0.2], [0, -12]));
		env2 = EnvGen.ar(Env.new([0, 1.0, 0.05, 0], [0.002, 0.05, 0.03], [0, -4, -4]), doneAction:2);

		oscs1 = Mix.fill(n, {|i|
			SinOsc.ar(
				( i.linlin(0, n-1, 42, 74) + rand2(4.0) ).midicps,
				SinOsc.ar( (i.linlin(0, n-1, 78, 80) + rand2(4.0) ).midicps, 0.0, 12),
				1/n
			)
		});

		oscs1 = BHiPass.ar(oscs1, 1000, 2, env1);
		n2 = 8;
		noise = WhiteNoise.ar;
		noise = Mix.fill(n2, {|i|
			var freq;
			freq = (i.linlin(0, n-1, 40, 50) + rand2(4.0) ).midicps.reciprocal;
			CombN.ar(noise, 0.04, freq, 0.1)
		}) * (1/n) + noise;
		noise = BPF.ar(noise, 6000, 0.9, 0.5, noise);
		noise = BLowShelf.ar(noise, 3000, 0.5, -6);
		noise = BHiPass.ar(noise, 1000, 1.5, env2);

		out = noise + oscs1;
		out = out.softclip;
		out = out * amp;

		Out.ar(outBus, out.dup);
	}).add;

	SynthDef("acid", {
		arg outBus=0, gate=1, pitch=50, amp=0.1;
		var env1, env2, out;
		pitch = Lag.kr(pitch, 0.12 * (1-Trig.kr(gate, 0.001)) * gate);
		env1 = EnvGen.ar(Env.new([0, 1.0, 0, 0], [0.001, 2.0, 0.04], [0, -4, -4], 2), gate, amp);
		env2 = EnvGen.ar(Env.adsr(0.001, 0.8, 0, 0.8, 70, -4), gate);
		out = LFPulse.ar(pitch.midicps, 0.0, 0.51, 2, -1);

		out = RLPF.ar(out, (pitch + env2).midicps, 0.3);
		out = out * env1;

		Out.ar(outBus, out.dup);
	}).add;

	SynthDef("fx", {
		arg outBus=0, gate=0;
		var out;

		out = In.ar(outBus, 2);
		out = FreeVerb2.ar( BPF.ar(out[0], 3500, 1.5), BPF.ar(out[1], 3500, 1.5), 1.0, 0.95, 0.15) * EnvGen.kr(Env.new([0.02, 0.3, 0.02], [0.4, 0.01], [3, -4], 1), 1-Trig.kr(gate, 0.01)) + out;
		out = HPF.ar(out * 1.2, 40);
		out = Limiter.ar(out, 1.0, 0.02);

		ReplaceOut.ar(outBus, out);
	}).add;

    s.sync(c);

	Pbind(*[
		instrument: \acid,
		pitch: Pseq([39,42,46,51]),
		dur: Pseq([Pn(0.25, 3), 0.5], 1)
    ]).play;
})