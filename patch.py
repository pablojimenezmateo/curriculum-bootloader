#!/usr/bin/env python3
'''
This utility merges my CV with the bootloader,
this way makes it work in Adobe Reader as well
as in all the rest I have tested.
'''
import os
import sys

if not os.path.isfile('boot.bin'):

	print("boot.bin does not exist, please follow the instructions to create it.")
	sys.exit(-1)

if not os.path.isfile('uncompressed.pdf'):

	print("uncompressed.pdf does not exist, please follow the instructions to create it.")
	sys.exit(-1)



with open("boot.bin", "rb") as binaryfile :
    bootloader  = bytearray(binaryfile.read())

#Delete the manual padding I added for the PDF magic numbers
#please refer to boot.asm for more information
bootloader_magic = bytearray(b'\xEB\x44\x25\x50\x44\x46\x2D\x31\x2E\x35') #Bootloader + PDF magic numbers
bootloader_start = bootloader[2:62]
bootloader_end   = bootloader[70:]
bootloader = bootloader_magic + bootloader_start + bootloader_end

binaryfile.close()

#Open PDF
with open("uncompressed.pdf", "rb") as binaryfile:
    cv = bytearray(binaryfile.read())

cv = cv[8:] #Remove the magic numbers
cv = bootloader + cv #Append bootloader

binaryfile.close()

with open("cv.pdf", "wb") as binaryfile:
    binaryfile.write(cv)

binaryfile.close()