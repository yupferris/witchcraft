#import "common.inc"

    .pc = demo_entry "entry"
entry:
    jsr mask_nmi

    // Turn off CIA interrupts
    lda #$7f
    sta $dc0d
    sta $dd0d

    // Enable raster interrupts
    lda #$01
    sta $d01a

    jsr init

    // Ack CIA interrupts
    lda $dc0d
    lda $dd0d

    // Ack VIC interrupts
    asl $d019

    cli

    jmp *

    .pc = * "mask nmi"
mask_nmi:
    // Stop timer A
    lda #$00
    sta $dd0e

    // Set timer A to 0 after starting
    sta $dd04
    sta $dd05

    // Set timer A as NMI source
    lda #$81
    sta $dd0d

    // Set NMI vector
    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb

    // Start timer A (NMI triggers immediately)
    lda #$01
    sta $dd0e

    rts

nmi:
    rti

    .const zp_base = $02

    .const frame_counter = zp_base
    .const frame_counter_low = frame_counter
    .const frame_counter_high = zp_base + 1

    .const sprite_frame_index = zp_base + 2
    .const sprite_frame_counter = zp_base + 3

    .const scroller_offset = zp_base + 4
    .const scroller_effect_index = zp_base + 5
    .const scroller_temp = zp_base + 6

    .const bg_fade_fade_index = zp_base + 7

    .const background_bitmap_pos = $4000
    .const background_screen_mem_pos = $6000

    .const scroller_stretcher_lines = 24 - 2
    .const scroller_font_pos = $6800
    .const scroller_text_pos = $8000
    .const scroller_color_table = $9000
    .const scroller_d018_table = scroller_color_table + scroller_stretcher_lines

    .const sprite_pos = $7000
    .const sprite_data_ptr_pos = background_screen_mem_pos + $3f8

    .pc = * "init"
init:
    // Reset graphics mode/scroll
    lda #$1b
    sta $d011

    // Reset vars
    lda #$00
    sta frame_counter_low
    sta frame_counter_high
    sta sprite_frame_index
    sta sprite_frame_counter
    sta scroller_offset
    sta scroller_effect_index
    sta bg_fade_fade_index

    // Set background colors
    lda #$00
    sta $d020
    sta $d021

    // Set initial color+screen mem contents
    lda #$00
    tax
!:      sta $d800, x
        sta $d900, x
        sta $da00, x
        sta $db00, x
        sta background_screen_mem_pos, x
        sta background_screen_mem_pos + $100, x
        sta background_screen_mem_pos + $200, x
        sta background_screen_mem_pos + $300, x
    inx
    bne !-

    // Unpack scroller font
    //  Bank out io regs
    lda #$34
    sta $01

    ldx #$00
unpack_font_char_loop:
        txa
        pha

        ldx #$00
unpack_font_line_loop:
            // Read char line byte
unpack_font_read_instr:
            lda scroller_font_pos, x

            // Write char line byte 8x
            ldy #$00
unpack_font_write_loop:
unpack_font_write_instr:
                sta $c000, y
            iny
            cpy #$08
            bne unpack_font_write_loop

            // Move write ptr to next charset
            lda unpack_font_write_instr + 2
            clc
            adc #$08
            sta unpack_font_write_instr + 2
        inx
        cpx #$08
        bne unpack_font_line_loop

        // Increment read ptr for next char
        lda unpack_font_read_instr + 1
        clc
        adc #$08
        sta unpack_font_read_instr + 1
        bcc !+
            inc unpack_font_read_instr + 2

        // Subtract charset offsets from write ptr
!:      lda unpack_font_write_instr + 2
        sec
        sbc #$40
        sta unpack_font_write_instr + 2

        // Increment write ptr for next char
        lda unpack_font_write_instr + 1
        clc
        adc #$08
        sta unpack_font_write_instr + 1
        bcc !+
            inc unpack_font_write_instr + 2

!:      pla
        tax
    inx
    cpx #$80
    bne unpack_font_char_loop

    //  Bank in io regs
    lda #$35
    sta $01

    // Clear out original font data
    //  This way we get a blank charset, useful for hiding some buggy stuff while doing the scroll rastersplits
    ldx #$00
clear_font_outer_loop:
        lda #$00
        tay
clear_font_inner_loop:
clear_font_write_instr:
            // Clear char line byte
            sta scroller_font_pos, y
        iny
        bne clear_font_inner_loop

        // Increment write ptr for next char
        inc clear_font_write_instr + 2
    inx
    cpx #$08
    bne clear_font_outer_loop

    // Set scroller color mem contents
    lda #$00
    ldx #$00
!:      sta $d800 + 20 * 40, x
    inx
    cpx #40
    bne !-

    // Clear scroller screen mem (set to spaces, $20)
    lda #$20
    ldx #$00
!:      sta background_screen_mem_pos + 20 * 40, x
    inx
    cpx #40
    bne !-

    // Set sprite positions
    //  Note these initial positions were taken straight from the spec image, so they'll need some transformation for actual reg values
    .const sprite_positions_x = List().add(  1,   8,  11,  76, 135, 143, 133, 138).lock()
    .const sprite_positions_y = List().add( 63,  43, 101,  76,  20,  47,  71, 110).lock()
    .var sprite_pos_x_msbs = 0
    .for (var i = 0; i < 8; i++) {
        .var x = sprite_positions_x.get(i) * 2 + $18
        .var y = sprite_positions_y.get(i) + $32
        .eval sprite_pos_x_msbs = (sprite_pos_x_msbs >> 1) | ((x >> 1) & $80)
        lda #(x & $ff)
        sta $d000 + i * 2
        lda #y
        sta $d001 + i * 2
    }
    lda #sprite_pos_x_msbs
    sta $d010

    // Set initial sprite colors
    lda #$00
    sta $d025
    sta $d026
    .for (var i = 0; i < 8; i++) {
        sta $d027 + i
    }

    // Enable sprites
    lda #$ff
    sta $d015

    // Set sprite multicolor
    lda #$ff
    sta $d01c

    // Set up frame interrupt
    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$ff
    sta $d012

    // Init music
    lda #$00
    tax
    tay
    jsr music

    rts

    .pc = * "frame"
frame:
    pha
    txa
    pha
    tya
    pha

    //inc $d020

    // Set multicolor bitmap mode
    lda #$3b
    sta $d011
    lda #$18
    sta $d016

    // Set graphics/screen pointers
    lda #$80
    sta $d018

    // Set graphics bank 1
    lda #$c6
    sta $dd00

    // Increment frame counter
    inc frame_counter_low
    bne !+
        inc frame_counter_high

    // Update sprite ptrs
!:  lda sprite_frame_index
    and #$07
    clc
    adc #$c0

    .for (var i = 0; i < 8; i++) {
        sta sprite_data_ptr_pos + i
        .if (i < 7) {
            clc
            adc #$08
        }
    }

    inc sprite_frame_counter
    lda sprite_frame_counter
    cmp #$03
    bne !+
        inc sprite_frame_index

        lda #$00
        sta sprite_frame_counter

    // Update scroller
!:  jsr scroller_update

    // Update bg fade
    jsr bg_fade_update

    // Update music
    //inc $d020
    jsr music + 3
    //dec $d020

    // Set 2x interrupt
    lda #<music2x
    sta $fffe
    lda #>music2x
    sta $ffff
    lda #99
    sta $d012

    //dec $d020

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .pc = * "music 2x"
music2x:
    pha
    txa
    pha
    tya
    pha

    // Update music 2x
    //inc $d020
    jsr music + 6
    //dec $d020

    // Set scroller display interrupt
    lda #<scroller_display
    sta $fffe
    lda #>scroller_display
    sta $ffff
    lda #206
    sta $d012

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .align $100
    .pc = * "scroller display"
scroller_display:
    pha
    txa
    pha
    tya
    pha

    // Set up next interrupt stage
    lda #<semi_stable_scroller_display
    sta $fffe
    inc $d012

    // ACK so next stage can fire
    asl $d019

    // Save sp into x (we'll restore in the next stage)
    tsx

    // Clear interrupt flag so next stage can fire
    cli

    // nop pads (next stage should fire in here somewhere)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    jmp * // Safety net (if we see more than 1-cycle jitter for the next int, we got here)

    // Semi-stable int with 1 cycle jitter
    .pc = * "semi-stable scroller display"
semi_stable_scroller_display:
    // Restore sp
    txs

    // Clear last bank byte to remove graphical glitches
    lda #$00
    sta $ffff

    // Wait a bit
    ldx #$2d
!:      dex
    bne !-
    nop
    nop

    // Set charset/screen ptr
    lda #$8a
    sta $d018

    // Switch to hires char mode, 38 columns width
    lda #$1b
    sta $d011
    lda scroller_offset
    sta $d016

    // Set VIC bank 0
    lda #$c4
    sta $dd00

    // Stretcher loop
    .for (var i = 0; i < scroller_stretcher_lines; i++) {
        lda scroller_d018_table + i
        sta $d018

        lda scroller_color_table + i
        sta $d021

        lda #$00
        sta scroller_d018_table + i
        sta scroller_color_table + i

        .if (i < scroller_stretcher_lines - 1) {
            ldx #$03
!:              dex
            bne !-
            nop
            nop
            bit $00

            .if (((i + 1) & $07) == $07) {
                lda #$1a
            } else {
                lda #$1b
            }
            sta $d011 // This write should occur on cycle 55-57 each scanline, except the last one

            nop
            nop
            nop
            nop
        }
    }

    // Wait a bit
    ldx #$02
!:      dex
    bne !-
    nop
    nop
    nop
    nop
    bit $00

    // Reset VIC bank 1
    lda #$c6
    sta $dd00

    // Reset graphics/screen pointers
    lda #$80
    sta $d018

    // Reset multicolor bitmap mode
    lda #$3b
    sta $d011
    lda #$18
    sta $d016

    // Reset background color
    lda #$00
    sta $d021

    //inc $d020

    // Reset frame interrupt
    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$ff
    sta $d012

    //dec $d020

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .pc = $1000 "music"
music:
    .import c64 "music.prg"

    .pc = * "scroller effect jump table"
scroller_effect_jump_table:
    .word static_y_scroller - 1
    .word dynamic_y_scroller - 1
    .word mirrored_scroller - 1
    .word layered_scrollers - 1
    .word squishy_scroller - 1
    .word repeating_scroller - 1

    .pc = * "scroller update"
scroller_update:
    // Update effect index
    lda frame_counter_low
    bne scroller_effect_index_update_done
    lda frame_counter_high
    and #$01
    bne scroller_effect_index_update_done
        inc scroller_effect_index
        lda scroller_effect_index
        cmp #$06
        bne scroller_effect_index_update_done
            lda #$01
            sta scroller_effect_index
scroller_effect_index_update_done:

    // Dispatch effect
    lda scroller_effect_index
    asl
    tax
    lda scroller_effect_jump_table + 1, x
    pha
    lda scroller_effect_jump_table, x
    pha
    rts

    // Static y scroller
static_y_scroller:
        ldy #(scroller_stretcher_lines / 2 - 8 / 2)
        ldx #$00
!:          lda #$01
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$08
        bne !-
    jmp scroller_effect_done

    // Dynamic y scroller
dynamic_y_scroller:
        lda frame_counter_low
        asl
        asl
        clc
        adc frame_counter_low
        tax
        lda scroller_y_offset_tab, x
        pha
        lda frame_counter_low
        asl
        asl
        tax
        pla
        clc
        adc scroller_y_offset_tab, x
        lsr
        tay
        ldx #$00
!:          lda #$01
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$08
        bne !-
    jmp scroller_effect_done

    // Mirrored scroller
mirrored_scroller:
        // Top part
        lda #(scroller_stretcher_lines / 2 - 7)
        ldx frame_counter_low
        sec
        sbc mirrored_scroller_y_tab, x
        tay
        ldx #$00
!:          lda #$01
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$07
        bne !-

        // Bottom part
        lda #(scroller_stretcher_lines / 2)
        ldx frame_counter_low
        clc
        adc mirrored_scroller_y_tab, x
        tay
        ldx #$00
!:          lda #$0b
            sta scroller_color_table, y
            txa
            eor #$ff
            clc
            adc #$07
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$07
        bne !-
    jmp scroller_effect_done

    // Layered scrollers
layered_scrollers:
        lda frame_counter_low
        lsr
        and #$0f
        tax
        lda layered_scrollers_color_tab_1, x
        sta scroller_temp
        lda frame_counter_low
        asl
        asl
        clc
        adc frame_counter_low
        tax
        lda scroller_y_offset_tab, x
        pha
        lda frame_counter_low
        asl
        asl
        tax
        pla
        clc
        adc scroller_y_offset_tab, x
        lsr
        tay
        ldx #$00
!:          lda scroller_temp
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$07
        bne !-

        lda frame_counter_low
        lsr
        clc
        adc #$04
        and #$0f
        tax
        lda layered_scrollers_color_tab_2, x
        sta scroller_temp
        lda frame_counter_low
        clc
        adc #$30
        asl
        clc
        adc frame_counter_low
        tax
        lda scroller_y_offset_tab, x
        pha
        lda frame_counter_low
        tax
        pla
        clc
        adc scroller_y_offset_tab, x
        lsr
        tay
        ldx #$00
!:          lda scroller_temp
            sta scroller_color_table, y
            txa
            eor #$ff
            clc
            adc #$07
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$07
        bne !-

        lda frame_counter_low
        lsr
        clc
        adc #$08
        and #$0f
        tax
        lda layered_scrollers_color_tab_3, x
        sta scroller_temp
        lda frame_counter_low
        clc
        adc #$67
        asl
        asl
        tax
        lda scroller_y_offset_tab, x
        tay
        ldx #$00
!:          lda scroller_temp
            sta scroller_color_table, y
            txa
            asl
            sta scroller_d018_table, y
            iny
        inx
        cpx #$07
        bne !-
    jmp scroller_effect_done

layered_scrollers_color_tab_1:
    .byte $0b, $02, $04, $03, $01, $03, $04, $02, $02, $02, $02, $02, $02, $02, $02, $02

layered_scrollers_color_tab_2:
    .byte $0b, $0c, $0f, $01, $01, $0f, $0c, $0b, $0b, $0b, $0b, $0b, $0b, $0b, $0b, $0b

layered_scrollers_color_tab_3:
    .byte $0b, $06, $0e, $0d, $01, $0d, $0e, $06, $06, $06, $06, $06, $06, $06, $06, $06

    // Squishy scroller
squishy_scroller:
        lda frame_counter_low
        asl
        asl
        asl
        asl
        sta scroller_temp
        ldx #$00
squishy_scroller_loop:
            lda scroller_temp
            and #$80
            bne !+
                lda scroller_temp
                lsr
                lsr
                lsr
                sta scroller_d018_table, x
                sec
                sbc frame_counter_low
                lsr
                and #$0f
                tay
                lda squishy_scroller_color_tab, y
                sta scroller_color_table, x
!:          ldy frame_counter_low
            txa
            eor #$ff
            asl
            clc
            adc scroller_y_offset_tab_2, y
            tay
            lda scroller_temp
            clc
            adc squishy_scroller_y_tab, y
            sta scroller_temp
        inx
        cpx #scroller_stretcher_lines
        bne squishy_scroller_loop
    jmp scroller_effect_done

squishy_scroller_color_tab:
    .byte $0b, $0f, $0c, $0f, $01, $01, $01, $01
    .byte $01, $01, $01, $01, $0f, $0c, $0f, $0b

    // Repeating scroller
repeating_scroller:
        lda frame_counter_low
        asl
        clc
        adc frame_counter_low
        tax
        lda scroller_y_offset_tab_2, x
        lsr
        pha
        lda frame_counter_low
        asl
        tax
        pla
        clc
        adc scroller_y_offset_tab_2, x
        tay
        ldx #$00
!:          tya
            pha
            lsr
            clc
            adc frame_counter_low
            and #$3f
            tay
            lda repeating_scroller_color_tab, y
            sta scroller_color_table, x
            pla
            tay
            sta scroller_d018_table, x
            iny
            iny
        inx
        cpx #scroller_stretcher_lines
        bne !-
    jmp scroller_effect_done

repeating_scroller_color_tab:
    .byte $0b, $02, $0b, $0b, $0b, $0b, $04, $0b
    .byte $04, $0b, $04, $04, $04, $04, $03, $04
    .byte $03, $04, $03, $03, $03, $03, $0d, $03
    .byte $0d, $03, $0d, $0d, $0d, $0d, $01, $0d
    .byte $01, $0d, $01, $01, $01, $01, $07, $01
    .byte $07, $01, $07, $07, $07, $07, $0a, $07
    .byte $0a, $07, $0a, $0a, $0a, $0a, $02, $0a
    .byte $02, $0a, $02, $02, $02, $02, $04, $02

    // Scroller transition effect
scroller_effect_done:
    lda frame_counter_low
    cmp #scroller_stretcher_lines
    bcs scroller_transition_out_test
    lda frame_counter_high
    and #$01
    bne scroller_transition_out_test
        // Transition in
        lda #scroller_stretcher_lines
        sec
        sbc frame_counter_low
        jmp scroller_transition

scroller_transition_out_test:
    lda frame_counter_low
    cmp #(256 - scroller_stretcher_lines)
    bcc scroller_transition_done
    lda frame_counter_high
    and #$01
    beq scroller_transition_done
        // Transition out
        lda frame_counter_low
        sec
        sbc #(256 - scroller_stretcher_lines)

scroller_transition:
    lsr
    pha

    // Top half
    tax
    inx
    lda #$00
    tay
!:      sta scroller_color_table, y
        iny
    dex
    bne !-

    // Bottom half
    pla

    tax
    inx
    lda #$00
    ldy #(scroller_stretcher_lines - 1)
!:      sta scroller_color_table, y
        dey
    dex
    bne !-

scroller_transition_done:
    dec scroller_offset
    lda scroller_offset
    and #$07
    sta scroller_offset

    cmp #$07
    beq !+
        jmp scroller_update_done
        // Shift screen mem
!:      .for (var i = 0; i < 39; i++) {
            lda background_screen_mem_pos + 20 * 40 + i + 1
            sta background_screen_mem_pos + 20 * 40 + i
        }

        // Load next char
scroller_text_load_instr:
        lda scroller_text
        sta background_screen_mem_pos + 20 * 40 + 39

        // Update (and possibly reset) text pointer
        inc scroller_text_load_instr + 1
        bne !+
            inc scroller_text_load_instr + 2
!:      lda scroller_text_load_instr + 1
        cmp #<scroller_text_end
        bne scroller_update_done
        lda scroller_text_load_instr + 2
        cmp #>scroller_text_end
        bne scroller_update_done
            lda #<scroller_text
            sta scroller_text_load_instr + 1
            lda #>scroller_text
            sta scroller_text_load_instr + 2

scroller_update_done:
    rts

    .pc = * "bg fade update"
bg_fade_update:
    //inc $d020

    lda frame_counter_low
    bne !+
    lda frame_counter_high
    and #$03
    bne !+
        inc bg_fade_fade_index
        lda bg_fade_fade_index
        cmp #$05
        bne !+
            lda #$01
            sta bg_fade_fade_index

!:  lda frame_counter_high
    and #$03
    beq !+
        jmp bg_fade_update_done

    // Fade sprites
!:  lda bg_fade_fade_index
    asl
    tax
    lda bg_fade_screen_mem_index_tab, x
    sta bg_fade_sprite_color_1_2_read_instr + 1
    lda bg_fade_screen_mem_index_tab + 1, x
    sta bg_fade_sprite_color_1_2_read_instr + 2
    lda bg_fade_color_mem_index_tab, x
    sta bg_fade_sprite_color_3_read_instr + 1
    lda bg_fade_color_mem_index_tab + 1, x
    sta bg_fade_sprite_color_3_read_instr + 2

    lda frame_counter_low
    lsr
    lsr
    sec
    sbc #$08
    cmp #$10
    bcs !+
        // Invert table index
        eor #$ff
        clc
        adc #$10
        tax
bg_fade_sprite_color_1_2_read_instr:
        lda bg_fade_screen_mem_tab_0, x
        pha
        lsr
        lsr
        lsr
        lsr
        sta $d025
        pla
        and #$0f
        .for (var i = 0; i < 8; i++) {
            sta $d027 + i
        }
bg_fade_sprite_color_3_read_instr:
        lda bg_fade_color_mem_tab_0, x
        sta $d026

    // Fade BG
!:  lda bg_fade_fade_index
    asl
    tax
    lda bg_fade_screen_mem_index_tab, x
    sta bg_fade_loop_screen_mem_read_instr + 1
    lda bg_fade_screen_mem_index_tab + 1, x
    sta bg_fade_loop_screen_mem_read_instr + 2
    lda bg_fade_color_mem_index_tab, x
    sta bg_fade_loop_color_mem_read_instr + 1
    lda bg_fade_color_mem_index_tab + 1, x
    sta bg_fade_loop_color_mem_read_instr + 2

    lda frame_counter_low
    lsr
    sec
    sbc #$10
    tax
    ldy #$00
bg_fade_loop:
        cpx #40
        bcc !+
            jmp bg_fade_loop_continue
bg_fade_loop_screen_mem_read_instr:
!:      lda bg_fade_screen_mem_tab_0, y
        .for (var y = 0; y < 25; y++) {
            .if (y < 20 || y >= 23) {
                sta background_screen_mem_pos + y * 40, x
            }
        }
bg_fade_loop_color_mem_read_instr:
        lda bg_fade_color_mem_tab_0, y
        .for (var y = 0; y < 25; y++) {
            .if (y < 20 || y >= 23) {
                sta $d800 + y * 40, x
            }
        }
bg_fade_loop_continue:
        inx
    iny
    cpy #$10
    beq bg_fade_update_done
        jmp bg_fade_loop

bg_fade_update_done:
    //dec $d020

    rts

bg_fade_screen_mem_index_tab:
    .word bg_fade_screen_mem_tab_0
    .word bg_fade_screen_mem_tab_1
    .word bg_fade_screen_mem_tab_2
    .word bg_fade_screen_mem_tab_3
    .word bg_fade_screen_mem_tab_4

bg_fade_color_mem_index_tab:
    .word bg_fade_color_mem_tab_0
    .word bg_fade_color_mem_tab_1
    .word bg_fade_color_mem_tab_2
    .word bg_fade_color_mem_tab_3
    .word bg_fade_color_mem_tab_4

bg_fade_screen_mem_tab_0:
    .byte $6e, $6e, $6c, $04, $0b, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
bg_fade_color_mem_tab_0:
    .byte $01, $0d, $03, $0c, $04, $0b, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00

bg_fade_screen_mem_tab_1:
    .byte $2a, $24, $92, $92, $99, $09, $00, $00, $00, $00, $06, $0b, $04, $6c, $6e, $6e
bg_fade_color_mem_tab_1:
    .byte $07, $0f, $0a, $08, $02, $09, $00, $00, $00, $06, $0b, $04, $0c, $03, $0d, $01

bg_fade_screen_mem_tab_2:
    .byte $5d, $cf, $4c, $48, $b2, $69, $00, $00, $00, $00, $09, $99, $92, $92, $24, $2a
bg_fade_color_mem_tab_2:
    .byte $01, $0d, $03, $0c, $04, $0b, $06, $00, $00, $00, $09, $02, $08, $0a, $0f, $07

bg_fade_screen_mem_tab_3:
    .byte $bc, $b4, $bb, $6b, $66, $60, $00, $00, $00, $00, $69, $b2, $48, $4c, $cf, $5d
bg_fade_color_mem_tab_3:
    .byte $0f, $0c, $04, $04, $0b, $0b, $06, $00, $00, $06, $0b, $04, $0c, $03, $0d, $01

bg_fade_screen_mem_tab_4:
    .byte $6e, $6e, $6c, $04, $0b, $06, $00, $00, $00, $00, $60, $66, $6b, $bb, $b4, $bc
bg_fade_color_mem_tab_4:
    .byte $01, $0d, $03, $0c, $04, $0b, $06, $00, $00, $06, $0b, $0b, $04, $04, $0c, $0f

    .align $100
    .pc = * "scroller tables"
scroller_y_offset_tab:
    .for (var i = 0; i < 256; i++) {
        .byte round((sin(toRadians(i / 256 * 360)) * 0.5 + 0.5) * 15)
    }
scroller_y_offset_tab_2:
    .for (var i = 0; i < 256; i++) {
        .byte round((sin(toRadians(i / 256 * 360)) * 0.5 + 0.5) * 128)
    }

mirrored_scroller_y_tab:
    .for (var i = 0; i < 256; i++) {
        .byte round(abs(sin(toRadians(i / 256 * 360 * 6))) * 4)
    }

squishy_scroller_y_tab:
    .for (var i = 0; i < 256; i++) {
        .byte round((sin(toRadians((i / 256 - 0.3) * 360 * 2)) * 0.5 + 0.5) * 26 - 12)
    }

    .pc = background_bitmap_pos "background bitmap"
background_bitmap:
    .import binary "build/background_bitmap.bin"

    .pc = scroller_font_pos "scroller font"
scroller_font:
    .import binary "build/font.bin"

    .pc = sprite_pos "sprites"
sprites:
    .import binary "build/sprites_blob.bin"

    .pc = scroller_text_pos "scroller text"
scroller_text:
    // Delay scroll intro a bit by adding some spaces at the beginning
    .text "                "
    .text "Hello Datastorm, WHAT IS UP?? "
    .text "Ferris on the keys here for this small demo by Pegboard Nerds and Logicoma. "
    .text "Credits: "
    .text "- Music: Flipside (Witchcraft/Pendulum cover) "
    .text "- Graphics: Flipside "
    .text "- Code: Ferris "
    .text "-     "
    .text "This thing started with Flipside doing a sick SID cover of this fab tune as well as a 'graphic cover' of the original album artwork! "
    .text "He then approached me asking if we could make a 'cool oldschool thing with crazy color scroller' and seeing as I've been itching to do some more cool hw tricks (I'm still kinda "
    .text "new to c64 after all) it was pretty easy to take the bait! "
    .text "In quite short time we got the gfx converted and added some scroller/fade tech porn, and the timing just so happened to coincide nicely with Datastorm, so here we are! "
    .text "This was pretty fun to put together, and I doubt this will be our last collab together.. :) "
    .text "    "
    .text "What you're looking at is a beauty of a 4-color multicolor pic with a sprite layer for the stars, as well as a FPP scroller display. Perhaps nothing particularly innovative, "
    .text "but a nice homage to the oldschool style and really fun to make :) . "
    .text "The track was composed with SID-Wizard and runs in double speed for extra PUNCH! "
    .text "All of this is packed with my own custom packer called admiral p4kbar. "
    .text "    "
    .text "Well that's about it for this little prod. Thanks and greets to everyone at Datastorm for a lovely party; this won't be the last you hear from us! :) "
    // 40 chars of spaces at the end to make sure the screen goes blank before looping
    .text "                                        "
scroller_text_end:
