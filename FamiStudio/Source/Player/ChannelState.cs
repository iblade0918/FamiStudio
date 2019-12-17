﻿using System;
using System.Diagnostics;

namespace FamiStudio
{
    public abstract class ChannelState
    {
        protected int apuIdx;
        protected int channelType;
        protected bool seeking = false;
        protected bool newNote = false;
        protected Note note;
        protected int portamentoPitch = 0;
        protected int portamentoStepCount = 0;
        protected int portamentoStep = 0;
        protected int[] envelopeIdx = new int[Envelope.Max];
        protected int[] envelopeValues = new int[Envelope.Max];
        protected int duty;
        protected int[] shadowRegisters = new int[21]; // MATTT: Add registers for expansion audio.
        protected ushort[] noteTable = null;

        public ChannelState(int apu, int type)
        {
            apuIdx = apu;
            channelType = type;
            note.Value = Note.NoteStop;
            note.Volume = Note.VolumeMax;
        }

        public void ProcessEffects(Song song, ref int patternIdx, ref int noteIdx, ref int speed, bool allowJump = true)
        {
            var pattern = song.Channels[channelType].PatternInstances[patternIdx];

            if (pattern == null)
                return;

            var tmpNote = pattern.Notes[noteIdx];

            switch (tmpNote.Effect)
            {
                case Note.EffectJump:
                    if (!seeking && allowJump)
                    {
                        patternIdx = tmpNote.EffectParam;
                        noteIdx = 0;
                    }
                    break;
                case Note.EffectSkip:
                    if (!seeking)
                    {
                        patternIdx++;
                        noteIdx = tmpNote.EffectParam;
                    }
                    break;
                case Note.EffectSpeed:
                    speed = tmpNote.EffectParam;
                    break;
            }
        }

        public void Advance(Song song, int patternIdx, int noteIdx)
        {
            var pattern = song.Channels[channelType].PatternInstances[patternIdx];

            if (pattern == null)
                return;

            var tmpNote = pattern.Notes[noteIdx];
            if (tmpNote.IsValid)
            {
                portamentoPitch = 0;
                portamentoStep = 0;
                portamentoStepCount = 0;

                if ((tmpNote.Flags & Note.FlagPortamento) != 0)
                {
                    int nextPatternIdx = patternIdx;
                    int nextNoteIdx    = noteIdx;

                    if (song.Channels[channelType].FindNextValidNote(ref nextPatternIdx, ref nextNoteIdx))
                    {
                        var noteDuration = (nextPatternIdx * song.PatternLength + nextNoteIdx) - (patternIdx * song.PatternLength + noteIdx);
                        portamentoPitch = (int)noteTable[note.Value] - (int)noteTable[tmpNote.Value];

                        if (portamentoPitch != 0 && noteDuration != 0)
                        {
                            var frameCount = noteDuration * song.Speed;
                            var floatStep = Math.Abs(portamentoPitch) / (float)frameCount;
                            portamentoStep = (int)Math.Ceiling(floatStep) * -Math.Sign(portamentoPitch);
                            portamentoStepCount = Math.Abs(portamentoPitch / portamentoStep);

                            Debug.Assert(Math.Abs(portamentoStep * portamentoStepCount) <= Math.Abs(portamentoPitch));
                        }
                    }
                }

                PlayNote(tmpNote);
            }
            else if (tmpNote.HasVolume)
            {
                note.Volume = tmpNote.Volume;
            }
        }

        public void PlayNote(Note note)
        {
            if (!note.HasVolume)
                note.Volume = this.note.Volume;

            if (note.IsRelease)
            {
                if (this.note.Instrument != null)
                {
                    for (int j = 0; j < Envelope.Max; j++)
                    {
                        if (this.note.Instrument.Envelopes[j].Release >= 0)
                            envelopeIdx[j] = this.note.Instrument.Envelopes[j].Release;
                    }
                }
            }
            else
            {
                this.note = note;
                this.newNote = true;

                if (note.Instrument != null)
                    duty = note.Instrument.DutyCycle;

                for (int j = 0; j < Envelope.Max; j++)
                    envelopeIdx[j] = 0;
            }
        }

        public void UpdateEnvelopes()
        {
            var instrument = note.Instrument;
            if (instrument == null)
                return;

            for (int j = 0; j < Envelope.Max; j++)
            {
                if (instrument.Envelopes[j] == null ||
                    instrument.Envelopes[j].Length <= 0)
                {
                    if (j == Envelope.Volume)
                        envelopeValues[j] = 15;
                    else
                        envelopeValues[j] = 0;
                    continue;
                }

                var idx = envelopeIdx[j];
                var env = instrument.Envelopes[j];

                envelopeValues[j] = instrument.Envelopes[j].Values[idx];

                idx++;

                if (env.Release >= 0 && idx == env.Release)
                    envelopeIdx[j] = env.Loop;
                else if (idx >= env.Length)
                    envelopeIdx[j] = env.Loop >= 0 && env.Release < 0 ? env.Loop : env.Length - 1;
                else
                    envelopeIdx[j] = idx;
            }

            // Update portamento.
            if (portamentoStepCount > 0)
            {
                portamentoPitch += portamentoStep;
                portamentoStepCount--;
            }
        }

        public int GetEnvelopeFrame(int envIdx)
        {
            return envelopeIdx[envIdx];
        }

        public void StartSeeking()
        {
            seeking = true;
            for (int i = 0; i < shadowRegisters.Length; i++)
                shadowRegisters[i] = -1;
        }

        public void StopSeeking()
        {
            seeking = false;
            for (int i = 0; i < shadowRegisters.Length; i++)
            {
                if (shadowRegisters[i] >= 0)
                    NesApu.NesApuWriteRegister(apuIdx, 0x4000 + i, shadowRegisters[i]);
            }
        }

        public void ClearNote()
        {
            note.Instrument = null;
        }

        protected int MultiplyVolumes(int v0, int v1)
        {
            return (int)Math.Ceiling((v0 / 15.0f) * (v1 / 15.0f) * 15.0f);
        }

        protected void WriteApuRegister(int register, int data)
        {
            if (seeking)
            {
                int idx = register - 0x4000;
                // Not caching DPCM register for now.
                if (idx < shadowRegisters.Length) 
                {
                    shadowRegisters[idx] = data;
                }
            }
            else
            {
                NesApu.NesApuWriteRegister(apuIdx, register, data);
            }
        }

        public abstract void UpdateAPU();
    };
}
