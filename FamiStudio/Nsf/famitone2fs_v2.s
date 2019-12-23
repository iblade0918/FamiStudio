;FamiTone2 v1.12
FT_BASE_SIZE_DEF = 157

;settings, uncomment or put them into your main program; the latter makes possible updates easier

; FT_BASE_ADR		= $0300	;page in the RAM used for FT2 variables, should be $xx00
; FT_TEMP			= $00	;3 bytes in zeropage used by the library as a scratchpad
FT_DPCM_OFF		= $c000
FT_SFX_STREAMS	= 0		;number of sound effects played at once, 1..4

FT_DPCM_ENABLE = 1			;undefine to exclude all DMC code
FT_SFX_ENABLE = 0			;undefine to exclude all sound effects code
FT_THREAD	= 1			;undefine if you are calling sound effects from the same thread as the sound update call

FT_PAL_SUPPORT = 0			;undefine to exclude PAL support
FT_NTSC_SUPPORT	= 1		;undefine to exclude NTSC support

;internal defines
FT_PITCH_FIX    = 0 ;(FT_PAL_SUPPORT|FT_NTSC_SUPPORT) ;add PAL/NTSC pitch correction code only when both modes are enabled

.segment "FAMITONE"

;FT_BASE_ADR:	.res FT_BASE_SIZE_DEF

;envelope structure offsets, 5 bytes per envelope, grouped by variable type

FT_NUM_ENVELOPES	= 3+3+3+2	;3 for the pulse and triangle channels, 2 for the noise channel
;FT_ENV_STRUCT_SIZE	= 5

FT_ENVELOPES:
FT_ENV_VALUE		: .res FT_NUM_ENVELOPES
FT_ENV_REPEAT		: .res FT_NUM_ENVELOPES
FT_ENV_ADR_L		: .res FT_NUM_ENVELOPES
FT_ENV_ADR_H		: .res FT_NUM_ENVELOPES
FT_ENV_PTR			: .res FT_NUM_ENVELOPES

;slide structure offsets, 4 bytes per slide.

FT_NUM_SLIDES = 3 ;square and triangle have slide notes.
;FT_SLIDE_STRUCT_SIZE = 4

FT_SLIDES:
FT_SLIDE_STEP		: .res FT_NUM_SLIDES
FT_SLIDE_REPEAT		: .res FT_NUM_SLIDES
FT_SLIDE_PITCH_L	: .res FT_NUM_SLIDES
FT_SLIDE_PITCH_H	: .res FT_NUM_SLIDES

;channel structure offsets, 10 bytes per channel

FT_NUM_CHANNELS		= 5
;FT_CHN_STRUCT_SIZE	= 10

FT_CHANNELS:
FT_CHN_PTR_L		: .res FT_NUM_CHANNELS
FT_CHN_PTR_H		: .res FT_NUM_CHANNELS
FT_CHN_NOTE			: .res FT_NUM_CHANNELS
FT_CHN_INSTRUMENT	: .res FT_NUM_CHANNELS
FT_CHN_REPEAT		: .res FT_NUM_CHANNELS
FT_CHN_RETURN_L		: .res FT_NUM_CHANNELS
FT_CHN_RETURN_H		: .res FT_NUM_CHANNELS
FT_CHN_REF_LEN		: .res FT_NUM_CHANNELS
FT_CHN_DUTY			: .res FT_NUM_CHANNELS
FT_CHN_VOLUME_TRACK	: .res FT_NUM_CHANNELS ; DPCM(4) + Triangle(2) are unused.

;variables and aliases

;FT_ENVELOPES	= FT_BASE_ADR
FT_CH1_ENVS		= FT_ENVELOPES+0
FT_CH2_ENVS		= FT_ENVELOPES+3
FT_CH3_ENVS		= FT_ENVELOPES+6
FT_CH4_ENVS		= FT_ENVELOPES+9

;FT_SLIDES       = FT_ENVELOPES+FT_NUM_ENVELOPES*FT_ENV_STRUCT_SIZE
FT_CH1_SLIDES	= FT_SLIDES+0
FT_CH2_SLIDES	= FT_SLIDES+1
FT_CH3_SLIDES	= FT_SLIDES+2

;FT_CHANNELS		= FT_ENVELOPES+FT_NUM_ENVELOPES*FT_ENV_STRUCT_SIZE+FT_NUM_SLIDES*FT_SLIDE_STRUCT_SIZE
FT_CH1_VARS		= FT_CHANNELS+0
FT_CH2_VARS		= FT_CHANNELS+1
FT_CH3_VARS		= FT_CHANNELS+2
FT_CH4_VARS		= FT_CHANNELS+3
FT_CH5_VARS		= FT_CHANNELS+4

FT_CH1_NOTE			= FT_CHN_NOTE+0
FT_CH2_NOTE			= FT_CHN_NOTE+1
FT_CH3_NOTE			= FT_CHN_NOTE+2
FT_CH4_NOTE			= FT_CHN_NOTE+3
FT_CH5_NOTE			= FT_CHN_NOTE+4

FT_CH1_INSTRUMENT	= FT_CHN_INSTRUMENT+0
FT_CH2_INSTRUMENT	= FT_CHN_INSTRUMENT+1
FT_CH3_INSTRUMENT	= FT_CHN_INSTRUMENT+2
FT_CH4_INSTRUMENT	= FT_CHN_INSTRUMENT+3
FT_CH5_INSTRUMENT	= FT_CHN_INSTRUMENT+4

FT_CH1_DUTY			= FT_CHN_DUTY+0
FT_CH2_DUTY			= FT_CHN_DUTY+1
FT_CH3_DUTY			= FT_CHN_DUTY+2
FT_CH4_DUTY			= FT_CHN_DUTY+3
FT_CH5_DUTY			= FT_CHN_DUTY+4

FT_CH1_VOLUME_TRACK	= FT_CHN_VOLUME_TRACK+0
FT_CH2_VOLUME_TRACK	= FT_CHN_VOLUME_TRACK+1
FT_CH4_VOLUME_TRACK	= FT_CHN_VOLUME_TRACK+2

FT_CH1_VOLUME		= FT_ENV_VALUE+0
FT_CH2_VOLUME		= FT_ENV_VALUE+3
FT_CH3_VOLUME		= FT_ENV_VALUE+6
FT_CH4_VOLUME		= FT_ENV_VALUE+9

FT_CH1_NOTE_OFF		= FT_ENV_VALUE+1
FT_CH2_NOTE_OFF		= FT_ENV_VALUE+4
FT_CH3_NOTE_OFF		= FT_ENV_VALUE+7
FT_CH4_NOTE_OFF		= FT_ENV_VALUE+10

FT_CH1_PITCH_OFF	= FT_ENV_VALUE+2
FT_CH2_PITCH_OFF	= FT_ENV_VALUE+5
FT_CH3_PITCH_OFF	= FT_ENV_VALUE+8

FT_CH1_SLIDE_STEP	= FT_SLIDE_STEP+0
FT_CH2_SLIDE_STEP	= FT_SLIDE_STEP+1
FT_CH3_SLIDE_STEP	= FT_SLIDE_STEP+2

FT_CH1_SLIDE_REPEAT	= FT_SLIDE_REPEAT+0
FT_CH2_SLIDE_REPEAT	= FT_SLIDE_REPEAT+1
FT_CH3_SLIDE_REPEAT	= FT_SLIDE_REPEAT+2

FT_CH1_SLIDE_PITCH_L	= FT_SLIDE_PITCH_L+0
FT_CH2_SLIDE_PITCH_L	= FT_SLIDE_PITCH_L+1
FT_CH3_SLIDE_PITCH_L	= FT_SLIDE_PITCH_L+2

FT_CH1_SLIDE_PITCH_H	= FT_SLIDE_PITCH_H+0
FT_CH2_SLIDE_PITCH_H	= FT_SLIDE_PITCH_H+1
FT_CH3_SLIDE_PITCH_H	= FT_SLIDE_PITCH_H+2

FT_SFX_STRUCT_SIZE	= 15

FT_VARS: .res 13 - FT_SFX_STRUCT_SIZE * FT_SFX_STREAMS

FT_PAL_ADJUST	= FT_VARS+0
FT_SONG_LIST_L	= FT_VARS+1
FT_SONG_LIST_H	= FT_VARS+2
FT_INSTRUMENT_L = FT_VARS+3
FT_INSTRUMENT_H = FT_VARS+4
FT_TEMPO_STEP_L	= FT_VARS+5
FT_TEMPO_STEP_H	= FT_VARS+6
FT_TEMPO_ACC_L	= FT_VARS+7
FT_TEMPO_ACC_H	= FT_VARS+8
FT_SONG_SPEED	= FT_CH5_INSTRUMENT
FT_PULSE1_PREV	= FT_CH3_DUTY
FT_PULSE2_PREV	= FT_CH5_DUTY
FT_DPCM_LIST_L	= FT_VARS+9
FT_DPCM_LIST_H	= FT_VARS+10
FT_DPCM_EFFECT  = FT_VARS+11
FT_OUT_BUF		= FT_VARS+12	;11 bytes


;sound effect stream variables, 2 bytes and 15 bytes per stream
;when sound effects are disabled, this memory is not used

FT_SFX_ADR_L		= FT_VARS+23
FT_SFX_ADR_H		= FT_VARS+24
FT_SFX_BASE_ADR		= FT_VARS+25

FT_SFX_REPEAT		= FT_SFX_BASE_ADR+0
FT_SFX_PTR_L		= FT_SFX_BASE_ADR+1
FT_SFX_PTR_H		= FT_SFX_BASE_ADR+2
FT_SFX_OFF			= FT_SFX_BASE_ADR+3
FT_SFX_BUF			= FT_SFX_BASE_ADR+4	;11 bytes

;FT_BASE_SIZE 		= FT_SFX_BUF+11-FT_BASE_ADR+FT_SFX_STRUCT_SIZE*FT_SFX_STREAMS

;aliases for sound effect channels to use in user calls

FT_SFX_CH0			= FT_SFX_STRUCT_SIZE*0
FT_SFX_CH1			= FT_SFX_STRUCT_SIZE*1
FT_SFX_CH2			= FT_SFX_STRUCT_SIZE*2
FT_SFX_CH3			= FT_SFX_STRUCT_SIZE*3

;.assert FT_TEMP_SIZE_DEF = FT_TEMP_SIZE, error, "Famitone temp size mismatch."
;.assert FT_BASE_SIZE_DEF = FT_BASE_SIZE, error, "Famitone base size mismatch."

;.out .sprintf ("Famitone base size is %d bytes.", FT_BASE_SIZE)

.segment "ZEROPAGE"
;zero page variables

FT_TEMP:
FT_TEMP_PTR			: .res 2
FT_TEMP_VAR1		: .res 1
FT_TEMP_VAR2		: .res 1
FT_TEMP_PTR2		: .res 2

FT_TEMP_PTR_L		= FT_TEMP_PTR+0
FT_TEMP_PTR_H		= FT_TEMP_PTR+1
FT_TEMP_PTR2_L		= FT_TEMP_PTR+0
FT_TEMP_PTR2_H		= FT_TEMP_PTR+1

.segment "CODE"

;aliases for the APU registers
APU_PL1_VOL		= $4000
APU_PL1_SWEEP	= $4001
APU_PL1_LO		= $4002
APU_PL1_HI		= $4003
APU_PL2_VOL		= $4004
APU_PL2_SWEEP	= $4005
APU_PL2_LO		= $4006
APU_PL2_HI		= $4007
APU_TRI_LINEAR	= $4008
APU_TRI_LO		= $400a
APU_TRI_HI		= $400b
APU_NOISE_VOL	= $400c
APU_NOISE_LO	= $400e
APU_NOISE_HI	= $400f
APU_DMC_FREQ	= $4010
APU_DMC_RAW		= $4011
APU_DMC_START	= $4012
APU_DMC_LEN		= $4013
APU_SND_CHN		= $4015


;aliases for the APU registers in the output buffer

.if(!FT_SFX_ENABLE)				;if sound effects are disabled, write to the APU directly
	FT_MR_PULSE1_V		= APU_PL1_VOL
	FT_MR_PULSE1_L		= APU_PL1_LO
	FT_MR_PULSE1_H		= APU_PL1_HI
	FT_MR_PULSE2_V		= APU_PL2_VOL
	FT_MR_PULSE2_L		= APU_PL2_LO
	FT_MR_PULSE2_H		= APU_PL2_HI
	FT_MR_TRI_V			= APU_TRI_LINEAR
	FT_MR_TRI_L			= APU_TRI_LO
	FT_MR_TRI_H			= APU_TRI_HI
	FT_MR_NOISE_V		= APU_NOISE_VOL
	FT_MR_NOISE_F		= APU_NOISE_LO
.else								;otherwise write to the output buffer
	FT_MR_PULSE1_V		= FT_OUT_BUF
	FT_MR_PULSE1_L		= FT_OUT_BUF+1
	FT_MR_PULSE1_H		= FT_OUT_BUF+2
	FT_MR_PULSE2_V		= FT_OUT_BUF+3
	FT_MR_PULSE2_L		= FT_OUT_BUF+4
	FT_MR_PULSE2_H		= FT_OUT_BUF+5
	FT_MR_TRI_V			= FT_OUT_BUF+6
	FT_MR_TRI_L			= FT_OUT_BUF+7
	FT_MR_TRI_H			= FT_OUT_BUF+8
	FT_MR_NOISE_V		= FT_OUT_BUF+9
	FT_MR_NOISE_F		= FT_OUT_BUF+10
.endif

;------------------------------------------------------------------------------
; reset APU, initialize FamiTone
; in: A   0 for PAL, not 0 for NTSC
;     X,Y pointer to music data
;------------------------------------------------------------------------------

FamiToneInit:

	stx FT_SONG_LIST_L		;store music data pointer for further use
	sty FT_SONG_LIST_H
	stx <FT_TEMP_PTR_L
	sty <FT_TEMP_PTR_H

	.if(FT_PITCH_FIX)
	tax						;set SZ flags for A
	beq @pal
	lda #64
@pal:
	.else
	.if(FT_PAL_SUPPORT)
	lda #0
	.endif
	.if(FT_NTSC_SUPPORT)
	lda #64
	.endif
	.endif
	sta FT_PAL_ADJUST

	jsr FamiToneMusicStop	;initialize channels and envelopes

	ldy #1
	lda (FT_TEMP_PTR),y		;get instrument list address
	sta FT_INSTRUMENT_L
	iny
	lda (FT_TEMP_PTR),y
	sta FT_INSTRUMENT_H
	iny
	lda (FT_TEMP_PTR),y		;get sample list address
	sta FT_DPCM_LIST_L
	iny
	lda (FT_TEMP_PTR),y
	sta FT_DPCM_LIST_H

	lda #$ff				;previous pulse period MSB, to not write it when not changed
	sta FT_PULSE1_PREV
	sta FT_PULSE2_PREV

	lda #$0f				;enable channels, stop DMC
	sta APU_SND_CHN
	lda #$80				;disable triangle length counter
	sta APU_TRI_LINEAR
	lda #$00				;load noise length
	sta APU_NOISE_HI

	lda #$30				;volumes to 0
	sta APU_PL1_VOL
	sta APU_PL2_VOL
	sta APU_NOISE_VOL
	lda #$08				;no sweep
	sta APU_PL1_SWEEP
	sta APU_PL2_SWEEP

	;jmp FamiToneMusicStop


;------------------------------------------------------------------------------
; stop music that is currently playing, if any
; in: none
;------------------------------------------------------------------------------

FamiToneMusicStop:

	lda #0
	sta FT_SONG_SPEED		;stop music, reset pause flag
	sta FT_DPCM_EFFECT		;no DPCM effect playing

	ldx #0	;initialize channel structures

@set_channels:

	lda #0
	sta FT_CHN_REPEAT,x
	sta FT_CHN_INSTRUMENT,x
	sta FT_CHN_NOTE,x
	sta FT_CHN_REF_LEN,x
	sta FT_CHN_VOLUME_TRACK,x
	lda #$30
	sta FT_CHN_DUTY,x

	inx						;next channel
	cpx #FT_NUM_CHANNELS
	bne @set_channels

	ldx #0	;initialize all slides to zero
	lda #0
@set_slides:

	sta FT_SLIDE_REPEAT, x
	inx						;next channel
	cpx #FT_NUM_SLIDES
	bne @set_slides

	ldx #0	;initialize all envelopes to the dummy envelope

@set_envelopes:

	lda #.lobyte (_FT2DummyEnvelope)
	sta FT_ENV_ADR_L,x
	lda #.hibyte(_FT2DummyEnvelope)
	sta FT_ENV_ADR_H,x
	lda #0
	sta FT_ENV_REPEAT,x
	sta FT_ENV_VALUE,x
	inx
	cpx #FT_NUM_ENVELOPES

	bne @set_envelopes

	jmp FamiToneSampleStop


;------------------------------------------------------------------------------
; play music
; in: A number of subsong
;------------------------------------------------------------------------------

FamiToneMusicPlay:

	ldx FT_SONG_LIST_L
	stx <FT_TEMP_PTR_L
	ldx FT_SONG_LIST_H
	stx <FT_TEMP_PTR_H

	ldy #0
	cmp (FT_TEMP_PTR),y		;check if there is such sub song
	bcs @skip

	asl a					;multiply song number by 14
	sta <FT_TEMP_PTR_L		;use pointer LSB as temp variable
	asl a
	tax
	asl a
	adc <FT_TEMP_PTR_L
	stx <FT_TEMP_PTR_L
	adc <FT_TEMP_PTR_L
	adc #5					;add offset
	tay

	lda FT_SONG_LIST_L		;restore pointer LSB
	sta <FT_TEMP_PTR_L

	jsr FamiToneMusicStop	;stop music, initialize channels and envelopes

	ldx #0	;initialize channel structures

@set_channels:

	lda (FT_TEMP_PTR),y		;read channel pointers
	sta FT_CHN_PTR_L,x
	iny
	lda (FT_TEMP_PTR),y
	sta FT_CHN_PTR_H,x
	iny

	lda #0
	sta FT_CHN_REPEAT,x
	sta FT_CHN_INSTRUMENT,x
	sta FT_CHN_NOTE,x
	sta FT_CHN_REF_LEN,x
	lda #$f0
	sta FT_CHN_VOLUME_TRACK,x
	lda #$30
	sta FT_CHN_DUTY,x

	inx						;next channel
	cpx #FT_NUM_CHANNELS
	bne @set_channels


	lda FT_PAL_ADJUST		;read tempo for PAL or NTSC
	beq @pal
	iny
	iny
@pal:

	lda (FT_TEMP_PTR),y		;read the tempo step
	sta FT_TEMPO_STEP_L
	iny
	lda (FT_TEMP_PTR),y
	sta FT_TEMPO_STEP_H


	lda #0					;reset tempo accumulator
	sta FT_TEMPO_ACC_L
	lda #6					;default speed
	sta FT_TEMPO_ACC_H
	sta FT_SONG_SPEED		;apply default speed, this also enables music

@skip:
	rts


;------------------------------------------------------------------------------
; pause and unpause current music
; in: A 0 or not 0 to play or pause
;------------------------------------------------------------------------------

FamiToneMusicPause:

	tax					;set SZ flags for A
	beq @unpause
	
@pause:

	jsr FamiToneSampleStop
	
	lda #0				;mute sound
	sta FT_CH1_VOLUME
	sta FT_CH2_VOLUME
	sta FT_CH3_VOLUME
	sta FT_CH4_VOLUME
	lda FT_SONG_SPEED	;set pause flag
	ora #$80
	bne @done
@unpause:
	lda FT_SONG_SPEED	;reset pause flag
	and #$7f
@done:
	sta FT_SONG_SPEED

	rts


;------------------------------------------------------------------------------
; update FamiTone state, should be called every NMI
; in: none
;------------------------------------------------------------------------------

FamiToneUpdate:

	.if(FT_THREAD)
	lda FT_TEMP_PTR_L
	pha
	lda FT_TEMP_PTR_H
	pha
	.endif

	lda FT_SONG_SPEED		;speed 0 means that no music is playing currently
	bmi @pause				;bit 7 set is the pause flag
	bne @update
@pause:
	jmp @update_sound

@update:

	clc						;update frame counter that considers speed, tempo, and PAL/NTSC
	lda FT_TEMPO_ACC_L
	adc FT_TEMPO_STEP_L
	sta FT_TEMPO_ACC_L
	lda FT_TEMPO_ACC_H
	adc FT_TEMPO_STEP_H
	cmp FT_SONG_SPEED
	bcs @update_row			;overflow, row update is needed
	sta FT_TEMPO_ACC_H		;no row update, skip to the envelopes update
	jmp @update_envelopes

@update_row:

	sec
	sbc FT_SONG_SPEED
	sta FT_TEMPO_ACC_H


	ldx #0	;process channel 1
	jsr _FT2ChannelUpdate
	bcc @no_new_note1
	ldx #0
	lda FT_CH1_INSTRUMENT
	jsr _FT2SetInstrument
	sta FT_CH1_DUTY
@no_new_note1:

	ldx #1	;process channel 2
	jsr _FT2ChannelUpdate
	bcc @no_new_note2
	ldx #1
	lda FT_CH2_INSTRUMENT
	jsr _FT2SetInstrument
	sta FT_CH2_DUTY
@no_new_note2:

	ldx #2	;process channel 3
	jsr _FT2ChannelUpdate
	bcc @no_new_note3
	ldx #2
	lda FT_CH3_INSTRUMENT
	jsr _FT2SetInstrument
@no_new_note3:

	ldx #3	;process channel 4
	jsr _FT2ChannelUpdate
	bcc @no_new_note4
	ldx #3
	lda FT_CH4_INSTRUMENT
	jsr _FT2SetInstrument
	sta FT_CH4_DUTY
@no_new_note4:

	.if(FT_DPCM_ENABLE)

	ldx #4	;process channel 5
	jsr _FT2ChannelUpdate
	bcc @no_new_note5
	lda FT_CH5_NOTE
	bne @play_sample
	jsr FamiToneSampleStop
	bne @no_new_note5		;A is non-zero after FamiToneSampleStop
@play_sample:
	jsr FamiToneSamplePlayM
@no_new_note5:

	.endif


@update_envelopes:

	ldx #0	;process 11 envelopes

@env_process:

	lda FT_ENV_REPEAT,x		;check envelope repeat counter
	beq @env_read			;if it is zero, process envelope
	dec FT_ENV_REPEAT,x		;otherwise decrement the counter
	bne @env_next

@env_read:

	lda FT_ENV_ADR_L,x		;load envelope data address into temp
	sta <FT_TEMP_PTR_L
	lda FT_ENV_ADR_H,x
	sta <FT_TEMP_PTR_H
	ldy FT_ENV_PTR,x		;load envelope pointer

@env_read_value:

	lda (FT_TEMP_PTR),y		;read a byte of the envelope data
	bpl @env_special		;values below 128 used as a special code, loop or repeat
	clc						;values above 128 are output value+192 (output values are signed -63..64)
	adc #256-192
	sta FT_ENV_VALUE,x		;store the output value
	iny						;advance the pointer
	bne @env_next_store_ptr ;bra

@env_special:

	bne @env_set_repeat		;zero is the loop point, non-zero values used for the repeat counter
	iny						;advance the pointer
	lda (FT_TEMP_PTR),y		;read loop position
	tay						;use loop position
	jmp @env_read_value		;read next byte of the envelope

@env_set_repeat:

	iny
	sta FT_ENV_REPEAT,x		;store the repeat counter value

@env_next_store_ptr:

	tya						;store the envelope pointer
	sta FT_ENV_PTR,x

@env_next:

	inx						;next envelope

	cpx #FT_NUM_ENVELOPES
	bne @env_process

@update_slides:

	ldx #0	;process 3 slides

@slide_process:

	lda FT_SLIDE_REPEAT,x 	; zero repeat means no active slide.
	beq @slide_next

	clc						; add step to slide pitch (16bit + 8bit signed).
	lda FT_SLIDE_STEP,x
	adc FT_SLIDE_PITCH_L,x
	sta FT_SLIDE_PITCH_L,x
	lda FT_SLIDE_STEP,x
	and #$80
	beq @positive_slide
	lda #$ff
@positive_slide:
	adc FT_SLIDE_PITCH_H,x
	sta FT_SLIDE_PITCH_H,x
	dec FT_SLIDE_REPEAT,x

@slide_next:

	inx						;next slide

	cpx #FT_NUM_SLIDES
	bne @slide_process

@update_sound:

	;convert envelope and channel output data into APU register values in the output buffer

	lda FT_CH1_NOTE
	beq @ch1cut
	clc
	adc FT_CH1_NOTE_OFF
	.if(FT_PITCH_FIX)
	ora FT_PAL_ADJUST
	.endif
	tax
	ldy FT_CH1_SLIDE_REPEAT
	beq @ch1noslide
@ch1slide:
	lda FT_CH1_PITCH_OFF
	tay
	adc _FT2NoteTableLSB,x
	sta FT_TEMP_PTR2_L
	tya
	ora #$7f
	bmi @ch1slidesign
	lda #0
@ch1slidesign:
	adc _FT2NoteTableMSB,x
	sta FT_TEMP_PTR2_H
	lda FT_TEMP_PTR2_L
	adc FT_CH1_SLIDE_PITCH_L
	sta FT_MR_PULSE1_L
	lda FT_TEMP_PTR2_H
	adc FT_CH1_SLIDE_PITCH_H
	jmp @ch1checkprevpulse
@ch1noslide:	
	lda FT_CH1_PITCH_OFF
	tay
	adc _FT2NoteTableLSB,x
	sta FT_MR_PULSE1_L
	tya						;sign extension for the pitch offset
	ora #$7f
	bmi @ch1sign
	lda #0
@ch1sign:
	adc _FT2NoteTableMSB,x
@ch1checkprevpulse:
	.if(!FT_SFX_ENABLE)
	cmp FT_PULSE1_PREV
	beq @ch1prev
	sta FT_PULSE1_PREV
	.endif

	sta FT_MR_PULSE1_H
@ch1prev:
	lda FT_CH1_VOLUME
	ora FT_CH1_VOLUME_TRACK
	tax
	lda _FT2VolumeTable, x 
@ch1cut:
	ora FT_CH1_DUTY
	sta FT_MR_PULSE1_V

	lda FT_CH2_NOTE
	beq @ch2cut
	clc
	adc FT_CH2_NOTE_OFF
	.if(FT_PITCH_FIX)
	ora FT_PAL_ADJUST
	.endif
	tax
	ldy FT_CH2_SLIDE_REPEAT
	beq @ch2noslide
@ch2slide:
	lda FT_CH2_PITCH_OFF
	tay
	adc _FT2NoteTableLSB,x
	sta FT_TEMP_PTR2_L
	tya
	ora #$7f
	bmi @ch2slidesign
	lda #0
@ch2slidesign:
	adc _FT2NoteTableMSB,x
	sta FT_TEMP_PTR2_H
	lda FT_TEMP_PTR2_L
	adc FT_CH2_SLIDE_PITCH_L
	sta FT_MR_PULSE2_L
	lda FT_TEMP_PTR2_H
	adc FT_CH2_SLIDE_PITCH_H
	jmp @ch2checkprevpulse
@ch2noslide:	
	lda FT_CH2_PITCH_OFF
	tay
	adc _FT2NoteTableLSB,x
	sta FT_MR_PULSE2_L
	tya
	ora #$7f
	bmi @ch2sign
	lda #0
@ch2sign:
	adc _FT2NoteTableMSB,x
@ch2checkprevpulse:
	.if(!FT_SFX_ENABLE)
	cmp FT_PULSE2_PREV
	beq @ch2prev
	sta FT_PULSE2_PREV
	.endif

	sta FT_MR_PULSE2_H
@ch2prev:
	lda FT_CH2_VOLUME
	ora FT_CH2_VOLUME_TRACK
	tax
	lda _FT2VolumeTable, x 	
@ch2cut:
	ora FT_CH2_DUTY
	sta FT_MR_PULSE2_V


	lda FT_CH3_NOTE
	beq @ch3cut
	clc
	adc FT_CH3_NOTE_OFF
	.if(FT_PITCH_FIX)
	ora FT_PAL_ADJUST
	.endif
	tax
	ldy FT_CH3_SLIDE_REPEAT
	beq @ch3noslide
@ch3slide:
	lda FT_CH3_PITCH_OFF
	tay
	adc _FT2NoteTableLSB,x
	sta FT_TEMP_PTR2_L
	tya
	ora #$7f
	bmi @ch3slidesign
	lda #0
@ch3slidesign:
	adc _FT2NoteTableMSB,x
	sta FT_TEMP_PTR2_H
	lda FT_TEMP_PTR2_L
	adc FT_CH3_SLIDE_PITCH_L
	sta FT_MR_TRI_L
	lda FT_TEMP_PTR2_H
	adc FT_CH3_SLIDE_PITCH_H
	sta FT_MR_TRI_H
	lda FT_CH3_VOLUME
	jmp @ch3cut
@ch3noslide:	
	lda FT_CH3_PITCH_OFF
	tay
	adc _FT2NoteTableLSB,x
	sta FT_MR_TRI_L
	tya
	ora #$7f
	bmi @ch3sign
	lda #0
@ch3sign:
	adc _FT2NoteTableMSB,x
	sta FT_MR_TRI_H
	lda FT_CH3_VOLUME
@ch3cut:
	ora #$80
	sta FT_MR_TRI_V


	lda FT_CH4_NOTE
	beq @ch4cut
	clc
	adc FT_CH4_NOTE_OFF
	and #$0f
	eor #$0f
	sta <FT_TEMP_VAR1
	lda FT_CH4_DUTY
	asl a
	and #$80
	ora <FT_TEMP_VAR1
	sta FT_MR_NOISE_F
	lda FT_CH4_VOLUME
	ora FT_CH4_VOLUME_TRACK
	tax
	lda _FT2VolumeTable, x 	
@ch4cut:
	ora #$f0
	sta FT_MR_NOISE_V


	.if(FT_SFX_ENABLE)

	;process all sound effect streams

	.if FT_SFX_STREAMS>0
	ldx #FT_SFX_CH0
	jsr _FT2SfxUpdate
	.endif
	.if FT_SFX_STREAMS>1
	ldx #FT_SFX_CH1
	jsr _FT2SfxUpdate
	.endif
	.if FT_SFX_STREAMS>2
	ldx #FT_SFX_CH2
	jsr _FT2SfxUpdate
	.endif
	.if FT_SFX_STREAMS>3
	ldx #FT_SFX_CH3
	jsr _FT2SfxUpdate
	.endif


	;send data from the output buffer to the APU

	lda FT_OUT_BUF		;pulse 1 volume
	sta APU_PL1_VOL
	lda FT_OUT_BUF+1	;pulse 1 period LSB
	sta APU_PL1_LO
	lda FT_OUT_BUF+2	;pulse 1 period MSB, only applied when changed
	cmp FT_PULSE1_PREV
	beq @no_pulse1_upd
	sta FT_PULSE1_PREV
	sta APU_PL1_HI
@no_pulse1_upd:

	lda FT_OUT_BUF+3	;pulse 2 volume
	sta APU_PL2_VOL
	lda FT_OUT_BUF+4	;pulse 2 period LSB
	sta APU_PL2_LO
	lda FT_OUT_BUF+5	;pulse 2 period MSB, only applied when changed
	cmp FT_PULSE2_PREV
	beq @no_pulse2_upd
	sta FT_PULSE2_PREV
	sta APU_PL2_HI
@no_pulse2_upd:

	lda FT_OUT_BUF+6	;triangle volume (plays or not)
	sta APU_TRI_LINEAR
	lda FT_OUT_BUF+7	;triangle period LSB
	sta APU_TRI_LO
	lda FT_OUT_BUF+8	;triangle period MSB
	sta APU_TRI_HI

	lda FT_OUT_BUF+9	;noise volume
	sta APU_NOISE_VOL
	lda FT_OUT_BUF+10	;noise period
	sta APU_NOISE_LO

	.endif

	.if(FT_THREAD)
	pla
	sta FT_TEMP_PTR_H
	pla
	sta FT_TEMP_PTR_L
	.endif

	rts


;internal routine, sets up envelopes of a channel according to current instrument
;in X envelope group offset, A instrument number

_FT2SetInstrument:
	asl a					;instrument number is pre multiplied by 4
	tay
	lda FT_INSTRUMENT_H
	adc #0					;use carry to extend range for 64 instruments
	sta <FT_TEMP_PTR_H
	lda FT_INSTRUMENT_L
	sta <FT_TEMP_PTR_L

	lda (FT_TEMP_PTR),y		;duty cycle
	sta <FT_TEMP_VAR1
	iny

	lda (FT_TEMP_PTR),y		;instrument pointer LSB
	sta FT_ENV_ADR_L,x
	iny
	lda (FT_TEMP_PTR),y		;instrument pointer MSB
	iny
	sta FT_ENV_ADR_H,x
	inx						;next envelope

	lda (FT_TEMP_PTR),y		;instrument pointer LSB
	sta FT_ENV_ADR_L,x
	iny
	lda (FT_TEMP_PTR),y		;instrument pointer MSB
	sta FT_ENV_ADR_H,x

	lda #1
	sta FT_ENV_PTR-1,x		;reset env1 pointer (env1 is volume and volume can have releases)
	lda #0
	sta FT_ENV_REPEAT-1,x	;reset env1 repeat counter
	sta FT_ENV_REPEAT,x		;reset env2 repeat counter
	sta FT_ENV_PTR,x		;reset env2 pointer

	cpx #3	;noise channel has only two envelopes
	bcs @no_pitch

	inx						;next envelope
	iny
	sta FT_ENV_REPEAT,x		;reset env3 repeat counter
	sta FT_ENV_PTR,x		;reset env3 pointer
	lda (FT_TEMP_PTR),y		;instrument pointer LSB
	sta FT_ENV_ADR_L,x
	iny
	lda (FT_TEMP_PTR),y		;instrument pointer MSB
	sta FT_ENV_ADR_H,x

@no_pitch:
	lda <FT_TEMP_VAR1
	rts


;internal routine, parses channel note data

_FT2ChannelUpdate:

	lda FT_CHN_REPEAT,x		;check repeat counter
	beq @no_repeat
	dec FT_CHN_REPEAT,x		;decrease repeat counter
	clc						;no new note
	rts

@no_repeat:
	lda FT_CHN_PTR_L,x		;load channel pointer into temp
	sta <FT_TEMP_PTR_L
	lda FT_CHN_PTR_H,x
	sta <FT_TEMP_PTR_H
@no_repeat_r:
	ldy #0

@read_byte:
	lda (FT_TEMP_PTR),y		;read byte of the channel

	inc <FT_TEMP_PTR_L		;advance pointer
	bne @check_regular_note
	inc <FT_TEMP_PTR_H
@check_regular_note:
	cmp #$61
	bcs @check_special_code			; $00 to $60 are regular notes, most common case.
	jmp @store_note

@check_special_code:
	ora #0
	bpl @check_volume
	jmp @special_code		;bit 7 0=note 1=special code

@check_volume:
	cmp #$70
	bcc @check_slide
	and #$0f
	asl ; a LUT would be nice, but x/y are both in-use here.
	asl
	asl
	asl
	sta FT_CHN_VOLUME_TRACK,x
	jmp @read_byte

@check_slide:
	cmp #$61				; slide note (followed by num steps, step size and the target note)
	beq @read_slide_num_steps

@check_slide_cancel:	
	;cmp #$62				; reset after a manual slide.
	stx <FT_TEMP_VAR1
	lda _FT2ChannelToSlide - .lobyte(FT_CHANNELS),x
	tax
	lda #0
	sta FT_SLIDE_REPEAT,x
	ldx <FT_TEMP_VAR1	
	jmp @read_byte

@read_slide_step_size:
	stx <FT_TEMP_VAR1
	lda _FT2ChannelToSlide - .lobyte(FT_CHANNELS),x
	tax
	lda (FT_TEMP_PTR),y
	sta FT_SLIDE_STEP,x
	inc <FT_TEMP_PTR_L
	bne @read_slide_num_steps
	inc <FT_TEMP_PTR_H

@read_slide_num_steps:
	lda (FT_TEMP_PTR),y
	sta FT_SLIDE_REPEAT,x
	inc <FT_TEMP_PTR_L
	bne @read_slide_note
	inc <FT_TEMP_PTR_H

@read_slide_note:
	cmp #$ff
	beq @manual_slide
@auto_slide:
	stx <FT_TEMP_VAR2
	sty <FT_TEMP_PTR2
	lda (FT_TEMP_PTR),y		; new note
	ldx <FT_TEMP_VAR1
	ldy FT_CHN_NOTE,x		; current note
	sta FT_CHN_NOTE,x		; store note code
	tax 
	sec						; subtract the pitch of both notes. TODO: PAL + Saw channel.
	lda _FT2NoteTableLSB,y
	sbc _FT2NoteTableLSB,x
	sta <FT_TEMP_PTR2_H
	lda _FT2NoteTableMSB,y
	sbc _FT2NoteTableMSB,x
	ldx <FT_TEMP_VAR2
	ldy <FT_TEMP_PTR2
	sta FT_SLIDE_PITCH_H,x
	lda <FT_TEMP_PTR2_H
	sta FT_SLIDE_PITCH_L,x
	ldx <FT_TEMP_VAR1
	sec						;new note flag is set
	jmp @done ;bra

@manual_slide:
	lda #0
	sta FT_SLIDE_PITCH_H,x
	sta FT_SLIDE_PITCH_L,x
	lda (FT_TEMP_PTR),y		; new note

@store_note:	
	sta FT_CHN_NOTE,x		;store note code
	sec						;new note flag is set
	jmp @done ;bra

@special_code:
	and #$7f
	lsr a
	bcs @set_empty_rows
	asl a
	asl a
	sta FT_CHN_INSTRUMENT,x	;store instrument number*4
	jmp @read_byte 

@set_empty_rows:
	cmp #$3b
	beq @release_note
	cmp #$3d
	bcc @set_repeat
	beq @set_speed
	cmp #$3e
	beq @set_loop

@set_reference:
	clc						;remember return address+3
	lda <FT_TEMP_PTR_L
	adc #3
	sta FT_CHN_RETURN_L,x
	lda <FT_TEMP_PTR_H
	adc #0
	sta FT_CHN_RETURN_H,x
	lda (FT_TEMP_PTR),y		;read length of the reference (how many rows)
	sta FT_CHN_REF_LEN,x
	iny
	lda (FT_TEMP_PTR),y		;read 16-bit absolute address of the reference
	sta <FT_TEMP_VAR1		;remember in temp
	iny
	lda (FT_TEMP_PTR),y
	sta <FT_TEMP_PTR_H
	lda <FT_TEMP_VAR1
	sta <FT_TEMP_PTR_L
	ldy #0
	jmp @read_byte

@set_speed:
	lda (FT_TEMP_PTR),y
	sta FT_SONG_SPEED
	inc <FT_TEMP_PTR_L		;advance pointer after reading the speed value
	bne @jump_back
	inc <FT_TEMP_PTR_H
@jump_back:	
	jmp @read_byte 

@set_loop:
	lda (FT_TEMP_PTR),y
	sta <FT_TEMP_VAR1
	iny
	lda (FT_TEMP_PTR),y
	sta <FT_TEMP_PTR_H
	lda <FT_TEMP_VAR1
	sta <FT_TEMP_PTR_L
	dey
	jmp @read_byte

@release_note:
	stx <FT_TEMP_VAR1
	lda _FT2ChannelToVolumeEnvelope - .lobyte(FT_CHANNELS),x ; DPCM(5) will never have releases.
	tax

	lda FT_ENV_ADR_L,x   ;load envelope data address into temp
	sta <FT_TEMP_PTR2_L
	lda FT_ENV_ADR_H,x
	sta <FT_TEMP_PTR2_H	
	
	ldy #0
	lda (FT_TEMP_PTR2),y  ;read first byte of the envelope data, this contains the release index.
	beq @env_has_no_release

	sta FT_ENV_PTR,x
	lda #0
	sta FT_ENV_REPEAT,x ; need to reset envelope repeat to force update.
	
@env_has_no_release:
	ldx <FT_TEMP_VAR1
	clc
	jmp @done

@set_repeat:
	sta FT_CHN_REPEAT,x		;set up repeat counter, carry is clear, no new note

@done:
	lda FT_CHN_REF_LEN,x	;check reference row counter
	beq @no_ref				;if it is zero, there is no reference
	dec FT_CHN_REF_LEN,x	;decrease row counter
	bne @no_ref

	lda FT_CHN_RETURN_L,x	;end of a reference, return to previous pointer
	sta FT_CHN_PTR_L,x
	lda FT_CHN_RETURN_H,x
	sta FT_CHN_PTR_H,x
	rts

@no_ref:
	lda <FT_TEMP_PTR_L
	sta FT_CHN_PTR_L,x
	lda <FT_TEMP_PTR_H
	sta FT_CHN_PTR_H,x
	rts



;------------------------------------------------------------------------------
; stop DPCM sample if it plays
;------------------------------------------------------------------------------

FamiToneSampleStop:

	lda #%00001111
	sta APU_SND_CHN

	rts


	
	.if(FT_DPCM_ENABLE)

;------------------------------------------------------------------------------
; play DPCM sample, used by music player, could be used externally
; in: A is number of a sample, 1..63
;------------------------------------------------------------------------------

FamiToneSamplePlayM:		;for music (low priority)

	ldx FT_DPCM_EFFECT
	beq _FT2SamplePlay
	tax
	lda APU_SND_CHN
	and #16
	beq @not_busy
	rts

@not_busy:
	sta FT_DPCM_EFFECT
	txa
	jmp _FT2SamplePlay

;------------------------------------------------------------------------------
; play DPCM sample with higher priority, for sound effects
; in: A is number of a sample, 1..63
;------------------------------------------------------------------------------

FamiToneSamplePlay:

	ldx #1
	stx FT_DPCM_EFFECT

_FT2SamplePlay:

	sta <FT_TEMP		;sample number*3, offset in the sample table
	asl a
	clc
	adc <FT_TEMP
	
	adc FT_DPCM_LIST_L
	sta <FT_TEMP_PTR_L
	lda #0
	adc FT_DPCM_LIST_H
	sta <FT_TEMP_PTR_H

	lda #%00001111			;stop DPCM
	sta APU_SND_CHN

	ldy #0
	lda (FT_TEMP_PTR),y		;sample offset
	sta APU_DMC_START
	iny
	lda (FT_TEMP_PTR),y		;sample length
	sta APU_DMC_LEN
	iny
	lda (FT_TEMP_PTR),y		;pitch and loop
	sta APU_DMC_FREQ

	lda #32					;reset DAC counter
	sta APU_DMC_RAW
	lda #%00011111			;start DMC
	sta APU_SND_CHN

	rts

	.endif

	.if(FT_SFX_ENABLE)

;------------------------------------------------------------------------------
; init sound effects player, set pointer to data
; in: X,Y is address of sound effects data
;------------------------------------------------------------------------------

FamiToneSfxInit:

	stx <FT_TEMP_PTR_L
	sty <FT_TEMP_PTR_H
	
	ldy #0
	
	.if(FT_PITCH_FIX)

	lda FT_PAL_ADJUST		;add 2 to the sound list pointer for PAL
	bne @ntsc
	iny
	iny
@ntsc:

	.endif
	
	lda (FT_TEMP_PTR),y		;read and store pointer to the effects list
	sta FT_SFX_ADR_L
	iny
	lda (FT_TEMP_PTR),y
	sta FT_SFX_ADR_H

	ldx #FT_SFX_CH0			;init all the streams

@set_channels:
	jsr _FT2SfxClearChannel
	txa
	clc
	adc #FT_SFX_STRUCT_SIZE
	tax
	cpx #FT_SFX_STRUCT_SIZE*FT_SFX_STREAMS
	bne @set_channels

	rts


;internal routine, clears output buffer of a sound effect
;in: A is 0
;    X is offset of sound effect stream

_FT2SfxClearChannel:

	lda #0
	sta FT_SFX_PTR_H,x		;this stops the effect
	sta FT_SFX_REPEAT,x
	sta FT_SFX_OFF,x
	sta FT_SFX_BUF+6,x		;mute triangle
	lda #$30
	sta FT_SFX_BUF+0,x		;mute pulse1
	sta FT_SFX_BUF+3,x		;mute pulse2
	sta FT_SFX_BUF+9,x		;mute noise

	rts


;------------------------------------------------------------------------------
; play sound effect
; in: A is a number of the sound effect 0..127
;     X is offset of sound effect channel, should be FT_SFX_CH0..FT_SFX_CH3
;------------------------------------------------------------------------------

FamiToneSfxPlay:

	asl a					;get offset in the effects list
	tay

	jsr _FT2SfxClearChannel	;stops the effect if it plays

	lda FT_SFX_ADR_L
	sta <FT_TEMP_PTR_L
	lda FT_SFX_ADR_H
	sta <FT_TEMP_PTR_H

	lda (FT_TEMP_PTR),y		;read effect pointer from the table
	sta FT_SFX_PTR_L,x		;store it
	iny
	lda (FT_TEMP_PTR),y
	sta FT_SFX_PTR_H,x		;this write enables the effect

	rts


;internal routine, update one sound effect stream
;in: X is offset of sound effect stream

_FT2SfxUpdate:

	lda FT_SFX_REPEAT,x		;check if repeat counter is not zero
	beq @no_repeat
	dec FT_SFX_REPEAT,x		;decrement and return
	bne @update_buf			;just mix with output buffer

@no_repeat:
	lda FT_SFX_PTR_H,x		;check if MSB of the pointer is not zero
	bne @sfx_active
	rts						;return otherwise, no active effect

@sfx_active:
	sta <FT_TEMP_PTR_H		;load effect pointer into temp
	lda FT_SFX_PTR_L,x
	sta <FT_TEMP_PTR_L
	ldy FT_SFX_OFF,x
	clc

@read_byte:
	lda (FT_TEMP_PTR),y		;read byte of effect
	bmi @get_data			;if bit 7 is set, it is a register write
	beq @eof
	iny
	sta FT_SFX_REPEAT,x		;if bit 7 is reset, it is number of repeats
	tya
	sta FT_SFX_OFF,x
	jmp @update_buf

@get_data:
	iny
	stx <FT_TEMP_VAR1		;it is a register write
	adc <FT_TEMP_VAR1		;get offset in the effect output buffer
	tax
	lda (FT_TEMP_PTR),y		;read value
	iny
	sta FT_SFX_BUF-128,x	;store into output buffer
	ldx <FT_TEMP_VAR1
	jmp @read_byte			;and read next byte

@eof:
	sta FT_SFX_PTR_H,x		;mark channel as inactive

@update_buf:

	lda FT_OUT_BUF			;compare effect output buffer with main output buffer
	and #$0f				;if volume of pulse 1 of effect is higher than that of the
	sta <FT_TEMP_VAR1		;main buffer, overwrite the main buffer value with the new one
	lda FT_SFX_BUF+0,x
	and #$0f
	cmp <FT_TEMP_VAR1
	bcc @no_pulse1
	lda FT_SFX_BUF+0,x
	sta FT_OUT_BUF+0
	lda FT_SFX_BUF+1,x
	sta FT_OUT_BUF+1
	lda FT_SFX_BUF+2,x
	sta FT_OUT_BUF+2
@no_pulse1:

	lda FT_OUT_BUF+3		;same for pulse 2
	and #$0f
	sta <FT_TEMP_VAR1
	lda FT_SFX_BUF+3,x
	and #$0f
	cmp <FT_TEMP_VAR1
	bcc @no_pulse2
	lda FT_SFX_BUF+3,x
	sta FT_OUT_BUF+3
	lda FT_SFX_BUF+4,x
	sta FT_OUT_BUF+4
	lda FT_SFX_BUF+5,x
	sta FT_OUT_BUF+5
@no_pulse2:

	lda FT_SFX_BUF+6,x		;overwrite triangle of main output buffer if it is active
	beq @no_triangle
	sta FT_OUT_BUF+6
	lda FT_SFX_BUF+7,x
	sta FT_OUT_BUF+7
	lda FT_SFX_BUF+8,x
	sta FT_OUT_BUF+8
@no_triangle:

	lda FT_OUT_BUF+9		;same as for pulse 1 and 2, but for noise
	and #$0f
	sta <FT_TEMP_VAR1
	lda FT_SFX_BUF+9,x
	and #$0f
	cmp <FT_TEMP_VAR1
	bcc @no_noise
	lda FT_SFX_BUF+9,x
	sta FT_OUT_BUF+9
	lda FT_SFX_BUF+10,x
	sta FT_OUT_BUF+10
@no_noise:

	rts

	.endif


;dummy envelope used to initialize all channels with silence

_FT2DummyEnvelope:
	.byte $c0,$00,$00

;PAL and NTSC, 11-bit dividers
;rest note, then octaves 1-5, then three zeroes
;first 64 bytes are PAL, next 64 bytes are NTSC

_FT2NoteTableLSB:
	.if(FT_PAL_SUPPORT)
		.byte $00
		.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $60, $f6, $92 ; Octave 0
		.byte $34, $db, $86, $37, $ec, $a5, $62, $23, $e8, $b0, $7b, $49 ; Octave 1
		.byte $19, $ed, $c3, $9b, $75, $52, $31, $11, $f3, $d7, $bd, $a4 ; Octave 2
		.byte $8c, $76, $61, $4d, $3a, $29, $18, $08, $f9, $eb, $de, $d1 ; Octave 3
		.byte $c6, $ba, $b0, $a6, $9d, $94, $8b, $84, $7c, $75, $6e, $68 ; Octave 4
		.byte $62, $5d, $57, $52, $4e, $49, $45, $41, $3e, $3a, $37, $34 ; Octave 5
		.byte $31, $2e, $2b, $29, $26, $24, $22, $20, $1e, $1d, $1b, $19 ; Octave 6
		.byte $18, $16, $15, $14, $13, $12, $11, $10, $0f, $0e, $0d, $0c ; Octave 7
	.endif
	.if(FT_NTSC_SUPPORT)
		.byte $00
		.byte $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f1, $7f, $13 ; Octave 0
		.byte $ad, $4d, $f3, $9d, $4c, $00, $b8, $74, $34, $f8, $bf, $89 ; Octave 1
		.byte $56, $26, $f9, $ce, $a6, $80, $5c, $3a, $1a, $fb, $df, $c4 ; Octave 2
		.byte $ab, $93, $7c, $67, $52, $3f, $2d, $1c, $0c, $fd, $ef, $e1 ; Octave 3
		.byte $d5, $c9, $bd, $b3, $a9, $9f, $96, $8e, $86, $7e, $77, $70 ; Octave 4
		.byte $6a, $64, $5e, $59, $54, $4f, $4b, $46, $42, $3f, $3b, $38 ; Octave 5
		.byte $34, $31, $2f, $2c, $29, $27, $25, $23, $21, $1f, $1d, $1b ; Octave 6
		.byte $1a, $18, $17, $15, $14, $13, $12, $11, $10, $0f, $0e, $0d ; Octave 7
	.endif

_FT2NoteTableMSB:
	.if(FT_PAL_SUPPORT)
		.byte $00
		.byte $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $06, $06 ; Octave 0
		.byte $06, $05, $05, $05, $04, $04, $04, $04, $03, $03, $03, $03 ; Octave 1
		.byte $03, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01 ; Octave 2
		.byte $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00 ; Octave 3
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 4
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 5
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 6
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 7
	.endif
	.if(FT_NTSC_SUPPORT)
		.byte $00
		.byte $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07 ; Octave 0
		.byte $06, $06, $05, $05, $05, $05, $04, $04, $04, $03, $03, $03 ; Octave 1
		.byte $03, $03, $02, $02, $02, $02, $02, $02, $02, $01, $01, $01 ; Octave 2
		.byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00 ; Octave 3
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 4
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 5
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 6
		.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; Octave 7
	.endif

.ifdef FT_VRC6_ENABLE
_FT2SawNoteTableLSB:
	.byte $00
	.byte $44, $69, $9a, $d6, $1e, $70, $cb, $30, $9e, $13, $91, $16 ; Octave 0
	.byte $a2, $34, $cc, $6b, $0e, $b7, $65, $18, $ce, $89, $48, $0a ; Octave 1
	.byte $d0, $99, $66, $35, $07, $db, $b2, $8b, $67, $44, $23, $05 ; Octave 2
	.byte $e8, $cc, $b2, $9a, $83, $6d, $59, $45, $33, $22, $11, $02 ; Octave 3
	.byte $f3, $e6, $d9, $cc, $c1, $b6, $ac, $a2, $99, $90, $88, $80 ; Octave 4
	.byte $79, $72, $6c, $66, $60, $5b, $55, $51, $4c, $48, $44, $40 ; Octave 5
	.byte $3c, $39, $35, $32, $2f, $2d, $2a, $28, $25, $23, $21, $1f ; Octave 6
	.byte $1e, $1c, $1a, $19, $17, $16, $15, $13, $12, $11, $10, $0f ; Octave 7
_FT2SawNoteTableMSB:    
	.byte $00
	.byte $0f, $0e, $0d, $0c, $0c, $0b, $0a, $0a, $09, $09, $08, $08  ; Octave 0
	.byte $07, $07, $06, $06, $06, $05, $05, $05, $04, $04, $04, $04  ; Octave 1
	.byte $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02  ; Octave 2
	.byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01  ; Octave 3
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00  ; Octave 4
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00  ; Octave 5
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00  ; Octave 6
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00  ; Octave 7
.endif

_FT2ChannelToVolumeEnvelope:
	.byte .lobyte(FT_ENVELOPES)+$00
	.byte .lobyte(FT_ENVELOPES)+$03
	.byte .lobyte(FT_ENVELOPES)+$06
	.byte .lobyte(FT_ENVELOPES)+$09

_FT2ChannelToSlide:
	.byte .lobyte(FT_SLIDES)+$00
	.byte .lobyte(FT_SLIDES)+$01
	.byte .lobyte(FT_SLIDES)+$02

; Precomputed volume multiplication table (ceiling) [0-15]x[0-15].
; Load the 2 volumes in the lo/hi nibble and fetch.

_FT2VolumeTable:
 	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
 	.byte $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
 	.byte $00, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02
 	.byte $00, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03
 	.byte $00, $01, $01, $01, $02, $02, $02, $02, $03, $03, $03, $03, $04, $04, $04, $04
 	.byte $00, $01, $01, $01, $02, $02, $02, $03, $03, $03, $04, $04, $04, $05, $05, $05
 	.byte $00, $01, $01, $02, $02, $02, $03, $03, $04, $04, $04, $05, $05, $06, $06, $06
 	.byte $00, $01, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $07
 	.byte $00, $01, $02, $02, $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $08, $08
 	.byte $00, $01, $02, $02, $03, $03, $04, $05, $05, $06, $06, $07, $08, $08, $09, $09
 	.byte $00, $01, $02, $02, $03, $04, $04, $05, $06, $06, $07, $08, $08, $09, $0a, $0a
 	.byte $00, $01, $02, $03, $03, $04, $05, $06, $06, $07, $08, $09, $09, $0a, $0b, $0b
 	.byte $00, $01, $02, $03, $04, $04, $05, $06, $07, $08, $08, $09, $0a, $0b, $0c, $0c
 	.byte $00, $01, $02, $03, $04, $05, $06, $07, $07, $08, $09, $0a, $0b, $0c, $0d, $0d
 	.byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0e
 	.byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
