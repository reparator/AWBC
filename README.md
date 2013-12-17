AWBC
====

Automatic Wordclock Brightness Control

This is a brightness control for the ct-Wordclock. Surely there should be software implemented solutions either, but after all the microcontroller stuff you should not forget the "old" electronics.

The circuitry is quite simple. The light intensity of the environment is measured over a LDR (light dependant resistor) which is part of a voltage divider (see schematic Schaltplan.bmp).The resulting potential controles a BD441 transistor. This transistor dims the +5V Power to suitable values in the range of 2.5 to 4.8 V. The four 1N4148 diodes are limiting the minimal voltage drop if desired (can be shorted over two jumpers or switches).

Description:
============

Here the detailed description howto adapt the circuit to the ct-Wordclock strip:
First it is neccessary to cut some routes on the basis strip (+5V rail to the transistors) and rewire them partly to supply U1 and U2 again: 
You have to cut the +5V copper path at the points 1 and 2 at the top side (where the components are located) and at point 5 on the backside (the bottom side). This is to isolate the transistors Q1..Q12 from the input voltage.
You can use a fine drill, cutter or miller in your handdrill or a cutterknife with a small blade. But take care to cut only the desired lane!
At point 1 you have to remove at least 1 mm of the paint only on each side of the cut. Also remove the paint at point 3 and 4. DONT CUT THE BLUE MARKED POINTS, ONLY REMOVE THE PAINT TO GET A BARE SOLDER POINT! 
On the left side of the cut (point 1) you have to solder some wire to connect to the dimmer PCB (input pin) and to points 3 and 4 (This connects all blue marked points). Usefull for this is wirewrap wire. The right side of cut 1 will get connected to the output pin of the dimmer circuit. Last but not least you have to connect the PCB to ground, which can be found in the middle pin of PL8 of the main board. Solder a wire from there to the ground of the dimmer circuit. The LDR can be soldered directly to the dimmer PCB or assembled at the top the frame of the wordclock and connected with wires.
Take a look at the pictures and the detail view of the ct-wordclock schematic for further explanation. 

Jumper Settings:
================

With the two jumpers you can adjust the minimum of the dimm-function:

No jumper set:	
The LEDs are dimmed down to a voltage of app. 2.6 V (if no light meets the LDR). That meens the LEDS are switch off in fact. The total current consumption of the clock is app. 10 mA then. For me this is a good "off"-state of the clock. So the power-supply can remain connected.

Jumper 1 (half) set:
The dimm function is working to a lower limit of around 3.6 V. Even if it is completely dark in the room and no light meets the LDR, the clock-LEDs are visible. (Power consuption in my case around 15-20 mA for the hole board)

Jumper 2 (full) set:
The dimm function is deactivated, input and output of dimmer PCB are shortet. The LEDs glow at maximum brightness. The power consumption of the hole board is app. 60 mA.     

I used switches instead of jumpers. So it is easy to change the dimm state without removing the clock from the wall it is mounted to.

Bill of materials:
==================

1x 	Transistor BD140,
1x 	LDR, 
1x	Resistor 10K, 
1x 	Resistor 56K, 
4x	diode 1N4148, 
  	pinheads and jumpers, 
2x	toggle switch (optional).


IMPORTANT
=========
This information is presented as it is without any warranty. The described modifications worked fine with me but if you are not familiar with the described techniques (e.g. cutting wire routes and soldering) they could result in total damage of your board. Use this description at your own risk!

17.12.2013
reparator
