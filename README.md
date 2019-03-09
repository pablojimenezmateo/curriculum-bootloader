My curriculum is also a bootloader
====================================

![ScreenShot](https://raw.githubusercontent.com/pjimenezmateo/curriculum-bootloader/master/Screenshot.png)

What?
------------

The PDF attached in this repository is both a working PDF of my CV and a custom bootloader created by me to impress technical recruiters.

How?
------------

I wrote a tiny bootloader of 1018 bytes, which is the perfect size since the PDF header has to be in the first 1024 bytes. Then I just copy the first bytes of my bootloader at the beginning of my CV and that is it, a working PDF and bootloader.

Can I try it?
------------

Sure! You can do so by two means, in real hardware (I spend a lot of time making it compatible) or in an emulated environment.

#### Real hardware

**NOTE:** Please be very careful with this command. If you select the wrong drive **you will lose data**.

Get a USB, check the device name and do:
```bash
sudo dd if=cv.pdf of=/dev/sdX bs=512 count=2880
```

where X is your device.

#### Emulated environment

You can use qemu:
```bash
qemu-system-i386 -drive format=raw,file=cv.pdf
```

Or bochs:

Create a bochsrc.txt file with this contents:
```text
megs: 32
romimage: file=/usr/share/bochs/BIOS-bochs-latest, address=0xfffe0000
vgaromimage: file=/usr/share/bochs/VGABIOS-lgpl-latest
floppya: 1_44=cv.pdf, status=inserted
boot: a
log: bochsout.txt
mouse: enabled=0
display_library: x, options="gui_debug"
```

And then execute bochs as follows:

```bash
bochs -f bochsrc.txt
```

Compiling from source
------------

```bash
nasm boot.asm -o boot.bin
```

Get your vanilla PDF, CV_english.pdf in this example, and do:
```bash
qpdf --stream-data=uncompress CV_english.pdf uncompressed.pdf
cat boot.bin uncompressed.pdf > cv.pdf
```

FAQ
------------

* But why?

    As a learning experience. I realized that I had no practical knowledge on how the booting process works, and also my assembly was a little bit rusty. This is a project I really enjoyed, although it was a little bit overwhelming at some points.

* Can you explain how?

    I have tried my best to comment the code thoroughly, including my optimization decisions as well as the encoding of the sprites. I have also linked to a couple of Stackoverflow answers for deeper understanding.

* But now your PDF is bigger!

    Yes, but 1018 bytes bigger or 0.01% bigger. For comparison, the image in this readme is 15016 bytes or 14.75 times bigger. The Firefox icon is 8532 bytes, 8.38 times bigger!



This program is licensed under Creative commons Attribution 3.0 Unported, more info : 
http://creativecommons.org/licenses/by/3.0/deed.en_US
