# A8 Cassette Diagnostics: User Guide

Version 0.5

Every file has its version in its name (`diag-32k-xl-xe-v0.5.cas`), and
every screen shows it at the right of the title bar (`V0.5`). If the two
don't match, or a screen shows no version, you are running an older file.
This guide leaves the `-v0.5` out of the names.

These tapes test any Atari 8-bit computer: the 400, 800, 1200XL, 600XL,
800XL, 65XE, 800XE, 130XE and XE Game System. You load them like any
cassette program. They tell you what works and what doesn't, by colour and
by beeps first, and with text on screen once the screen itself has been
checked. So they're still useful when the picture is bad.

You don't need to know any programming. You need the `.cas` files from the
`cassettes` folder and a way to play them into the machine (see
[Loading a tape](#loading-a-tape)). With a disk drive, two of them also
come as disk files, in the `disks` folder (see [From disk](#from-disk)),
and all of the tests are on one cartridge, in the `carts` folder (see
[From the cartridge](#from-the-cartridge)).

Pictures in this guide come from the project's simulator, using the MiSTer
Atari800 core's NTSC palette and a real Atari OS font. The colours and
their RGB values are what the MiSTer core shows; a real TV or monitor may
differ a little.

## Contents

1. [Why cassette, and why several sets](#why-cassette-and-why-several-sets)
2. [Which tapes for which machine](#which-tapes-for-which-machine)
3. [Loading a tape](#loading-a-tape)
4. [Reading the results: the screen, colours, beeps, keys](#reading-the-results)
5. [The tapes, screen by screen](#the-tapes-screen-by-screen)
6. [When something fails](#when-something-fails)
7. [Questions](#questions)

## Why cassette, and why several sets

**Cassette, because it needs the least of the machine.** A cassette boot
needs only the computer, its OS ROM, the first few K of RAM and the SIO
port. There's no disk drive to work, no DOS to load, and nothing else for
the tape to depend on. So it runs on the smallest machine there is, a 400
with 8K, and on a machine too sick to boot a disk. Each tape loads into the
bottom of RAM and tests everything else from there.

**A disk version is planned.** It will load much faster, for machines with a
working disk drive. The cassette tapes stay as the version for low-spec and
failing machines.

**Several sets, because tape is slow.** A cassette loads at 600 baud:
about 3K a minute. So the tests are split by how much RAM the machine has,
and the more RAM, the fewer tapes:
- **8K or more:** the 400 set, five small tapes of about 2 minutes each.
- **16K or more:** the 16k set, two tapes of about 3.5 minutes each.
- **32K or more:** the 32k+ tape, one tape of about 6 minutes.

A set works on every machine with at least that much RAM, whatever the
model. So any Atari can run the 400 set, and a 130XE can run all three.
The bigger set is just quicker to get through.

Within each set, every tape only relies on what an earlier one proved. For
example, RAM is tested before anything else runs from it, and the keyboard
is tested before a test asks you a yes/no question.

## Which tapes for which machine

**Pick by RAM.** Use the biggest set your machine has the RAM for:

| RAM | Tapes, in this order | Long test (optional) |
|---|---|---|
| 8K or more | the 400 set: `diag-400-01-ram`, `-02-rom`, `-03-input`, `-04-ports`, `-05-av` | `diag-400-memtest` |
| 16K or more | the 16k set: `diag-16k-01-ram`, `diag-16k-02-system` | `diag-memtest` |
| 32K or more | the 32k+ tape: `diag-32k-xl-xe` | `diag-memtest` |

For the keyboard, joysticks and paddles only: `diag-controls` (16K or more).

How much RAM the models came with (an upgraded machine counts what it
has now):

| Model | RAM |
|---|---|
| 400 | 8K or 16K |
| 800 | 8K to 48K |
| 600XL | 16K, or 64K with a 1064 memory module |
| 1200XL, 800XL, 65XE, 800XE, XE Game System | 64K |
| 130XE | 128K |

Not sure how much RAM there is? Load `diag-400-01-ram`: it runs on every
Atari and shows the RAM it found. Or just try a bigger tape: one that needs
more RAM than the machine has stops at once with a red border and a low
tone, on and off (see [Colours](#colours)).

**When a machine won't get through its own set**, use the 400 set: it
needs only the first 8K of RAM to work, so it's the fallback for every
machine.

All the tapes:

| Tape | Needs | Load time | Tests |
|---|---|---|---|
| `diag-400-01-ram` | 8K | 2 min, then 1.5 min for part 2 | the video check and all the RAM. Part 2 (machines with 16K or more): the RAM the tape itself used, the RAM under an XL/XE's OS and a 130XE's extra RAM |
| `diag-400-02-rom` | 8K | 2 min | test 1, the ROMs |
| `diag-400-03-input` | 8K | 2 min | tests 2 and 3, the keyboard and the console keys |
| `diag-400-04-ports` | 8K | 2 min | tests 4 and 5, the joysticks and the paddles |
| `diag-400-05-av` | 8K | 2 min | tests 6 and 7, the sound (POKEY) and the video (GTIA) |
| `diag-400-memtest` | 8K | 2 min | the memory test, until you stop it (main RAM only) |
| `diag-16k-01-ram` | 16K | 3.5 min | the whole RAM test in one load: all the RAM, the tape's own, under an XL/XE's OS, and a 130XE's extra RAM |
| `diag-16k-02-system` | 16K | 3.5 min | tests 1-7, with a menu |
| `diag-32k-xl-xe` | 32K | 6 min | the whole RAM test, then tests 1-7 with a menu, in one load |
| `diag-memtest` | 16K | 2.5 min | the memory test, until you stop it (all the RAM) |
| `diag-controls` | 16K | 2 min | tests 2, 4 and 5 only: keyboard, joysticks, paddles |

`diag-controls` is a companion to Atari's SALT diagnostic disks: their
controller tests need a test harness plugged in, and this tape doesn't.

`diag-400-01-ram-part2` is the second part of the 400 RAM tape as a file of
its own. A machine with 8K never loads it (the screen says
`STAGE 2: 16K ONLY. NEXT: DIAG-400-02-ROM`); a bigger machine running the
400 set does. You only need it with a player that can't wait between the two parts
(see [AspeQt](#from-a-pc-usb-sio-interface-and-aspeqt)).

## Loading a tape

### Starting the machine for a cassette boot

1. Turn the Atari off.
2. **Take out any cartridge**, BASIC included. A cartridge covers 8K of RAM,
   so the RAM test can't reach it; the `FOUND:` line then says `CART IN`.
   An XL or XE's built-in BASIC doesn't matter: the tapes switch it off
   themselves.
3. Hold **START** and turn the Atari on, still holding START. It beeps once.
4. Start the tape, then press any key on the Atari.

When the tape has loaded, the border turns green and you hear a rising
chirp: the machine is running the test.

If a load fails (BOOT ERROR, or a crash before the green chirp), load it
again: turn the Atari off, rewind or reload the tape, and start over. A
load that works on the second try is fine; the tape is good. Only a load
that fails every time, at the same point, means something is wrong.

### On a MiSTer (Atari800 core)

Put the `.cas` files on the MiSTer's storage (for example in
`games/ATARI800/_diag`). Load the tape in the core's menu, then do the
cassette boot above.

### From a PC: USB-SIO interface and AspeQt

A USB-to-SIO interface (an "SIO2PC" cable; for example the SIO2PC-USB) plugs
into the Atari's SIO port (the one the disk drive and cassette recorder use)
and into a PC's USB port. On the PC it shows up as a COM port. The free
program [AspeQt](https://sourceforge.net/projects/aspeqt/) can then play a
`.cas` file into the Atari as if it came from a cassette recorder.

Setting up AspeQt (Tools > Options):
- **Serial port:** the COM port the interface uses (Windows Device Manager
  shows it).
- **Handshake:** the method your interface uses (its manual says which).
- **Cassette speed:** leave "Use custom baud rate for cassette emulation"
  off: the tapes are 600 baud, the normal speed.

AspeQt's manual recommends interfaces built on an FTDI USB chip, and says
the AtariMax "SIO2PC Universal Interface USB Edition" isn't supported.

To play a tape:
1. In AspeQt, choose **File > Playback cassette image** and pick the `.cas`
   file (or drag the file onto AspeQt). A dialog with instructions appears.
2. Do the cassette boot on the Atari (hold START, power on, wait for the
   beep).
3. Press a key on the Atari and confirm AspeQt's dialog at about the same
   time. The tape plays.

AspeQt can't rewind or pause a tape. On a machine with 16K or more,
`diag-400-01-ram` is a **two-part tape**: the first part runs its RAM test
for a few minutes before it asks for part two, and by then AspeQt has
played past it. The screen then says `STAGE 2: NOT ON TAPE` or
`STAGE 2: ERROR` and a number.
When that happens, play `diag-400-01-ram-part2.cas` and press START on the
Atari: it tries again. Every other tape is a single part and doesn't have
this problem.

### From a real cassette recorder

The `.cas` files can be turned into audio (a `.wav` file) with a CAS-to-WAV
converter, and the audio recorded onto a tape for an Atari 410 or 1010
recorder. This hasn't been tried with these tapes yet.

### From disk

Two of the tapes also come as Atari binary files (`.xex`), in the `disks`
folder. They load in seconds, not minutes:

| File | Same tests as | Needs |
|---|---|---|
| `diag-32k-xl-xe.xex` | the `diag-32k-xl-xe` tape: everything, with the menu | 32K |
| `diag-memtest.xex` | the `diag-memtest` tape | 16K |

To load one:

- **MiSTer:** load the `.xex` from the core's menu (its XEX loader). No
  cassette boot and no DOS disk needed.
- **A DOS disk** (Atari DOS 2.0S or 2.5, or MyDOS): copy the file onto it,
  boot DOS, and load it with the binary load option (`L` in the DOS 2
  menu).
- **A PC or FujiNet:** AspeQt, SIO2SD and FujiNet can boot an `.xex`
  straight from their own menus.

Take any cartridge out first, as for a tape. You don't need to hold OPTION:
the tests switch an XL or XE's BASIC off themselves. Everything on screen is
the same as on the tape, except the title bar: ` DIAG-32K-XEX ` and
` DIAG-MEMTEST-XEX `.

If the file can't run, it says so before it loads, with a red border and
the low tone on and off:

- `NEEDS 32K RAM. THIS MACHINE HAS 16K.`: too little RAM. Use the tapes
  for a smaller machine.
- `DOS IS IN THE WAY: USE DOS 2 OR MYDOS`: this DOS takes up the memory
  the file loads into (SpartaDOS does). Use Atari DOS 2.0S or 2.5, MyDOS,
  or the MiSTer's loader.

An 8K machine can't run a disk file at all; use the 400 tapes.

Once the file is running, DOS has been overwritten (the test checks that
RAM too). Pressing RESET then starts the machine again, as if switched on.

### From the cartridge

`diag-cart.car`, in the `carts` folder, holds all the tests. It is an
AtariMax 128K cartridge image (`.car` type 41):

- **MiSTer:** load it from the core's cartridge menu, then reset the
  machine.
- **A real Atari:** write it to an AtariMax 128K flash cartridge (its own
  flasher does this).

The tests run from the cartridge itself, not from RAM, so it works on any
Atari, an 8K 400 included, and on a machine whose RAM is too sick to load
a tape into. Switch on with the cartridge in:

1. The RAM test starts at once (green border and a chirp, then yellow
   while it tests), and ends on the RAM summary.
2. START goes to the menu: lines 0 to 8.

![Cartridge menu](img/cart-01-menu.png)

1. `0 RAM`: the RAM test again, with its result so far.
2. Tests 1 to 7.
3. All of them in order, and the results.
4. `8 LONG RAM TEST`: the long memory test, pass after pass until a key
   is pressed. It needs 16K (the line says so on a smaller machine).
5. The keys.

A cartridge switches off the 8K of RAM it sits over ($A000-$BFFF), which
is why a 48K machine with a BASIC cartridge shows 40K. This cartridge
switches itself off for a moment during the RAM test, tests that 8K too,
and switches back on, so the machine shows its real size (48K, or 64K on
an XL/XE) and a fault there is reported in bank 3.

**CTRL+S skips the RAM test.** Hold CTRL and S as you switch on (or while
the RAM test runs: it is looked at between banks) and the menu comes up at
once, with line 0 showing `SKIPPED`. The disk file `diag-32k-xl-xe` does
the same. The tapes don't: their wait is the load.

The long test, line 8, copies itself into RAM and switches the cartridge
off for good. After it, RESET starts the machine from cold without the
cartridge; to get back to the menu, switch off and on again.

In the ROM test the cartridge line shows `DIAG` and its CRC. An
XL/XE's built-in BASIC can't be read while a cartridge is plugged in; the
tape and disk versions check it.

## Reading the results

### The top of every screen

The bar along the top names **the tape** you loaded, then the test on
screen: for example `DIAG-16K-02-SYSTEM  2 KEYBOARD`. That's the tape's
name, not what it found out about your machine.

What the tape **found** is on the line below it: `FOUND:`, then the machine
type (400/800 or XL/XE), all the RAM it found (an 800XL shows 64K, a 130XE
128K), PAL or NTSC, and `CART IN` if a cartridge is plugged in. So the
32k+ tape on a 130XE shows `DIAG-32K-XL-XE` on top and
`FOUND: XL/XE  RAM 128K  NTSC` below. The same tape on an 800 shows
`FOUND: 400/800`.

### Colours

The border colour tells you what's happening, even when the picture is
unreadable or the screen is switched off:

| | Colour | RGB (MiSTer NTSC) | Meaning |
|---|---|---|---|
| ![](img/color-green.png) | green | `#009B58` | alive (just after loading); everything passed |
| ![](img/color-green-flash.png) | bright green flash | `#4CE5AB` | a pass beep: the jingle, then one long flash per RAM bank or test that passed |
| ![](img/color-yellow.png) | yellow | `#F0C55A` | testing. If it stays yellow and silent, the machine hung in that test. Memory test: an intermittent fault has been seen |
| ![](img/color-red.png) | red | `#891104` | a fault; the beep code follows |
| ![](img/color-red-flash.png) | bright red flash | `#D15D57` | a fault beep (see the beep code below) |
| ![](img/color-purple.png) | purple | `#AD3C9F` | waiting for you: a question to answer, or the video check's last chance |
| | black | `#000000` | the short gap between two flashes, and the moment after you answer a question |

**Red border with a low tone on and off, straight after loading, and
nothing else:** the machine has less RAM than this tape needs. That isn't a
fault: use the set for its RAM (see
[Which tapes](#which-tapes-for-which-machine)).

On the text screens the text is light grey (`#CBC3D0`) on black.

You never need colour to read a result: every colour comes with a sound,
and on a working screen with text as well.

### The beep code

Every flash comes with a beep, so you can read the code by eye or by ear.

| Sound | Flash | Meaning |
|---|---|---|
| rising three-note jingle | bright green | a pass |
| long beep (about 0.6 s, 440 Hz) | bright red | group A: **where**, counted. The RAM bank (1-4; the 130XE's extra banks are 5-8), or the test number |
| short beep (about 0.2 s, 880 Hz) | bright red | group B: **what**, counted. For RAM, the data bit, D0 = 1 up to D7 = 8; for a test, the item |
| low beep (about 0.6 s, 220 Hz) | bright red | the end of the list |

A fault plays as: long beeps (where), a pause, short beeps (what), and so
on for each bad bit or item, then the low end beep.

Only two things have a beep code: the RAM and the ROMs. They are what a
machine with no picture can still tell you about.

- **The RAM test** runs first, before anyone has said they can see the
  screen. Its result flashes the border with every beep, holds red for 3 s
  and plays again, over and over, until you press START. A pass repeats
  its long green flashes every 5 s.
- **Pressing START there** tells the program the picture can be read.
  From then on the border stays steady and nothing repeats.
- **The ROM test** (test 1) plays its code once: one long beep in a lower
  pitch than the RAM's (330 Hz), then one short beep (660 Hz) per failed
  item number, then the low beep. SELECT plays it again.
- **Every other test** only shows its result. A pass plays the jingle; a
  fail plays one low beep and waits for START with a red border.
- **The final result** plays a code only for ROM and RAM faults: for the
  RAM one long beep at the RAM's pitch (440 Hz), then one short beep per
  bad bank number.
- **OPTION** switches to full-screen flashes, and the flashing and
  repeating come back while the text is off.

Example: **long, long, pause, short ×5, low** = bank 2, bit D4.

A single long beep then the low beep, with no short beeps and no picture,
means the tape didn't load correctly into RAM (a bad image checksum): see
[When something fails](#when-something-fails).

Only the low beep, on and off with no long or short beeps, means this tape
needs more RAM than the machine has.

The test numbers are the same on every tape, disk file and the cartridge:
0 RAM, 1 ROMs, 2 keyboard, 3 console keys, 4 joysticks, 5 paddles, 6 POKEY,
7 GTIA. (Before version 0.5, 4 was POKEY, 5 joysticks, 6 paddles, and the
RAM was 8.)

### Keys during a result

| Key | Does |
|---|---|
| START, any key, or a joystick button | go on (between the beeps of a code too) |
| SELECT | play the beep code again |
| OPTION | switch between the text screen and full-screen flashes (the whole screen flashes with the code: easier to see when the picture is garbled) |

A test that passes moves on by itself after about 2 seconds, except the ROM
test, which waits so you can read the names and checksums. At the end of a
tape the results stay up until you press START:
- the 400 tapes 02-05 and `diag-controls`: START runs that tape's tests again
- the menu tapes (`diag-16k-02-system`, `diag-32k-xl-xe`): START goes back to
  the menu
- `diag-16k-01-ram`: START runs the whole RAM test again
- `diag-32k-xl-xe`'s RAM summary: START goes on to the system tests

After the opening video check, no question has a time limit: every question
waits until you answer it, with a purple border, and a test that asks about
a sound keeps playing it until you answer.

## The tapes, screen by screen

### RAM test (`-01-ram`, and the start of `diag-32k-xl-xe`)

There is no separate video check. The RAM result screen is the picture
check: its code keeps flashing and beeping until you press START, and
pressing START says you can see it.

**Testing.** Each 16K bank is tested in turn; the screen says which. On a
machine with a lot of RAM this takes a few minutes.

![RAM test running](img/ram-02-testing.png)

1. What the tape found.
2. The bank being tested now.

**Result** (the 400 tape; the 16k and 32k+ tapes go straight on to the
summary below).

![RAM test passed](img/ram-03-pass.png)

1. How to read the code.
2. One line per 16K bank: PASS, FAIL, or NOT FOUND (no RAM there).
3. The overall result.
4. The keys (see [Keys during a result](#keys-during-a-result)).

When a bank fails, its line shows the bad data bits:

![RAM test failed](img/ram-05-fail.png)

1. How to read the code.
2. The failed bank and its bad bits. On an 800XL each data bit is one RAM
   chip; see [When something fails](#when-something-fails).
3. The overall result. The border is red while the code plays: here
   long ×1 (bank 1), short ×5 (bit D4).

**Summary** (machines with 16K or more). Next the tape tests the RAM it
ran in itself (the "loader area"), then on an XL/XE the RAM under the
operating system and, on a 130XE, the four extra banks. Then it shows
everything. On the 400 tape the second part does this:

![RAM summary, 400 tape](img/ram-04-summary.png)

1. Low RAM and the display checks.
2. Every bank, and the area the tape itself ran in. On an XL/XE also the RAM
   under the OS, and on a 130XE the extra banks.
3. The number of failures and the next tape.

On `diag-16k-01-ram` it's all one load: the tape tests its own RAM page by
page, moving each page into the screen (the top rows show a jumble for a
moment), testing it and putting it back. The summary waits for you:

![RAM summary, 16K tape](img/16k-01-summary.png)

1. Low RAM and the display checks.
2. Every bank, and the area the tape itself ran in.
3. The number of failures and the next tape. A failure shows its first bad
   address and bits, with a hint (one bit: one RAM chip).
4. START runs the whole RAM test again.

### ROMs (`diag-400-02-rom`; test 1 on the system tapes)

The test reads every ROM chip and works out its CRC32 checksum, then looks
it up in a table of known Atari ROMs.

![ROMs on a 400/800](img/rom-01-400.png)

1. The 400/800's three OS chips, each named on its own, with its CRC32. A
   repaired board can have chips from different revisions; the test spots
   that (item 5).
2. A cartridge, if one is plugged in (here BASIC rev A, which is also why
   the `FOUND:` line says `CART IN` and only 40K of RAM). `NONE` is not a
   fault.
3. The character set's checksum.
4. The result. The ROM test waits here until you press a key, so you can
   read the names.

On an XL/XE the OS is one 16K chip, named as a whole:

![ROMs on an XL](img/rom-02-xl.png)

1. The OS. `UNKNOWN` (in inverse) means it matches no Atari ROM in the
   table: a patched, replacement, failing or badly seated chip.
2. BASIC, built into the XL/XE. A BASIC or cartridge the table doesn't know
   shows `NOT IN THE TABLE` and is not a fault.
3. The character set's checksum.
4. The result.

The names come from published tables of Atari's own ROMs (see
[DEVELOPMENT.md](DEVELOPMENT.md)), not from any one machine.

Items: 1 the OS reads differently twice; 2 BASIC or the cartridge reads
differently twice; 3 an unknown OS; 4 the character set reads differently
twice; 5 OS chips from different revisions.

### Keyboard and console keys (`diag-400-03-input`; tests 2 and 3)

**Keyboard.** Press every key. Each key on the map shows one of three
states, without needing colour, so this works on a black-and-white screen
too:

![Keyboard test](img/input-01-keyboard.png)

1. The key map. Not pressed yet: normal. Done: inverse. Held down now:
   inverse, blinking. The four arrow keys are CONTROL with `-` `=` `+`
   `*`, so those keys carry the arrows. CONTROL lights only together with
   another key: the Atari can't see CONTROL on its own.
2. The legend.
3. How many keys are left. HELP (XL/XE) and F1-F4 (1200XL) show but
   aren't required.

Press START when you're done. If keys are missing, the result screen shows
the pressed keys in inverse, so the missing ones stand out:

![Keyboard test failed](img/input-04-fail.png)

1. The map: inverse = pressed, normal = never pressed.
2. The legend for this screen.
3. Keys left.
4. The result and the failed items (item 1: a key was already held at the
   start, a stuck key; item 2: keys never pressed).
5. The keys.

**Console keys.** Press START, SELECT and OPTION. Then the console speaker
plays a tone over and over until you answer.

![Console keys](img/input-02-console.png)

1. What to do. If one of the three keys is dead, any keyboard key moves on
   (and that key is marked failed).
2. The keys seen so far, in inverse.
3. The question about the speaker, answered with Y or START (yes) or N or
   SELECT (no). The border is purple while it waits.

### Joysticks and paddles (`diag-400-04-ports`; tests 4 and 5)

**Joysticks.** Move each joystick and press its button. Each direction and
the button show inverse while active. START (or any key) ends the test.

![Joysticks](img/ports-01-joysticks.png)

1. One line per port: four on a 400/800, two on an XL/XE. Something
   already active at the start counts as stuck (item = port).

**Paddles.** First, unplug all paddles and press START: with nothing
plugged in, every paddle input must read 228 (SELECT skips this check).
Then plug the paddles back in and turn each one. START or any key ends the
test.

![Paddles](img/ports-02-paddles.png)

1. What to do. SELECT switches the fast scan on and off.
2. The column headings: the value now, the lowest and highest seen (a full
   turn reaches about 1 and 228), and the jitter.
3. One line per paddle, with a bar. Here nothing is plugged in, so every
   one reads 228. Jitter is how much the value wobbles with the knob
   still: a large jitter means a dirty or worn paddle. A `T` at the end
   means the paddle's button is pressed.

### Sound and video (`diag-400-05-av`; tests 6 and 7)

**POKEY.** The sound chip's timer and random-number generator are checked
automatically. Then each of its four voices plays a rising scale, eight
notes from C to C, one voice at a time, over and over until you answer
whether you heard it (items 3-6). A voice that plays some notes wrong
counts as not heard.
Last, voice 1 plays noise, a steady hiss (item 7): the noise comes from a
part of the chip the pure tones don't use.

![POKEY voices](img/av-01-pokey.png)

1. The automatic checks are done.
2. The voice playing now.
3. The question: Y or START = yes, N or SELECT = no.

**GTIA.** One screen: eight brightness steps, sixteen colours, and under
them the sprites: the word ATARI, made of the four players and the four
missiles, scrolling across in rainbow colours that move down the letters.
Answer whether it all looks right (item 1). Without a working screen the
test is skipped.

![GTIA](img/av-02-gtia.png)

1. PAL or NTSC, as the machine reports it.
2. Eight even steps from black to white.
3. Sixteen different colours.
4. ATARI, scrolling.
5. The question: does it look right?

### The menu (`diag-16k-02-system` and `diag-32k-xl-xe`)

On machines with 16K or more, all seven tests are on one tape, with a
menu.

![Menu](img/system-01-menu.png)

1. The tests, in order, with their state: `-` not run yet, PASS, or FAIL
   and the failed items.
2. `ALL OF THEM, IN ORDER`, highlighted when the menu first appears: one
   press of START runs everything.
3. The results and the final code.
4. The keys: START runs the highlighted line, SELECT moves down, OPTION
   moves up, and the number keys run that test. After a test the next one
   is highlighted, so pressing START again and again goes through them
   all.

Running a test again replaces its old result.

![Results](img/system-02-results.png)

1. Every test: PASS, FAIL and its items, or `-` if not run.
2. The ROMs (see [ROMs](#roms-diag-400-02-rom-test-1-on-the-system-tapes)).

### The 32k+ tape (`diag-32k-xl-xe`)

One tape, one load, for any machine with 32K or more:
1. The RAM test: everything above the program gets the full test.
2. The program's own RAM, page by page: each page is moved into the screen
   (the top rows show a jumble for a moment), tested, and put back.
3. On an XL/XE: the RAM under the OS and, on a 130XE, the four extra banks.
4. The RAM summary, which waits for you:

![32K RAM summary](img/32k-01-summary.png)

1. Low RAM and the display checks.
2. Every bank, the area the tape ran in, and here (an XL) the RAM under the
   OS as bank 4.
3. The result and what's next.
4. START goes on to the menu.

5. The seven tests, with the menu:

![32K menu](img/32k-02-menu.png)

1. `0 RAM`: the whole RAM test again from the start, with the RAM result
   so far beside it. Choose it with SELECT and START, or press 0. After
   the RAM summary, START brings you back to this menu, with the other
   tests cleared to `-`.
2. The tests.
3. All of them, in order.
4. The results.
5. The keys.

At the end, RAM faults show up again as test 0, with the bank as the item:

![32K results](img/32k-03-results.png)

1. Test 0: the RAM. FAIL with the bank numbers if any RAM failed; the code
   plays one long beep, then short × bank.
2. The seven tests.
3. The ROMs: here a real XL OS rev 2 and BASIC rev A.

During the ROM test the screen goes blank for about a third of a second:
the test is reading the XL/XE's self-test ROM, which sits where this tape
keeps its screen.

### Controls only (`diag-controls`)

The keyboard, joystick and paddle tests from above, on one tape for 16K
and up, with nothing else: no menu, no RAM or ROM test. They run in order,
and at the end START runs them again. Use it alongside Atari's SALT
diagnostic disks, whose controller tests need a test harness.

### Memory test (`diag-memtest`, `diag-400-memtest`)

The memory test (a burn-in) repeats the RAM tests until you press a key:
leave it running for an hour or a day to catch faults that only show when
the machine is warm. It keeps a clock, counts passes, and logs every bad
bit: in which pass it first failed, and in how many passes since. A bit
that failed every time is **solid**; one that only fails sometimes is
**intermittent**.

What each one covers:
- **`diag-memtest`** (16K or more): all the RAM. That's main RAM, the RAM
  under an XL/XE's OS, and a 130XE's extra RAM. The one exception is the
  last page under the OS, $FF00-$FFFF, which holds the memory test's own
  interrupt vectors while the OS is switched out. The RAM tapes test that
  page.
- **`diag-400-memtest`** (8K or more): main RAM only. On an XL/XE, use
  `diag-memtest` for the rest.

![Memory test running](img/memtest-01-running.png)

1. The pass number and how long it has run.
2. What it's testing now.
3. The log: bank (B1-B8; B9 is the memory test's own RAM, when it tests it
   page by page), bit, the first pass it failed in, and failed/passes.
4. Press a key (or START, SELECT, OPTION or a joystick button) to stop
   after the pass in progress.

The border shows the state so far: green no errors, red solid errors only,
yellow if anything intermittent has been seen.

![Memory test summary](img/memtest-02-summary.png)

1. Passes, time and the result.
2. The log.

The memory test also tests the RAM it runs in:
- **`diag-400-memtest`**, and **`diag-memtest` on 16K:** each page of its
  own code is moved aside, tested and put back, every pass. While that
  happens the top of the screen shows the page being worked on, as a
  jumble of characters.
- **`diag-memtest` on 32K and up:** it keeps two copies of itself that take
  turns, each testing the other's RAM. So the RAM it sits in gets the same
  full test as all the rest.

Every pass, both memory tests also test the screen's own RAM where you can see
it: an inverse bar runs down the screen, one row at a time. Each row is
inverted, held for two frames, checked, put back and checked again.

![The screen sweep](img/memtest-03-sweep.png)

1. The row being tested. A blank row shows as a row of arrows: that's what
   a space looks like with every bit flipped.

## When something fails

- **Note the code** (or the screen). Long beeps say where, short beeps say
  which bit or item.
- **RAM:** a bad bit in one bank usually means one RAM chip. On an 800XL
  each data bit (D0-D7) is one chip, across all of the 64K. On a 400/800
  each 16K board has its own chips, so the bank tells you which board. The
  same bad bit in every bank points at something shared: a data line, a
  socket, or a buffer chip.
- **Run the memory test** on a machine that passes but misbehaves, or after a
  repair. Intermittent faults often only show when the machine is warm.
- **Fall back to the 400 set** when a machine can't get through its own
  tapes. It only needs the first 8K of RAM. In particular:
  - no green chirp after loading: the RAM the tape loaded into is bad
  - one long beep then the low beep, with no picture: the tape didn't load
    into RAM correctly
  - a crash or a hang (the border stays yellow and silent) partway through
- **Red border and the low tone on and off, right after loading:** not a
  fault. The tape needs more RAM than the machine has; use a smaller set.
- **A tape that won't load at all**, or a BOOT ERROR, every time: first
  load it again (one failed load means nothing). If it fails every time,
  it points at the first part of RAM, or the cassette or SIO connection.

## Questions

### Why the different sets?

So that a tape never needs more RAM than the machine has, and bigger
machines load in fewer, longer steps. Tape is slow, so loading the fewest
bytes matters. The 400 set works on everything, which is why it's the
fallback. See [Why cassette, and why several sets](#why-cassette-and-why-several-sets).

### Why not a disk?

A disk needs a working drive and more of the machine before anything can
run. The cassette tapes are for the machines that can't manage that: an
8K 400, or a machine that fails to boot a disk. A disk version is planned,
for faster loading on machines that have a drive.

### Is this a substitute for the memory test?

No. The RAM tapes test every byte with strong patterns, but only once. A
fault that only shows when warm, or now and then, needs the memory test
running for a while.

### Does a pass prove the machine is good?

It proves what was tested: RAM, ROMs, the keyboard, the console keys, the
controller ports, and the sound and video chips as far as you could see
and hear them. The SIO port gets a workout just by loading the tape. It
doesn't test a disk drive, a printer, or the cartridge slot beyond naming
a cartridge that's plugged in.
