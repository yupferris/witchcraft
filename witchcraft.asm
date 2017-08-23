    .pc = $0801 "autostart"
    :BasicUpstart(entry)

    .pc = $080d "entry"
entry:
    sei

    // Bank out BASIC and kernal ROMs
    lda #$35
    sta $01

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

    .const fldtabi = $02

    .pc = * "init"
init:
    lda #$1b
    sta $d011

    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$00
    sta $d012
    sta fldtabi
    sta $3fff

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

    // Update music
    inc $d020
    jsr music + 3
    dec $d020

    // Set 2x interrupt
    lda #<music2x
    sta $fffe
    lda #>music2x
    sta $ffff
    lda #(312 / 2)
    sta $d012

    inc fldtabi
    ldy fldtabi
!:      ldx $d012
            cpx $d012
        beq * - 3
        txa
        cmp fldytab, y
        beq !+
            and #$07
            ora #$18
            sta $d011
    jmp !-

!:  pla
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
    inc $d020
    jsr music + 6
    dec $d020

    // Reset frame interrupt
    lda #<frame
    sta $fffe
    lda #>frame
    sta $ffff
    lda #$00
    sta $d012

    pla
    tay
    pla
    tax
    pla
    asl $d019
    rti

    .pc = * "fldytab"
fldytab:
    .for (var i = 0; i < 256; i++) {
        .byte [-cos(i / 256 * 2 * 3.14159265) * 0.5 + 0.5] * 105 + 44
    }

    .pc = $1000 "music"
music:
    .import c64 "music.prg"
