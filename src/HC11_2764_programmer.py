import getopt
import sys
import time

import serial


def load_program(comport, s19file, loopback=False):
    print(f"Program will use {comport}")
    print(f"Parsing {s19file}...")

    # --------------------------------------------------------------------------
    # This part more or less unmodified from original HC11_BL.py...
    # --------------------------------------------------------------------------
    ser = serial.Serial(port=comport, baudrate=1200, timeout=6.5)
    machine_code = bytearray(256)  # Already initialized to 0

    f = open(s19file)
    line = f.readline()
    j = 0
    while line:
        if line[0:2] == "S1":
            bcount = int(line[2:4], 16)
            dcount = bcount - 3
            i = 0
            j = int(line[4:8], 16)
            k = 0
            #            print (line)
            print("@", hex(j), end=":")
            while k < (dcount):
                machine_code[j] = int(line[i + 8 : i + 10], 16)
                byte = hex(machine_code[j])[-2:]
                if byte[0] == "x":
                    byte = "0" + byte[-1:]
                print(byte, end=" ")
                i += 2
                j += 1
                k += 1
        line = f.readline()
        print()
    f.close()

    print("Input S19 file parsed. ", end=" ")
    ser.write(b"\x00")
    print("Press the RESET button of the HC11 board now.")
    input("Program is paused - press Enter on keyboard after HC11 RESET.")
    time.sleep(1.0)
    print("Serial coms to HC11: Sending 0xFF and the rest of the code... ")
    ser.write(b"\xff")
    ser.write(machine_code)
    print()

    # Read back what the HC11 (should have) sent back, which is an echo of what it received:
    print(
        "Waiting for echoback from HC11.  If you don't see anthing on screen, something is wrong..."
    )

    byte = ser.read()
    if not byte:
        print("HC11 is not sending anything back - aborting.")
    else:
        if loopback:
            print("Sync:", hex(ord(byte)))
            j = 256
        else:
            print(hex(ord(byte)), end=" ")
            j = 255

        while j >= 0:
            byte = ser.read()
            if byte:
                print(hex(ord(byte)), end=" ")
                j -= 1
            else:
                print("Error in received data - aborting.")
                j = 0
        print("\n\n")
        print("Done - HC11 should be running your machine code in RAM now.")

    # WARNING: This doesn't close the serial port, just passes it back!
    return ser


def blank_check(comport, loopback=False):
    """Performs a blank check of the EPROM."""

    print("-------------------------------------------------------")
    print(" EPROM blank check")
    print("-------------------------------------------------------\n")
    print("The program will now verify that the first 25 bytes of the EPROM are 0xFF.")
    input("Press ENTER to continue...")

    ser = load_program(comport, "read.s19", loopback)

    print("Reading first 25 bytes from the EPROM...")

    # Print 25 bytes
    for i in range(25):
        byte = ser.read()
        if byte:
            print(f"[{i}] {hex(ord(byte))}")
            if ord(byte) != 0xFF:
                print("EPROM is not blank - aborting.")
                quit()  # Terminate the whole program
        else:
            print("Error in received data - aborting.")
            break

    ser.close()


def program(comport, loopback=False):
    """Writes 25 bytes to the EPROM."""

    print("-------------------------------------------------------")
    print(" Writing 25 bytes to the EPROM")
    print("-------------------------------------------------------\n")
    print("The program will now write 25 bytes to the EPROM.")
    print("Afterwards, it will display all of the written bytes.")
    print("Ensure that the correct data is stored in program.s19.")
    input("Press ENTER to continue...")

    ser = load_program(comport, "program.asm", loopback)

    print("Reading first 25 bytes from the EPROM...")

    print("Starting here, program will be reading everything that the HC11 sends back.")
    print("(THIS IS JUST FOR TESTING!)")

    time.sleep(1.0)  # Sleep for some time to let the 68HC11 do its thing

    # Print 25 bytes
    for i in range(25):
        byte = ser.read()
        if byte:
            print(f"[{i}] {hex(ord(byte))}")
        else:
            print("Error in received data - aborting.")
            break

    ser.close()


def main(argv):
    print("-------------------------------------------------------")
    print(" CEMICRO Final Project")
    print(" M2764A EPROM Programmer\n")
    print(" Based on HC11 Bootload Mode RAM Loader, v0.2 Clem Ong")
    print("-------------------------------------------------------\n")

    comport = ""
    loopback = False

    # Args
    try:
        opts, arg = getopt.getopt(argv, "hlc:", ["port"])
    except getopt.GetoptError:
        print("HC11_bootload -c <COM_port>")
        sys.exit(2)
    for opt, arg in opts:
        if opt == "-h":
            print("HC11_bootload -c <COM_port>")
            sys.exit()
        elif opt == "-l":
            loopback = True
        elif opt in ("-c", "--port"):
            comport = arg

    blank_check(comport, loopback)
    program(comport, loopback)
