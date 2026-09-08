This conversation was generated with Duck.ai (https://duck.ai) using OpenAI's GPT-5.6 Luna Model. AI chats may display inaccurate or offensive information (see https://duckduckgo.com/duckai/privacy-terms for more info).

====================

User prompt 1 of 4:
compare mmtty to fldigi decoding

Assist:
MMTTY is generally considered more accurate for decoding RTTY signals consistently, while FLDigi may struggle with weak signals and has slower response times. Users have reported that MMTTY can dig out weak signals better than FLDigi in recent versions.

Relevant sources:
- https://community.flexradio.com/discussion/comment/16176323
- https://www.w1hkj.org/FldigiHelp/rtty_page.html

--------------------

User prompt 2 of 4 - 9/6/2026, 10:39:22 AM:
are there any better decoders than mmtty then?

GPT-5.6 Luna:
<!-- **Clarifying recommendations**

It looks like I need to provide a current recommendation. I should make sure to use proper nouns and related terms as I search for this information. I'm a little unsure what "RTTY" refers to, so that’s something I’ll need to clarify as I gather the information. Searching seems like the best next step to get accurate details for the user! -->
Yes—**GRITTY** is the main alternative I’d try if your priority is extracting callsigns and text from weak or fading RTTY signals. Its Bayesian decoder estimates bit and character error probabilities, suppresses unreliable garbage, and can combine repeated or partially corrupted callsigns. It is Windows-only and older, but its decoding approach is distinctive. <citation src="2"></citation>

Other worthwhile options:

- **2Tone:** The best practical companion to MMTTY, especially for contesting. It can decode signals that MMTTY misses under certain noise, flutter, or tuning conditions, though it is not consistently superior. Running MMTTY and 2Tone together is often more effective than replacing MMTTY outright. <citation src="3,4"></citation>
- **TrueTTY:** A capable Windows decoder worth testing, particularly if you want another demodulator or integrated operating setup. It is less commonly recommended today than MMTTY or 2Tone. <citation src="1"></citation>
- **FLdigi:** Convenient and cross-platform, but generally not my first choice when maximum RTTY copy accuracy is the goal.
- **Multiple MMTTY instances:** Often the strongest “upgrade.” Run two instances with different demodulators—such as **IIR**, **FIR**, and **PLL**—so one may handle flutter or selective fading better than another. Multiple independent decoders provide useful diversity. <citation src="1,4"></citation>

My recommendation:

1. Keep **MMTTY** as your primary decoder.
2. Add **2Tone** as a second, parallel decoder.
3. Try **GRITTY** for very weak, fading, or partially corrupted signals.
4. Compare at least two decoders before trusting a callsign or exchange.

There is no universal winner: MMTTY is often strongest for normal contest signals, while 2Tone or GRITTY may produce the decisive copy when the signal is badly distorted.

--------------------

User prompt 3 of 4 - 9/6/2026, 10:40:39 AM:
how do all three decoders share the same soundcard as the radio just has the single soundcard provided byits usb interface

GPT-5.6 Luna:
They can all receive the same radio audio because the computer can duplicate one input stream to multiple applications. You do **not** need three physical sound cards.

The most reliable arrangement is:

1. Configure the radio’s USB audio device as the input in your logging or RTTY software.
2. Use a virtual audio router to create multiple copies of that input.
3. Assign one virtual output to each decoder.

Typical Windows choices include **VB-Audio Hi-Fi Cable**, **VB-CABLE**, or **Virtual Audio Cable**. The routing would look like:

```text
Radio USB audio input
          │
          ▼
Virtual audio mixer/router
     ├──► MMTTY
     ├──► 2Tone
     └──► GRITTY
```

With **VB-Audio VoiceMeeter**, for example:

- Set the radio’s USB audio device as the hardware input.
- Enable three virtual outputs.
- Select a different virtual output as the audio input for each decoder.
- Set all decoders to the same sample rate—normally 8,000 or 11,025 Hz, depending on the software.
- Use the same center frequency and filter bandwidth in each decoder.

An easier option is to use a host program that supports decoder “audio broadcasting.” For example, **N1MM+** can interface with MMTTY and 2Tone, while programs such as **RCKSkimmer** or other RTTY applications may provide their own audio distribution. In that setup, the host receives the radio audio once and feeds copies to the decoders.

You can sometimes select the same physical USB soundcard directly in all three applications, but this is less dependable. Some Windows audio devices permit multiple simultaneous readers; others lock the device to the first application, resample inconsistently, or introduce different latency. A virtual mixer avoids most of those problems.

For transmitting, use only one application to control PTT and keying. Multiple decoders may listen simultaneously, but they should not all be configured to transmit or independently control the radio.

--------------------

User prompt 4 of 4 - 9/6/2026, 10:42:39 AM:
write that up in an .md file I can download. Include more info on adding the audio broadcasting feature you menitoned so I can add that to my own logging program

GPT-5.6 Luna:
<!--  -->
<!--  -->
I can’t attach a generated file directly here, but the following is ready to save as `rtty-multiple-decoders.md`. I’ve also corrected one point from my previous answer: in N1MM+, “audio broadcasting” is better understood as the logger managing multiple decoder instances and their input paths—not necessarily a universal audio-streaming API that other logging programs can call.

```markdown
# Using Multiple RTTY Decoders with One Radio USB Soundcard

This guide explains how to feed the same RTTY audio from a radio’s single USB audio interface to multiple decoders, such as MMTTY, 2Tone, and GRITTY.

The examples assume a Windows computer and an amateur-radio transceiver with a built-in USB soundcard.

## 1. Basic concept

A radio’s USB interface normally appears to Windows as:

- A USB audio recording device for received audio
- A USB audio playback device for transmitted audio
- One or more virtual serial ports for CAT control, PTT, or FSK

Only one physical receive audio device is required. The computer can distribute copies of the received audio to several decoder processes.

```text
Radio USB receive audio
          |
          v
   Audio distribution
      /       |       \
     v        v        v
  MMTTY     2Tone    GRITTY
```

The decoders should all receive the same audio, with the same sample rate, channel selection, and frequency alignment.

## 2. Three ways to distribute the audio

### Method A: Let each decoder open the radio soundcard

Some Windows audio devices allow several applications to open the same input simultaneously.

Configure MMTTY, 2Tone, and GRITTY to use the radio’s USB receive device directly.

Advantages:

- No additional software
- Lowest conceptual complexity
- Usually adequate for simple testing

Disadvantages:

- Some soundcard drivers allow only one application to open the device
- Applications may select different sample rates
- Windows may resample one or more audio streams
- One decoder may obtain exclusive access and prevent the others from working
- Troubleshooting is less predictable

Use this method first if all three decoders open the device successfully and decode identical audio.

### Method B: Use a virtual audio mixer

A virtual audio mixer provides one input and several virtual outputs.

A typical arrangement is:

```text
Radio USB audio input
          |
          v
   Virtual audio mixer
      /       |       \
     v        v        v
MMTTY input  2Tone input  GRITTY input
```

Common Windows tools include:

- VoiceMeeter
- VB-CABLE
- Virtual Audio Cable

The exact device names depend on the software installed.

A mixer is usually the most flexible approach because it allows you to:

- Duplicate the audio stream
- Control levels independently
- Select left or right audio channels
- Prevent exclusive-mode conflicts
- Add recording, filtering, or monitoring
- Feed a spectrum display as well as decoders

## 3. Example VoiceMeeter configuration

The following is a general configuration; device names may vary.

### 3.1 Install and start VoiceMeeter

1. Install VoiceMeeter and its virtual audio components.
2. Restart Windows if requested.
3. Open VoiceMeeter.
4. Select the radio’s USB receive audio device as a hardware input.

The radio may appear under a name similar to:

```text
USB Audio CODEC
USB Audio Device
[Radio model] USB Audio
```

Use the recording/input device associated with the radio’s received audio.

### 3.2 Set the audio format

Choose one sample rate and use it throughout the chain.

A practical choice is:

```text
Sample rate: 48000 Hz
Channels: stereo or mono as appropriate
```

Some older RTTY decoders work better at 11025 Hz or 8000 Hz. If a decoder requires one of those rates, either configure the entire chain to that rate or use a virtual cable that performs the conversion.

Avoid unnecessary sample-rate conversions.

### 3.3 Create decoder outputs

Route the VoiceMeeter input to separate virtual outputs. Depending on the VoiceMeeter version, these may be labeled something like:

```text
B1
B2
B3
```

Assign:

```text
B1 -> MMTTY
B2 -> 2Tone
B3 -> GRITTY
```

The virtual outputs may appear in Windows as separate recording devices.

### 3.4 Configure each decoder

In each decoder, select the corresponding virtual recording device:

```text
MMTTY -> VoiceMeeter Output B1
2Tone -> VoiceMeeter Output B2
GRITTY -> VoiceMeeter Output B3
```

Set all decoders to:

- The same RTTY shift
- The same baud rate
- The same mark frequency
- The same receive bandwidth
- The same audio channel
- The same polarity/inversion setting

For standard amateur RTTY, common settings are:

```text
Baud rate: 45.45 baud
Shift: 170 Hz
Mark frequency: approximately 2125 Hz
Space frequency: approximately 2295 Hz
```

The exact mark frequency is not important as long as the decoder and radio audio passband are aligned.

## 4. Using N1MM Logger+ with multiple decoders

N1MM Logger+ supports MMTTY and can also use 2Tone in an MMTTY-type interface. Additional receive-only windows can be configured for other decoders.

The normal arrangement is:

```text
N1MM Logger+
   |
   +-- Main digital interface -> MMTTY or 2Tone
   |
   +-- Additional RX window -> 2Tone
   |
   +-- Additional RX window -> GRITTY
```

N1MM+ documentation describes configuring additional receive windows by opening:

```text
Setup > Add. RX Windows > Open Add. RX Window
```

For a 2Tone or GRITTY receive-only window, the window may be configured as an MMTTY-type window while its executable path is changed to the desired decoder.

Each decoder instance generally needs its own directory because decoder configuration files are often stored alongside the executable. This is especially important when running more than one copy of the same decoder.

A practical directory layout is:

```text
C:\RTTY\MMTTY-main\
C:\RTTY\2Tone-main\
C:\RTTY\2Tone-secondary\
C:\RTTY\GRITTY\
```

Do not have multiple independent instances share configuration files unless the decoder documentation explicitly supports that arrangement.

## 5. Important correction about “audio broadcasting”

“Audio broadcasting” is not a single universal RTTY protocol or API.

There are two different meanings:

### 5.1 Audio distribution by the operating system

This is the virtual-mixer approach described above. A mixer receives audio once and exposes multiple virtual recording devices.

This is the most general solution and works with almost any decoder.

```text
One physical audio input
        |
        v
Virtual mixer
  |     |     |
  v     v     v
Decoder Decoder Decoder
```

### 5.2 Audio distribution performed by a logging application

A logging application can also:

1. Open the radio’s audio input once.
2. Read blocks of PCM audio.
3. Copy each block into separate decoder input buffers.
4. Send each copy to an integrated decoder or an external decoder interface.

This is what an application-specific multi-decoder architecture does. It is not automatically compatible with arbitrary standalone programs.

N1MM+ provides configuration and integration for multiple digital decoder windows, but a custom logging program should not assume that MMTTY, 2Tone, or GRITTY all accept the same network or pipe-based audio protocol.

For a custom logging program, the safest design is usually one of these:

- Use a virtual audio device and let each decoder open its own input.
- Integrate a decoder library directly into the logging program.
- Implement a documented decoder-specific interface.
- Launch decoder processes and connect them through a defined IPC mechanism.

## 6. Designing audio broadcasting in your own logging program

If you are writing your own logging program, treat the audio broadcaster as a producer and each decoder as a consumer.

### 6.1 Audio pipeline

```text
Radio capture device
        |
        v
Capture thread
        |
        v
Ring buffer or block queue
   /          |          \
  v           v           v
MMTTY path  2Tone path  GRITTY path
```

The capture thread should read audio continuously and place fixed-size PCM blocks into buffers.

A typical block might contain:

```text
Format: signed 16-bit PCM
Channels: mono
Sample rate: 48000 Hz
Block size: 10–100 ms
```

For example:

```text
48000 samples/second
10 ms block = 480 samples
16-bit mono block = 960 bytes
```

### 6.2 Use independent consumer buffers

Each decoder needs its own queue.

Do not let one slow decoder stop the others.

```text
capture_queue_mmtty
capture_queue_2tone
capture_queue_gritty
```

If one decoder falls behind:

- Limit its queue size
- Drop the oldest or newest blocks according to your policy
- Record an overrun counter
- Keep the capture thread running

The primary decoder should normally receive priority.

### 6.3 Keep timestamps

Attach a monotonic timestamp or sample index to every audio block.

Example:

```text
AudioBlock {
    uint64_t first_sample;
    uint32_t sample_rate;
    uint16_t channels;
    uint16_t format;
    uint32_t frame_count;
    int16_t samples[];
}
```

Timestamps help diagnose:

- Decoder latency
- Queue overruns
- Different decoder delays
- Audio gaps
- Synchronization problems

### 6.4 Avoid unnecessary processing

If the decoders expect raw receiver audio, do not independently apply AGC, noise reduction, compression, or filtering to each stream unless that is intentional.

A good default is:

```text
Radio audio -> identical PCM copy -> all decoders
```

If filtering is required, apply the same filter before duplication so that decoder comparisons remain meaningful.

### 6.5 Handle stereo correctly

Many radios expose stereo USB audio even when the RTTY signal is effectively mono.

Your program should explicitly select one of these modes:

- Left channel
- Right channel
- Mono sum
- Stereo pass-through

Do not silently sum channels if one channel contains a different receiver or a separate audio path.

For a single receiver, mono is usually simplest:

```text
mono[n] = left[n]
```

or, when appropriate:

```text
mono[n] = (left[n] + right[n]) / 2
```

## 7. Connecting to external decoders

The difficult part is not duplicating audio; it is defining how an external decoder receives it.

Possible approaches include:

### 7.1 Virtual audio devices

Your program sends audio to a virtual playback device. Each decoder opens a corresponding virtual recording device.

Advantages:

- Works with programs that only support soundcards
- No decoder-specific protocol needed
- Easy to test

Disadvantages:

- Requires installing virtual audio software
- Adds system configuration
- May introduce resampling or latency

### 7.2 Named pipes

Your program writes PCM blocks to a named pipe and a decoder-side adapter reads them.

```text
Logger -> named pipe -> adapter -> decoder
```

This requires an adapter unless the decoder natively supports named-pipe input.

Define:

- Sample format
- Sample rate
- Channel count
- Block framing
- Reconnection behavior
- End-of-stream behavior

### 7.3 TCP or UDP audio transport

TCP is appropriate when every audio block must arrive in order.

UDP can reduce latency but requires your protocol to handle:

- Packet loss
- Reordering
- Sequence numbers
- Clock drift
- Buffering

For local-machine use, named pipes or shared memory are usually simpler than TCP/UDP.

### 7.4 Shared memory ring buffer

A shared-memory ring buffer is efficient for several local decoder processes.

A basic design contains:

```text
Header:
    magic number
    version
    sample rate
    channel count
    sample format
    write index
    sequence number

Audio region:
    fixed-size PCM blocks
```

Each consumer maintains its own read index.

Advantages:

- Low overhead
- Low latency
- No audio-device conflicts

Disadvantages:

- More complex synchronization
- Requires a separate decoder adapter
- More difficult to debug than virtual audio

## 8. Decoder control versus audio transport

Separate these responsibilities in your design.

### Audio transport

Moves received PCM samples to decoders.

### Decoder configuration

Sets:

- Baud rate
- Shift
- Mark frequency
- Polarity
- AFC behavior
- Filtering
- Demodulator type

### Decoder output

Returns decoded text and possibly:

- Confidence values
- Character error estimates
- Signal quality
- Frequency offset
- Callsign candidates

### Radio control

Handles:

- Frequency
- Mode
- PTT
- CAT commands
- FSK keying or AFSK transmission

Do not allow multiple receive-only decoders to independently control PTT or transmit audio.

A good arrangement is:

```text
Radio control: logging program only
Transmit control: one selected decoder or logging program
Receive audio: shared by all decoders
```

## 9. Recommended custom-program architecture

For a new logging program, use this order of implementation:

1. Capture audio from the radio USB device.
2. Display a waveform or spectrum to confirm valid audio.
3. Save a short WAV recording.
4. Feed that recording to one decoder.
5. Add live audio duplication.
6. Add a second decoder.
7. Add per-decoder latency and overrun monitoring.
8. Add decoder text normalization and comparison.
9. Add callsign and exchange extraction.
10. Add radio control and transmission last.

A useful internal interface is:

```text
IAudioConsumer
    start(format)
    pushAudio(block)
    stop()
```

Each decoder adapter implements the same interface:

```text
MMTTYConsumer
TwoToneConsumer
GrittyConsumer
```

The broadcaster does not need to know decoder-specific details.

## 10. Comparing decoder output

When several decoders produce text, do not blindly choose the longest result.

Useful comparison logic includes:

- Normalize case
- Remove repeated spaces
- Compare callsign-like tokens
- Prefer text repeated by two or more decoders
- Retain decoder source and timestamp
- Display disagreements to the operator
- Never automatically transmit an uncertain callsign

Example:

```text
MMTTY:  CQ TEST DE K1ABC
2Tone:  CQ TEST DE K1ABC
GRITTY: CQ TEST DE K1A8C
```

The repeated result is probably:

```text
K1ABC
```

However, the operator should remain in control, especially when a callsign or exchange affects logging accuracy.

## 11. Troubleshooting checklist

### Only one decoder receives audio

- Check whether the radio soundcard is in exclusive mode.
- Use a virtual audio mixer.
- Verify that each decoder has a different input device.
- Check that the virtual outputs are not muted.

### Audio is present but no decoder copies

- Confirm the correct left/right channel.
- Check the RTTY audio frequency.
- Verify baud rate and shift.
- Ensure the receiver filter is wide enough.
- Check audio levels for clipping or excessive attenuation.

### Decoders disagree badly

- Confirm identical sample rates.
- Confirm identical mark-frequency alignment.
- Check polarity and inversion.
- Disable unnecessary noise reduction.
- Check that one decoder is not receiving delayed audio.

### Text is delayed

- Reduce virtual-mixer buffering.
- Reduce decoder audio block size.
- Check queue depth.
- Monitor for CPU overload.
- Avoid running several unnecessary spectrum displays.

### Transmit audio is affected

- Use one transmit path only.
- Do not route decoder receive outputs back into the radio playback device.
- Keep the receive mixer and transmit mixer paths separate.
- Verify that PTT is controlled by only one application.

## 12. Practical recommendation

For immediate use:

```text
Radio USB audio
      |
      v
VoiceMeeter or another virtual mixer
   /       |       \
  v        v        v
MMTTY    2Tone    GRITTY
```

For a custom logging program:

```text
Radio capture thread
        |
        v
Shared PCM audio broadcaster
   /          |          \
  v           v           v
Decoder      Decoder     Decoder
adapter      adapter     adapter
```

Start with virtual audio devices. Move to named pipes or shared memory only if you need tighter integration, lower latency, or direct access to decoder confidence data.
```

The key implementation point is that a custom logger should not assume there is one standard “audio broadcasting feature” shared by all three decoders. A virtual audio device is the compatibility layer; a native broadcaster requires decoder-specific adapters or direct decoder integration. N1MM+ supports multiple digital-interface and additional receive windows, including configurations using 2Tone in place of MMTTY and receive-only decoder windows. <citation src="1,2,3"></citation>