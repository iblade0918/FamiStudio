﻿using System;
using System.Linq;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace FamiStudio
{
    public class NsfFile
    {
        // NSF memory layout
        //   0x8000: start of code
        //   0x8000: nsf_init
        //   0x8060: nsf_play
        //   0x8080: FamiTone kernel code (variable size depending on expansion)
        //   0x8???: song table of content, 4 bytes per song:
        //      - first page of the song (1 byte)
        //      - address of the start of the song in page starting at 0x9000 (2 byte)
        //      - flags (1 = use DPCM)
        //   0x????: DPCM samples, if any.
        //   0x????: Song data.

        const int NsfMemoryStart     = 0x8000;
        const int NsfInitAddr        = 0x8000; // Hardcoded in asm config.
        const int NsfPlayAddr        = 0x8060; // Hardcoded in asm config.
        const int NsfKernelAddr      = 0x8080; // Hardcoded in asm config.
        const int NsfDpcmOffset      = 0xc000;
        const int NsfPageSize        = 0x1000;

        const int NsfGlobalVarsSize     = 2;
        const int NsfSongTableEntrySize = 4;

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        unsafe struct NsfHeader
        {
            public fixed byte id[5];
            public byte version;
            public byte numSongs;
            public byte startingSong;
            public ushort loadAddr;
            public ushort initAddr;
            public ushort playAddr;
            public fixed byte song[32];
            public fixed byte artist[32];
            public fixed byte copyright[32];
            public ushort playSpeedNTSC;
            public fixed byte banks[8];
            public ushort playSpeedPAL;
            public byte palNtscFlags;
            public byte extensionFlags;
            public byte reserved;
            public fixed byte programSize[3];
        };

        public unsafe bool Save(Project originalProject, FamitoneMusicFile.FamiToneKernel kernel, string filename, int[] songIds, string name, string author, string copyright, MachineType mode)
        {
            try
            {
                if (songIds.Length == 0)
                    return false;

                Debug.Assert(!originalProject.UsesExpansionAudio || mode == MachineType.NTSC);

                var project = originalProject.DeepClone();
                project.RemoveAllSongsBut(songIds);

                // Header
                var header = new NsfHeader();
                header.id[0] = (byte)'N';
                header.id[1] = (byte)'E';
                header.id[2] = (byte)'S';
                header.id[3] = (byte)'M';
                header.id[4] = (byte)0x1a;
                header.version = 1;
                header.numSongs = (byte)project.Songs.Count;
                header.startingSong = 1;
                header.loadAddr = 0x8000;
                header.initAddr = NsfInitAddr;
                header.playAddr = NsfPlayAddr;
                header.playSpeedNTSC = 16639;
                header.playSpeedPAL = 19997;
                header.palNtscFlags = (byte)mode;
                header.extensionFlags = (byte)(project.ExpansionAudio == Project.ExpansionNone ? 0 : 1 << (project.ExpansionAudio - 1));
                header.banks[0] = 0;
                header.banks[1] = 1;
                header.banks[2] = 2;
                header.banks[3] = 3;
                header.banks[4] = 4;
                header.banks[5] = 5;
                header.banks[6] = 6;
                header.banks[7] = 7;

                var nameBytes      = Encoding.ASCII.GetBytes(name);
                var artistBytes    = Encoding.ASCII.GetBytes(author);
                var copyrightBytes = Encoding.ASCII.GetBytes(copyright);

                Marshal.Copy(nameBytes,      0, new IntPtr(header.song),      Math.Min(31, nameBytes.Length));
                Marshal.Copy(artistBytes,    0, new IntPtr(header.artist),    Math.Min(31, artistBytes.Length));
                Marshal.Copy(copyrightBytes, 0, new IntPtr(header.copyright), Math.Min(31, copyrightBytes.Length));

                var headerBytes = new byte[sizeof(NsfHeader)];
                Marshal.Copy(new IntPtr(&header), headerBytes, 0, headerBytes.Length);

                List<byte> nsfBytes = new List<byte>();

                string kernelBinary = "nsf";
                if (kernel == FamitoneMusicFile.FamiToneKernel.FamiStudio)
                {
                    kernelBinary += "_famistudio";

                    if (project.UsesExpansionAudio)
                    {
                        kernelBinary += $"_{project.ExpansionAudioShortName.ToLower()}";

                        if (project.ExpansionAudio == Project.ExpansionN163)
                            kernelBinary += $"_{project.ExpansionNumChannels}ch";
                    }
                }
                else
                {
                    kernelBinary += "_famitone2";
                }

                switch (mode)
                {
                    case MachineType.NTSC: kernelBinary += "_ntsc"; break;
                    case MachineType.PAL:  kernelBinary += "_pal";  break;
                    case MachineType.Dual: kernelBinary += "_dual"; break;
                }

                if (project.UsesFamiStudioTempo)
                {
                    kernelBinary += "_tempo";
                }

                kernelBinary += ".bin";

                // Code/sound engine
                var nsfBinStream = typeof(NsfFile).Assembly.GetManifestResourceStream("FamiStudio.Nsf." + kernelBinary);
                var nsfBinBuffer = new byte[nsfBinStream.Length - 128]; // Skip header.
                nsfBinStream.Seek(128, SeekOrigin.Begin);
                nsfBinStream.Read(nsfBinBuffer, 0, nsfBinBuffer.Length);

                nsfBytes.AddRange(nsfBinBuffer);

                var songTableIdx  = nsfBytes.Count;
                var songTableSize = NsfGlobalVarsSize + project.Songs.Count * NsfSongTableEntrySize;

                nsfBytes.AddRange(new byte[songTableSize]);

                var songDataIdx  = nsfBytes.Count;
                var dpcmBaseAddr = NsfDpcmOffset;
                var dpcmPadding  = 0;

                if (project.UsesSamples)
                {
                    var totalSampleSize = project.GetTotalSampleSize();

                    // Samples need to be 64-bytes aligned.
                    nsfBytes.AddRange(new byte[64 - (nsfBytes.Count & 0x3f)]);

                    // We start putting the samples right after the code, so the first page is not a
                    // full one. If we have near 16KB of samples, we might go over the 4 page limit.
                    // In this case, we will introduce padding until the next page.
                    if (nsfBytes.Count + totalSampleSize > Project.MaxSampleSize)
                    {
                        dpcmPadding = NsfPageSize - (nsfBytes.Count & (NsfPageSize - 1));
                        nsfBytes.AddRange(new byte[dpcmPadding]);
                    }

                    var dpcmPageStart = (nsfBytes.Count) / NsfPageSize;
                    var dpcmPageEnd   = (nsfBytes.Count + totalSampleSize - 1) / NsfPageSize;
                    var dpcmPageCount = dpcmPageEnd - dpcmPageStart + 1;

                    // Otherwise we will allocate at least a full page for the samples and use the following mapping:
                    //    0KB -  4KB samples: starts at 0xf000
                    //    4KB -  8KB samples: starts at 0xe000
                    //    8KB - 12KB samples: starts at 0xd000
                    //   12KB - 16KB samples: starts at 0xc000
                    dpcmBaseAddr += (4 - dpcmPageCount) * NsfPageSize + (nsfBytes.Count & (NsfPageSize - 1));

                    nsfBytes.AddRange(project.GetPackedSampleData());

                    nsfBytes[songTableIdx + 0] = (byte)dpcmPageStart; // DPCM_PAGE_START
                    nsfBytes[songTableIdx + 1] = (byte)dpcmPageCount; // DPCM_PAGE_CNT
                }

                // Export each song individually, build TOC at the same time.
                for (int i = 0; i < project.Songs.Count; i++)
                {
                    var song = project.Songs[i];
                    var firstPage = nsfBytes.Count < NsfPageSize;
                    int page = nsfBytes.Count / NsfPageSize + (firstPage ? 1 : 0);
                    int addr = NsfMemoryStart + (firstPage ? 0 : NsfPageSize ) + (nsfBytes.Count & (NsfPageSize - 1));
                    var songBytes = new FamitoneMusicFile(kernel).GetBytes(project, new int[] { song.Id }, addr, dpcmBaseAddr, mode);

                    // If we introduced padding for the samples, we can try to squeeze a song in there.
                    if (songBytes.Length < dpcmPadding)
                    {
                        // TODO. We should start writing at [songDataIdx] until we run out of dpcmPadding.
                    }

                    var idx = songTableIdx + NsfGlobalVarsSize + i * NsfSongTableEntrySize;
                    nsfBytes[idx + 0] = (byte)(page);
                    nsfBytes[idx + 1] = (byte)((addr >> 0) & 0xff);
                    nsfBytes[idx + 2] = (byte)((addr >> 8) & 0xff);
                    nsfBytes[idx + 3] = (byte)0;

                    nsfBytes.AddRange(songBytes);
                }

                // Finally insert the header, not very efficient, but easy.
                nsfBytes.InsertRange(0, headerBytes);

                File.WriteAllBytes(filename, nsfBytes.ToArray());
            }
            catch
            {
                return false;
            }

            return true;
        }

#if FAMISTUDIO_WINDOWS
        private const string NotSoFatsoDll = "NotSoFatso.dll";
#elif FAMISTUDIO_MACOS
        private const string NotSoFatsoDll = "NotSoFatso.dylib";
#else
        private const string NotSoFatsoDll = "NotSoFatso.so";
#endif

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static IntPtr NsfOpen(string file);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static int NsfGetTrackCount(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static int NsfIsPal(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static int NsfGetExpansion(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static IntPtr NsfGetTitle(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static IntPtr NsfGetArtist(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static IntPtr NsfGetCopyright(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static IntPtr NsfGetTrackName(IntPtr nsf, int track);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static void NsfClose(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static void NsfSetTrack(IntPtr nsf, int track);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static int NsfRunFrame(IntPtr nsf);

        [DllImport(NotSoFatsoDll, CallingConvention = CallingConvention.StdCall)]
        public extern static int NsfGetState(IntPtr nsf, int channel, int state, int sub);

        const int EXTSOUND_VRC6  = 0x01;
        const int EXTSOUND_VRC7  = 0x02;
        const int EXTSOUND_FDS   = 0x04;
        const int EXTSOUND_MMC5  = 0x08;
        const int EXTSOUND_N163  = 0x10;
        const int EXTSOUND_S5B   = 0x20;

        const int STATE_VOLUME             = 0;
        const int STATE_PERIOD             = 1;
        const int STATE_DUTYCYCLE          = 2;
        const int STATE_DPCMSAMPLELENGTH   = 3;
        const int STATE_DPCMSAMPLEADDR     = 4;
        const int STATE_DPCMSAMPLEDATA     = 5;
        const int STATE_DPCMLOOP           = 6;
        const int STATE_DPCMPITCH          = 7;
        const int STATE_FDSWAVETABLE       = 8;
        const int STATE_FDSMODULATIONTABLE = 9;
        const int STATE_FDSMODULATIONDEPTH = 10;
        const int STATE_FDSMODULATIONSPEED = 11;
        const int STATE_FDSMASTERVOLUME    = 12;
        const int STATE_VRC7PATCH          = 13;
        const int STATE_VRC7PATCHREG       = 14;
        const int STATE_VRC7OCTAVE         = 15;
        const int STATE_VRC7TRIGGER        = 16;
        const int STATE_VRC7SUSTAIN        = 17;
        const int STATE_N163WAVEPOS        = 18;
        const int STATE_N163WAVESIZE       = 19;
        const int STATE_N163WAVE           = 20;
        const int STATE_N163NUMCHANNELS    = 21;

        class ChannelState
        {
            public const int Triggered = 1;
            public const int Released  = 2;
            public const int Stopped   = 0;

            public int  period  = -1;
            public int  note    =  0;
            public int  pitch   =  0;
            public int  volume  = 15;
            public int  octave  = -1;
            public int  trigger = Stopped;

            public int fdsModDepth = 0;
            public int fdsModSpeed = 0;

            public Instrument instrument = null;
        };

        IntPtr nsf;
        Song song;
        Project project;
        ChannelState[] channelStates;

        public int GetBestMatchingNote(int period, ushort[] noteTable, out int finePitch)
        {
            int bestNote = -1;
            int minDiff  = 9999999;

            for (int i = 0; i < noteTable.Length; i++)
            {
                var diff = Math.Abs(noteTable[i] - period);
                if (diff < minDiff)
                {
                    minDiff = diff;
                    bestNote = i;
                }
            }

            finePitch = period - noteTable[bestNote];

            return bestNote;
        }

        private Pattern GetOrCreatePattern(Channel channel, int patternIdx)
        {
            if (channel.PatternInstances[patternIdx] == null)
                channel.PatternInstances[patternIdx] = channel.CreatePattern();
            return channel.PatternInstances[patternIdx];
        }

        private Instrument GetDutyInstrument(Channel channel, int duty)
        {
            var expansion = channel.IsExpansionChannel && project.NeedsExpansionInstruments ? project.ExpansionAudio : Project.ExpansionNone;
            var expPrefix = expansion == Project.ExpansionNone ? "" : Project.ExpansionShortNames[expansion] + " ";
            var name = $"{expPrefix}Duty {duty}";

            var instrument = project.GetInstrument(name);
            if (instrument == null)
            {
                instrument = project.CreateInstrument(expansion, name);
                instrument.Envelopes[Envelope.DutyCycle].Length = 1;
                instrument.Envelopes[Envelope.DutyCycle].Values[0] = (sbyte)duty;
            }

            return instrument;
        }

        private Instrument GetFdsInstrument(sbyte[] wavEnv, sbyte[] modEnv, byte masterVolume)
        {
            foreach (var inst in project.Instruments)
            {
                if (inst.ExpansionType == Project.ExpansionFds)
                {
                    if (inst.FdsMasterVolume == masterVolume &&
                        wavEnv.SequenceEqual(inst.Envelopes[Envelope.FdsWaveform].Values.Take(64)) &&
                        modEnv.SequenceEqual(inst.Envelopes[Envelope.FdsModulation].Values.Take(32)))
                    {
                        return inst;
                    }
                }
            }

            for (int i = 1; ; i++)
            {
                var name = $"FDS {i}";
                if (project.IsInstrumentNameUnique(name))
                {
                    var instrument = project.CreateInstrument(Project.ExpansionFds, name);

                    Array.Copy(wavEnv, instrument.Envelopes[Envelope.FdsWaveform].Values,   64);
                    Array.Copy(modEnv, instrument.Envelopes[Envelope.FdsModulation].Values, 32);

                    instrument.FdsMasterVolume = masterVolume;
                    instrument.FdsWavePreset   = Envelope.WavePresetCustom;
                    instrument.FdsModPreset    = Envelope.WavePresetCustom;

                    return instrument;
                }
            }
        }

        private Instrument GetVrc7Instrument(byte patch, byte[] patchRegs)
        {
            if (patch == 0)
            {
                // Custom instrument, look for a match.
                foreach (var inst in project.Instruments)
                {
                    if (inst.ExpansionType == Project.ExpansionVrc7)
                    {
                        if (inst.Vrc7Patch == 0 && inst.Vrc7PatchRegs.SequenceEqual(patchRegs))
                            return inst;
                    }
                }

                for (int i = 1; ; i++)
                {
                    var name = $"VRC7 Custom {i}";
                    if (project.IsInstrumentNameUnique(name))
                    {
                        var instrument = project.CreateInstrument(Project.ExpansionVrc7, name);
                        instrument.Vrc7Patch = patch;
                        Array.Copy(patchRegs, instrument.Vrc7PatchRegs, 8);
                        return instrument;
                    }
                }
            }
            else
            {
                // Built-in patch, simply find by name.
                var name = $"VRC7 {Instrument.GetVrc7PatchName(patch)}";
                var instrument = project.GetInstrument(name);

                if (instrument == null)
                {
                    instrument = project.CreateInstrument(Project.ExpansionVrc7, name);
                    instrument.Vrc7Patch = patch;
                }

                return instrument;
            }
        }

        private Instrument GetN163Instrument(sbyte[] waveData, byte wavePos)
        {
            foreach (var inst in project.Instruments)
            {
                if (inst.ExpansionType == Project.ExpansionN163)
                {
                    if (inst.N163WavePos  == wavePos &&
                        inst.N163WaveSize == waveData.Length &&
                        waveData.SequenceEqual(inst.Envelopes[Envelope.N163Waveform].Values.Take(waveData.Length)))
                    {
                        return inst;
                    }
                }
            }

            for (int i = 1; ; i++)
            {
                var name = $"N163 {i}";
                if (project.IsInstrumentNameUnique(name))
                {
                    var instrument = project.CreateInstrument(Project.ExpansionN163, name);

                    instrument.N163WavePreset = Envelope.WavePresetCustom;
                    instrument.N163WaveSize   = (byte)waveData.Length;
                    instrument.N163WavePos    = wavePos;
                    Array.Copy(waveData, instrument.Envelopes[Envelope.N163Waveform].Values, waveData.Length);

                    return instrument;
                }
            }
        }

        private Instrument GetS5BInstrument()
        {
            foreach (var inst in project.Instruments)
            {
                if (inst.ExpansionType == Project.ExpansionS5B)
                    return inst;
            }

            return project.CreateInstrument(Project.ExpansionS5B, "S5B");
        }
        
        private bool UpdateChannel(int p, int n, Channel channel, ChannelState state)
        {
            var project = channel.Song.Project;
            var channelIdx = Channel.ChannelTypeToIndex(channel.Type);
            var hasNote = false;

            if (channel.Type == Channel.Dpcm)
            {
                var len = NsfGetState(nsf, channel.Type, STATE_DPCMSAMPLELENGTH, 0) - 1;

                if (len > 0) 
                {
                    var sampleData = new byte[len];
                    for (int i = 0; i < len; i++)
                        sampleData[i] = (byte)NsfGetState(nsf, channel.Type, STATE_DPCMSAMPLEDATA, i);

                    var sample = project.FindMatchingSample(sampleData);
                    if (sample == null)
                        sample = project.CreateDPCMSample($"Sample {project.Samples.Count + 1}", sampleData);

                    var loop  = NsfGetState(nsf, channel.Type, STATE_DPCMLOOP, 0) != 0;
                    var pitch = NsfGetState(nsf, channel.Type, STATE_DPCMPITCH, 0);

                    var note = project.FindDPCMSampleMapping(sample, pitch, loop);
                    if (note == -1)
                    {
                        for (int i = Note.DPCMNoteMin + 1; i <= Note.DPCMNoteMax; i++)
                        {
                            if (project.GetDPCMMapping(i) == null)
                            {
                                note = i;
                                project.MapDPCMSample(i, sample, pitch, loop);
                                break;
                            }
                        }
                    }

                    if (note != -1)
                    {
                        var pattern = GetOrCreatePattern(channel, p).GetOrCreateNoteAt(n).Value = (byte)note;
                        hasNote = true;
                    }
                }
            }
            else
            {
                var period  = NsfGetState(nsf, channel.Type, STATE_PERIOD, 0);
                var volume  = NsfGetState(nsf, channel.Type, STATE_VOLUME, 0);
                var duty    = NsfGetState(nsf, channel.Type, STATE_DUTYCYCLE, 0);
                var force   = false;
                var stop    = false;
                var release = false;
                var octave  = -1;

                // VRC6 has a much larger volume range (6-bit) than our volume (4-bit).
                if (channel.Type == Channel.Vrc6Saw)
                {
                    volume >>= 2;
                }
                else if (channel.Type == Channel.FdsWave)
                {
                    volume = Math.Min(Note.VolumeMax, volume >> 1);
                }
                else if (channel.Type >= Channel.Vrc7Fm1 && channel.Type <= Channel.Vrc7Fm6)
                {
                    volume = 15 - volume;
                }

                var hasTrigger = true;
                var hasPeriod  = true;
                var hasOctave  = channel.Type >= Channel.Vrc7Fm1 && channel.Type <= Channel.Vrc7Fm6;
                var hasVolume  = channel.Type != Channel.Triangle;
                var hasPitch   = channel.Type != Channel.Noise;
                var hasDuty    = channel.Type == Channel.Square1 || channel.Type == Channel.Square2 || channel.Type == Channel.Noise || channel.Type == Channel.Vrc6Square1 || channel.Type == Channel.Vrc6Square2 || channel.Type == Channel.Mmc5Square1 || channel.Type == Channel.Mmc5Square2;

                if (channel.Type >= Channel.Vrc7Fm1 && channel.Type <= Channel.Vrc7Fm6)
                {
                    var trigger = NsfGetState(nsf, channel.Type, STATE_VRC7TRIGGER, 0) != 0;
                    var sustain = NsfGetState(nsf, channel.Type, STATE_VRC7SUSTAIN, 0) != 0;
                    var triggerState = trigger ? ChannelState.Triggered : (sustain ? ChannelState.Released : ChannelState.Stopped);

                    if (triggerState != state.trigger)
                    {
                        stop    = triggerState == ChannelState.Stopped;
                        release = triggerState == ChannelState.Released;
                        force |= true;
                        state.trigger = triggerState;
                    }

                    octave = NsfGetState(nsf, channel.Type, STATE_VRC7OCTAVE, 0);
                }
                else
                {
                    if (hasTrigger)
                    {
                        var trigger = volume != 0 ? ChannelState.Triggered : ChannelState.Stopped;

                        if (trigger != state.trigger)
                        {
                            stop = trigger == ChannelState.Stopped;
                            force |= true;
                            state.trigger = trigger;
                        }
                    }
                }

                if (hasVolume)
                {
                    if (state.volume != volume && volume != 0)
                    {
                        var pattern = GetOrCreatePattern(channel, p).GetOrCreateNoteAt(n).Volume = (byte)volume;
                        state.volume = volume;
                    }
                }

                Instrument instrument = null;

                if (hasDuty)
                {
                    instrument = GetDutyInstrument(channel, duty);
                }
                else if (channel.Type == Channel.FdsWave)
                {
                    var wavEnv = new sbyte[64];
                    var modEnv = new sbyte[32];

                    for (int i = 0; i < 64; i++)
                        wavEnv[i] = (sbyte)NsfGetState(nsf, channel.Type, STATE_FDSWAVETABLE, i);
                    for (int i = 0; i < 32; i++)
                        modEnv[i] = (sbyte)NsfGetState(nsf, channel.Type, STATE_FDSMODULATIONTABLE, i);

                    Envelope.ConvertFdsModulationToAbsolute(modEnv);

                    var masterVolume = (byte)NsfGetState(nsf, channel.Type, STATE_FDSMASTERVOLUME, 0);

                    instrument = GetFdsInstrument(wavEnv, modEnv, masterVolume);

                    int modDepth = NsfGetState(nsf, channel.Type, STATE_FDSMODULATIONDEPTH, 0);
                    int modSpeed = NsfGetState(nsf, channel.Type, STATE_FDSMODULATIONSPEED, 0);

                    if (state.fdsModDepth != modDepth)
                    {
                        var pattern = GetOrCreatePattern(channel, p).GetOrCreateNoteAt(n).FdsModDepth = (byte)modDepth;
                        state.fdsModDepth = modDepth;
                    }

                    if (state.fdsModSpeed != modSpeed)
                    {
                        var pattern = GetOrCreatePattern(channel, p).GetOrCreateNoteAt(n).FdsModSpeed = (ushort)modSpeed;
                        state.fdsModSpeed = modSpeed;
                    }
                }
                else if (channel.Type >= Channel.N163Wave1 &&
                         channel.Type <= Channel.N163Wave8)
                {
                    var wavePos = (byte)NsfGetState(nsf, channel.Type, STATE_N163WAVEPOS,  0);
                    var waveLen = (byte)NsfGetState(nsf, channel.Type, STATE_N163WAVESIZE, 0);

                    if (waveLen > 0)
                    {
                        var waveData = new sbyte[waveLen];
                        for (int i = 0; i < waveLen; i++)
                            waveData[i] = (sbyte)NsfGetState(nsf, channel.Type, STATE_N163WAVE, wavePos + i);

                        instrument = GetN163Instrument(waveData, wavePos);
                    }

                    period >>= 2; 
                }
                else if (channel.Type >= Channel.Vrc7Fm1 &&
                         channel.Type <= Channel.Vrc7Fm6)
                {
                    var patch = (byte)NsfGetState(nsf, channel.Type, STATE_VRC7PATCH, 0);
                    var regs = new byte[8];

                    if (patch == 0)
                    {
                        for (int i = 0; i < 8; i++)
                            regs[i] = (byte)NsfGetState(nsf, channel.Type, STATE_VRC7PATCHREG, i);
                    }

                    instrument = GetVrc7Instrument(patch, regs);
                }
                else if (channel.Type >= Channel.S5BSquare1 && channel.Type <= Channel.S5BSquare3)
                {
                    instrument = GetS5BInstrument();
                }
                else 
                {
                    instrument = GetDutyInstrument(channel, 0);
                }

                if ((hasPeriod && state.period != period) || (hasOctave && state.octave != octave) || (instrument != state.instrument) || force)
                {
                    var noteTable = NesApu.GetNoteTableForChannelType(channel.Type, false, project.ExpansionNumChannels);
                    var note = release ? Note.NoteRelease : (stop ? Note.NoteStop : state.note);
                    var finePitch = 0;

                    if (!stop && !release && state.trigger != ChannelState.Stopped)
                    {
                        if (channel.Type == Channel.Noise)
                            note = (period ^ 0x0f) + 32;
                        else
                            note = (byte)GetBestMatchingNote(period, noteTable, out finePitch);

                        if (hasOctave)
                        {
                            while (note > 12)
                            {
                                note -= 12;
                                octave++;
                            }
                            note += octave * 12;
                            period *= (1 << octave);
                            finePitch = period - noteTable[note];
                        }
                    }

                    if (note < Note.MusicalNoteMin || note > Note.MusicalNoteMax)
                        instrument = null;

                    if ((state.note != note) || (state.instrument != instrument && instrument != null) || force)
                    {
                        var pattern = GetOrCreatePattern(channel, p);
                        var newNote = pattern.GetOrCreateNoteAt(n);
                        newNote.Value = (byte)note;
                        newNote.Instrument = instrument;
                        state.note = note;
                        state.octave = octave;
                        if (instrument != null)
                            state.instrument = instrument;
                        hasNote = note != 0;
                    }

                    if (hasPitch && !stop)
                    {
                        Channel.GetShiftsForType(channel.Type, project.ExpansionNumChannels, out int pitchShift, out _);

                        // We scale all pitches changes (slides, fine pitch, pitch envelopes) for
                        // some channels with HUGE pitch values (N163, VRC7).
                        finePitch >>= pitchShift;

                        var pitch = (sbyte)Utils.Clamp(finePitch, Note.FinePitchMin, Note.FinePitchMax);

                        if (pitch != state.pitch)
                        {
                            var pattern = GetOrCreatePattern(channel, p).GetOrCreateNoteAt(n).FinePitch = pitch;
                            state.pitch = pitch;
                        }
                    }

                    state.period = period;
                }
            }

            return hasNote;
        }

        public static string[] GetSongNames(string filename)
        {
            var nsf = NsfOpen(filename);

            if (nsf == null)
                return null;

            var trackCount = NsfGetTrackCount(nsf);
            var trackNames = new string[trackCount];

            for (int i = 0; i < trackCount; i++)
            {
                var name = Marshal.PtrToStringAnsi(NsfGetTrackName(nsf, i));
                if (string.IsNullOrEmpty(name))
                {
                    trackNames[i] = $"Song {i+1}";
                }
                else
                {
                    trackNames[i] = name;
                }
            }

            NsfClose(nsf);

            return trackNames;
        }

        private int GetNumNamcoChannels(string filename, int songIndex, int numFrames)
        {
            var tmpNsf = NsfOpen(filename);

            NsfSetTrack(tmpNsf, songIndex);

            int numNamcoChannels = 1;
            for (int i = 0; i < numFrames; i++)
            {
                NsfRunFrame(tmpNsf);
                numNamcoChannels = Math.Max(numNamcoChannels, NsfGetState(tmpNsf, Channel.N163Wave1, STATE_N163NUMCHANNELS, 0));
            }

            NsfClose(tmpNsf);

            return numNamcoChannels;
        }

        public Project Load(string filename, int songIndex, int duration, int patternLength, int startFrame, bool removeIntroSilence)
        {
            nsf = NsfOpen(filename);

            if (nsf == null)
                return null;

            var numFrames = duration * (NsfIsPal(nsf) != 0 ? 50 : 60);

            project = new Project();

            project.Name      = Marshal.PtrToStringAnsi(NsfGetTitle(nsf));
            project.Author    = Marshal.PtrToStringAnsi(NsfGetArtist(nsf));
            project.Copyright = Marshal.PtrToStringAnsi(NsfGetCopyright(nsf));

            switch (NsfGetExpansion(nsf))
            {
                case EXTSOUND_VRC6: project.SetExpansionAudio(Project.ExpansionVrc6); break;
                case EXTSOUND_VRC7: project.SetExpansionAudio(Project.ExpansionVrc7); break;
                case EXTSOUND_FDS:  project.SetExpansionAudio(Project.ExpansionFds);  break;
                case EXTSOUND_MMC5: project.SetExpansionAudio(Project.ExpansionMmc5); break;
                case EXTSOUND_N163: project.SetExpansionAudio(Project.ExpansionN163, GetNumNamcoChannels(filename, songIndex, numFrames)); break;
                case EXTSOUND_S5B:  project.SetExpansionAudio(Project.ExpansionS5B);  break;
                case 0: break;
                default:
                    NsfClose(nsf); // Unsupported expansion combination.
                    return null;
            }

            var songName = Marshal.PtrToStringAnsi(NsfGetTrackName(nsf, songIndex));

            song = project.CreateSong(string.IsNullOrEmpty(songName) ? $"Song {songIndex + 1}" : songName);
            channelStates = new ChannelState[song.Channels.Length];

            NsfSetTrack(nsf, songIndex);

            song.ResizeNotes(1, false);
            song.SetDefaultPatternLength(patternLength);

            for (int i = 0; i < song.Channels.Length; i++)
                channelStates[i] = new ChannelState();

            var foundFirstNote = !removeIntroSilence;

            var p = 0;
            var n = 0;
            var f = startFrame;

            for (int i = 0; i < numFrames; i++)
            {
                p = f / song.PatternLength;
                n = f % song.PatternLength;

                if (p >= Song.MaxLength - 1)
                    break;

                var playCalled = 0;
                do
                {
                    playCalled = NsfRunFrame(nsf);
                }
                while (playCalled == 0);

                for (int c = 0; c < song.Channels.Length; c++)
                    foundFirstNote |= UpdateChannel(p, n, song.Channels[c], channelStates[c]);

                if (foundFirstNote)
                {
                    f++;
                }
                else
                {
                    // Reset everything until we find our first note.
                    project.DeleteAllInstrument();
                    project.DeleteAllSamples();
                    for (int c = 0; c < song.Channels.Length; c++)
                        channelStates[c] = new ChannelState();
                }
            }

            song.SetLength(p + 1);

            NsfClose(nsf);

            var factors = Utils.GetFactors(song.PatternLength, Song.MaxNoteLength);
            if (factors.Length > 0 && factors[0] <= Song.MaxNoteLength)
                song.ResizeNotes(factors[0], false);
            else
                song.ResizeNotes(1, false);

            song.SetSensibleBarLength();
            song.DeleteEmptyPatterns();
            song.UpdatePatternStartNotes();
            project.DeleteUnusedInstruments();
            project.UpdateAllLastValidNotesAndVolume();

            return project;
        }
    }
}
