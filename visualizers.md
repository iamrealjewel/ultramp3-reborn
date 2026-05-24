The Two Main Ways Visualizers Work
1. Waveform Visualization

Shows the raw audio amplitude over time.

Example:

oscilloscope style
waveform line
voice recorder wave

It visualizes:

loudness
peaks
rhythm
Input:

PCM audio samples

Output:

Wave shape

2. Spectrum Visualization

Most common in music players.

It breaks audio into frequency bands:

bass
mids
treble

Then animates bars/circles/waves.

This is what Winamp, UltraMP3, Poweramp, etc. use.

How Spectrum Analysis Works

The key technology is:

FFT — Fast Fourier Transform

FFT converts:

Time-domain audio
→
Frequency-domain data

Meaning:

Instead of:

"speaker moves like this over time"

You get:

"there is strong bass at 60Hz and vocals at 2kHz"

Simplified Pipeline
Audio Stream
↓
PCM Buffer
↓
FFT Processing
↓
Frequency Bins
↓
Smoothing
↓
Animation Rendering
PCM Audio Data

Android audio players usually access audio as:

16-bit PCM samples

Example:

[0, 1200, -3400, 5000, -2000...]

These represent speaker movement amplitudes.

FFT Output

FFT produces frequency bins.

Example:

Bin	Frequency
0	31Hz
1	62Hz
2	125Hz
3	250Hz

Each bin has an intensity value.

Example:

31Hz → 0.9
62Hz → 0.7
125Hz → 0.4

This means:

strong bass
medium low-mid
weaker upper frequencies
Then The UI Animates

Example:

Frequency	Visual
Strong bass	Tall bars
Loud treble	Bright particles
Beat detected	Pulses
Stereo separation	Left/right movement