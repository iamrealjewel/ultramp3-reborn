Here are the most common frequency bands used in audio equalizers for music players, studio EQs, car audio systems, and apps like the one you're building for UltraMP3.

Standard EQ Frequency Bands
2-Band EQ

Basic consumer audio:

Band	Frequency Range	Controls
Bass	~20Hz–250Hz	Low-end thump, kick
Treble	~4kHz–20kHz	Brightness, clarity
3-Band EQ
Band	Frequency Range	Description
Bass	20Hz–250Hz	Sub-bass + punch
Mid	250Hz–4kHz	Vocals/instruments
Treble	4kHz–20kHz	Air/detail
Common 5-Band EQ

Very popular in Android music players.

Band	Center Frequency	Purpose
60Hz	Deep bass	Subwoofer rumble
230Hz	Bass warmth	Punch/fullness
910Hz	Midrange	Vocals
3.6kHz	Presence	Attack/clarity
14kHz	Air	Sparkle

This exact structure is extremely common in older music players.

Common 10-Band EQ

Most recognizable “pro consumer” EQ.

Band	Frequency
31Hz	
62Hz	
125Hz	
250Hz	
500Hz	
1kHz	
2kHz	
4kHz	
8kHz	
16kHz	

This is probably the most iconic equalizer layout ever made.

Common 15-Band EQ
Frequencies
25Hz
40Hz
63Hz
100Hz
160Hz
250Hz
400Hz
630Hz
1kHz
1.6kHz
2.5kHz
4kHz
6.3kHz
10kHz
16kHz
Common 31-Band Graphic EQ

Professional studio/live sound standard.

Bands are spaced in 1/3 octaves:

20, 25, 31.5, 40, 50, 63, 80, 100,
125, 160, 200, 250, 315, 400, 500, 630,
800, 1k, 1.25k, 1.6k, 2k, 2.5k, 3.15k,
4k, 5k, 6.3k, 8k, 10k, 12.5k, 16k, 20k
Frequency Meaning Cheat Sheet
Frequency	What You Hear
20–60Hz	Sub bass / rumble
60–120Hz	Bass punch
120–250Hz	Warmth
250–500Hz	Mud
500Hz–1kHz	Body
1kHz–2kHz	Vocal intelligibility
2kHz–4kHz	Presence / attack
4kHz–6kHz	Sharpness
6kHz–10kHz	Detail
10kHz–20kHz	Air / sparkle
For UltraMP3 Revival

You should probably implement:

Default
10-band EQ

Because users instantly recognize it.

Use:

31Hz
62Hz
125Hz
250Hz
500Hz
1kHz
2kHz
4kHz
8kHz
16kHz

This gives:

nostalgic Winamp/UltraMP3 feel
enough control
lightweight UI
mobile-friendly
Recommended Additional Effects

For a modern nostalgic player:

Effect	Worth Adding
Bass Boost	Yes
Virtualizer	Yes
Reverb presets	Yes
Stereo widening	Yes
Loudness normalization	Yes
Limiter	Yes
Crossfade	Nice
Tube/Warm mode	Very nice
Vinyl simulation	Optional
Industry Standard Gain Range

Most EQs use:

-12dB to +12dB

Some use:

±15dB
±24dB

But ±12dB is safest for mobile audio.

Common Presets

Popular presets users expect:

Normal
Classical
Dance
Flat
Folk
Heavy Metal
Hip Hop
Jazz
Pop
Rock
Bass Boost
Vocal Boost
Electronic
Acoustic
Piano

For the music player experience, presets matter almost as much as the EQ itself.