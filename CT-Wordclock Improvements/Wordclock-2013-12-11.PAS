program wordclock;
// Wordclock-Version für c't Wordclock-Platine (Segor-Bausatz)
// Q&D Version basiert auf WordClock für PONG, aber verbesserte Buchstaben-Kodierung
// C. Meyer 7/2013
// Kommentare und kleine Änderungen: reparator 12/2013

{$NOSHADOW}
{ $WG}                     {global Warnings off}

Device = mega8, VCC=5;
{ $BOOTRST $00C00}         {Reset Jump to $00C00}

Define_Fuses
//  Override_Fuses;
  NoteBook   = A;
  COMport    = USB;
  LockBits0 = [];
  FuseBits0  = [CKSEL0, CKSEL1, CKSEL3, SUT0, BODEN];
  FuseBits1  = [];
  ProgMode   = SPI;
  ProgFuses  = true;
  ProgLock   = false;
  ProgFlash  = true;
  ProgEEprom = false;

Import SysTick, TWImaster, RTClock, TickTimer;
// Import DCFclock;

From System Import LongWord, Random;


Define
  ProcClock      = 8000000;       {Hertz}
  SysTick        = 10;             {msec}
  StackSize      = $0032, iData;
  FrameSize      = $0032, iData;
//  DCFclock       = iData;
//  DCFport        = PinB, 2, positive; {Port, Pin#, Polarity}
  TWIpresc       = TWI_BR100;
  TickTimer      = Timer1;
  RTClock        = iData, Time;
  RTCsource      = SysTick;
  
Implementation

{$IDATA}

{--------------------------------------------------------------}
{ Type Declarations }

type


{--------------------------------------------------------------}
{ Const Declarations }
const
  sr_on: Boolean = false;
  sr_off: Boolean = true;
  rtc_adr: byte = $68;              //RTC-Adresse %01101000 (siehe Datenblatt Dallas DS1307)

// Buchstaben-Pattern, 12 Bit wie angezeigt, plus Zeile im obersten Nibble
  c_es_war: word   = $0000 or %110111000000;        //ES WAR              1
  c_es_ist: word   = $0000 or %110000111000;        //ES IST              1
  c_gleich: word   = $1000 or %111111000000;        //GLEICH              2
  c_genau: word    = $1000 or %000000011111;        //GENAU               2
  c_gerade: word   = $2000 or %111111000000;        //GERADE              3
  c_fuenfmin: word = $2000 or %000000011110;        //FÜNF (Min)          3
  c_viertel: word  = $3000 or %000011111110;        //VIERTEL             4
  c_dreiviertel: word  = $3000 or %111111111110;    //DREIVIERTEL         4
  c_dreimin: word  = $3000 or %111100000000;        //DREI (Min)          4
  C_viermin: word  = $3000 or %000011110000;        //VIER (Min)          4
  c_zehnmin: word  = $4000 or %111100000000;        //ZEHN (Min)          5
  c_zwanzig: word  = $4000 or %000001111111;        //ZWANZIG (Min)       5
  c_nach: word     = $5000 or %111100000000;        //NACH                6
  c_vor: word      = $5000 or %000011100000;        //VOR                 6
  c_halb: word     = $5000 or %000000001111;        //HALB                6
  c_drei: word     = $6000 or %111100000000;        //DREI                7
  c_ein: word      = $6000 or %001110000000;        //EIN                 7
  c_eins: word     = $6000 or %001111000000;        //EINS                7
  c_sieben: word   = $6000 or %000001111110;        //SIEBEN              7
  c_elf: word      = $7000 or %111000000000;        //ELF                 8
  c_fuenf: word    = $7000 or %001111000000;        //FÜNF                8
  c_zwoelf: word   = $7000 or %000000011111;        //ZWÖLF               8
  c_vier: word     = $8000 or %111100000000;        //VIER                9
  c_zwei: word     = $8000 or %000011110000;        //ZWEI                9
  c_acht: word     = $8000 or %000000001111;        //ACHT                9
  c_neun: word     = $9000 or %011110000000;        //NEUN                10
  c_sechs: word    = $9000 or %000000111110;        //SECHS               10
  c_zehn: word     = $A000 or %111100000000;        //ZEHN                11
  c_uhr: word      = $A000 or %000001110000;        //UHR                 11
  c_vor12: word    = $A000 or %000000000111;        //VOR (mittag)        11
  c_nach12: word   = $B000 or %111100000000;        //NACH (mittag)       12
  c_nachts: word   = $B000 or %111111000000;        //NACHTS              12
  c_mittag: word   = $B000 or %000000111111;        //MITTAG              12

{--------------------------------------------------------------}
{ Var Declarations }
var
{$PDATA}
  SR_CLK[@PortB,5]: Bit;              //PB5_SCK
  SR_DATA[@PortB,3]: Bit;             //PB3_MOSI
  HOURBTN[@PinB,1]: Bit;              //Hour-Button: PB1
  MINUTEBTN[@PinB,0]: Bit;            //Min-Button: PB0

  TESTPIN[@PortB,4]: Bit;


{$DATA}
  b, i, led_row, tenmillisec: byte;
  LED_word: word;

{$IDATA}
  TickSema, Blinkenlights,
  SecondSema, MinuteSema, LEDupdateRequest: Boolean;


  LED_word_array: Array[0..11] of word;
// Einzel-Zeilen, evt. einmal gebraucht
  LED_word_line0[@LED_word_array+0]: word;
  LED_word_line1[@LED_word_array+24]: word;
  LED_word_line2[@LED_word_array+48]: word;
  LED_word_line3[@LED_word_array+72]: word;
  LED_word_line4[@LED_word_array+96]: word;
  LED_word_line5[@LED_word_array+120]: word;
  LED_word_line6[@LED_word_array+144]: word;
  LED_word_line7[@LED_word_array+168]: word;
  LED_word_line8[@LED_word_array+192]: word;
  LED_word_line9[@LED_word_array+216]: word;
  LED_word_line10[@LED_word_array+240]: word;
  LED_word_line11[@LED_word_array+264]: word;

  UpdateTimer: SysTimer8;
  BlinkTimer, LED_select,
  hour, minute: Byte;

{--------------------------------------------------------------}
{ functions }

procedure onTickTimer;     //Wird bei jedem Timerdurchlauf aufgerufen
begin
  TickSema:= true;
end;

procedure RTCtickMinute;   //Wird bei jedem Minuten Übertrag aufgerufen
begin
  MinuteSema:= true;
end;

procedure RTCtickSecond;   //Wird bei jedem Sekunden Übertrag aufgerufen
begin
  SecondSema:= true;
end;

function DS1307getSecond: byte;     //Sekunden aus RTC holen
var my_byte: byte;
begin
  TWIout(rtc_adr,0);                // Sekunden-Register ansprechen
  TWIinp(rtc_adr,my_byte);          // ... und auslesen
  return(BCDtoByte(my_byte));       // BCD Wert in Byte konvertieren und zurückliefern
end;

function DS1307getMinute: byte;    //Minuten aus RTC holen
var my_byte: byte;
begin
  TWIout(rtc_adr,1);               // Minuten-Register ansprechen
  TWIinp(rtc_adr,my_byte);         // ... und auslesen
  return(BCDtoByte(my_byte));      // BCD Wert in Byte konvertieren und zurückliefern
end;

function DS1307getHour: byte;      // Stunden aus RTC holen
var my_byte: byte;
begin
  TWIout(rtc_adr,2);               // Stunden-Register ansprechen
  TWIinp(rtc_adr,my_byte);         // ... und auslesen
  return(BCDtoByte(my_byte and $3F)); // BCD Wert in Byte konvertieren und zurückliefern:
                                      //WARUM NUR DIE UNTEREN 6 BIT ($3F = %00111111)???
end;

procedure DS1307setSecond(my_second: byte);   // Sekunden in RTC schreiben
var my_byte: byte;
begin
  my_Byte:= ByteToBCD(my_second) and $7F;     // %01111111 Clock HALT Bit (Bit7) immer löschen
  TWIout(rtc_adr,0,my_Byte);                  // Sekunden-Register
end;

procedure DS1307setMinute(my_minute: byte);   // Minuten in RTC schreiben
var my_byte: byte;
begin
  my_Byte:= ByteToBCD(my_Minute);             // Minuten anch BCD konvertieren
  TWIout(rtc_adr,1,my_Byte);                  // Minuten-Register
end;

procedure DS1307setHour(my_hour: byte);       // Stunden in RTC schreiben
var my_byte: byte;
begin
  my_Byte:= ByteToBCD(my_hour and 31);        //%00011111  ?????????????????   HIER WAR EIN BUG IM ORIGINALFILE!
  TWIout(rtc_adr,2,my_Byte);                  // Stunden-Register
end;

//##############################################################################

procedure InitPorts;        //Ports und Pullups konfigurieren
begin
  PortB:= %00000111;        //PB0..PB2 Pullup eingeschaltet
  DDRB:=  %00111000;        //Bit 0..2 Input, Bit 3..5 Output Bit 6..7 Input
                            //0..1     Taster
                            //2        DCF
                            //3,4,5    ISP
                            //6,7      Takteingang
  
  PortC:= %00000000;        //PB0..PB6 Pullups off
  DDRC:=  %00001111;        //Bit 0..3 Output, 4..6 Input
                            //0..3     LEDS Spalte links
                            //4..5     I2C zur RTC
                            //6        /RESET

  PortD:= %00000000;        //PB0..PB7 Pullupts off
  DDRD:=  %11111111;        //Bit0..7  Output
                            //0..5     LEDS Spalte rechts
                            //6..7     LEDS Spalte links
end InitPorts;

procedure LED_out;
begin
   PortC:=hi(LED_word) and $0F;  //Höherwertiges Byte von LED_word and %00001111
   PortD:=lo(LED_word);          //Niederwertiges Byte von LED_word
end;

procedure LED_off;
begin
   PortC:=(PortC and $F0);       //$F0 = %11110000
   PortD:=0;
end;


procedure LED_SR_next;
begin
  LED_off;
  if not inctolim(led_row, 11) then
    led_row:= 0;
    SR_DATA:= sr_on;
    SR_CLK:= true;
    nop; nop; nop;
    SR_CLK:= false;
    SR_DATA:= sr_off;
    LED_word:= LED_word_array[0];
  else
    SR_CLK:= true;
    nop; nop; nop;
    SR_CLK:= false;
  endif;
  LED_word:= LED_word_array[led_row];
  LED_out;
end;

//##############################################################################

//#####################  Pattern aus LED_word_array ausgeben   #################

procedure ptn2led(my_pattern: word);
var my_idx: byte;
begin
  my_idx:= hi(my_pattern) shr 4;    // Zeilennummer im obersten Nibble
  LED_word_array[my_idx]:= LED_word_array[my_idx] or my_pattern;
end;

//#####################  Zeit in Buchstaben konvertieren   #####################

procedure time_to_letters(my_hour, my_minute: byte; my_adjust: boolean);
var my_div, my_mod, my_addhour: byte; my_disp_uhr: Boolean;
begin
  for i:= 0 to 11 do
    LED_word_array[i]:= 0;
  endfor;

  my_disp_uhr:= false;                   // UHR?
  my_mod:= my_minute mod 5;             // Minute words
  my_addhour:= 0;
  my_div:= my_minute div 5;             //Minuten in Fünferschritten

  case my_mod of                        // Einzel-Minuten
    0:                                  // Es ist genau
        ptn2led(c_es_ist);
        ptn2led(c_genau);
        |
    1,2:                                // Es war gerade
        ptn2led(c_es_war);
        ptn2led(c_gerade);
        |
    3,4:                               // Es ist gleich
        ptn2led(c_es_ist);
        ptn2led(c_gleich);
        inc(my_div);
        if my_minute > 57 then
          my_addhour:= 1;
        endif;
        |
  endcase;

  case my_div of                                // 5-Minuten-Schritte
    0,12:                                       // bei voller Stunde: Uhr
        my_disp_uhr:= true;
        |
    1:
        ptn2led(c_fuenfmin);                    // Fünf nach
        ptn2led(c_nach);
        |
    2:
        ptn2led(c_zehnmin);                     // Zehn nach
        ptn2led(c_nach);
        |
    3:
        ptn2led(c_viertel);                     // Viertel nach
        ptn2led(c_nach);
        |
    4:
        ptn2led(c_zwanzig);                     // Zwanzig nach
        ptn2led(c_nach);
        |
    5:
        ptn2led(c_fuenfmin);                    // Fünf vor halb
        ptn2led(c_vor);
        ptn2led(c_halb);
        my_addhour:= 1;
        |
    6:
        ptn2led(c_halb);                        // Halb
        my_addhour:= 1;
        |
    7:
        ptn2led(c_fuenfmin);                    // Fünf nach halb
        ptn2led(c_nach);
        ptn2led(c_halb);
        my_addhour:= 1;
        |
    8:
        ptn2led(c_zwanzig);                     // Zwanzig vor
        ptn2led(c_vor);
        my_addhour:= 1;
        |
    9:
        ptn2led(c_viertel);                     // Viertel vor
        ptn2led(C_vor);
        my_addhour:= 1;
        |
    10:
        ptn2led(c_zehnmin);                     // Zehn vor
        ptn2led(c_vor);
        my_addhour:= 1;
        |
    11:
        ptn2led(c_fuenfmin);                    // Fünf vor
        ptn2led(c_vor);
        my_addhour:= 1;
        |
  endcase;
  my_hour:= my_hour + my_addhour;

  case my_hour of                               // Stunden-Schritte
    0,12,24:                                    // Zwölf    HIER WAR EIN BUG IM ORIGINALFILE
      ptn2led(c_zwoelf);
      |
    1,13:                                       // Ein
      if my_disp_uhr then
        // Sonderfall ein"s"
        ptn2led(c_ein);
      else
        ptn2led(c_eins);
      endif;
      |
    2,14:                                       // Zwei
      ptn2led(c_zwei);
      |
    3,15:
      ptn2led(c_drei);                          // Drei
      |
    4,16:
      ptn2led(c_vier);                          // Vier
      |
    5,17:
      ptn2led(c_fuenf);                         // Fünf
      |
    6,18:
      ptn2led(c_sechs);                         // Sechs
      |
    7,19:
      ptn2led(c_sieben);                        // Sieben
      |
    8,20:
      ptn2led(c_acht);                          // Acht
      |
    9,21:
      ptn2led(c_neun);                          // Neun
      |
    10,22:
      ptn2led(c_zehn);                          // Zehn
      |
    11,23:
      ptn2led(c_elf);                           // Elf
      |
  endcase;

  if my_disp_uhr then
    ptn2led(c_uhr);                             // Uhr
  endif;
  case my_hour of                               //Tageszeit
     0,1,2,3,4:                                 // Nachts
       ptn2led(c_nachts);
       |
     5,6,7,8,9:                                 // nichts
       nop;
       |
     10,11:                                     // Vor Mittag
       ptn2led(c_vor12);
       ptn2led(c_mittag);
       |
     12,13:                                     // Mittag
       ptn2led(c_mittag);
       |
     14,15,16,17:                               // Nachmittag
       ptn2led(c_nach12);
       ptn2led(c_mittag);
       |
     18,19,20,21,22,23,24:                      // nichts
       nop;
       |
  endcase;
  
end;

{--------------------------------------------------------------}
{ Main Program }
{$IDATA}

begin
  InitPorts;
  TickTimerTime(1000);  // Wert in us      //Stoppt den Timer und setzt das Timing neu
  TickTimerStart;                          //Startet den Timer
  Blinkenlights:= true;                    // Am Anfang zunächst Blinklichter
  BlinkTimer:= 20;                         // mit Frequenz 20
  
  EnableInts;                              //Gibt den globalen Interrupt frei
  MinuteSema:= true;
  i:= DS1307getSecond;  // First Power up, Clock HALT Bit löschen
  DS1307setSecond(i);

   loop
    if TickSema then                        //Systemtick hat sich geändert
      TickSema:=false;
      TESTPIN:= not TESTPIN;                //Testpin togglen im Systemtick-takt
      LED_SR_next;
    endif;

    if MinuteSema then                     //Minuten haben sich geändert
      //Blinkenlights:= true;              //Blinkgewitter nach jeder Minutenänderung
      BlinkTimer:= 10;
      MinuteSema:= false;
      minute:= DS1307getMinute;            //Minuten aus RTC holen
      hour:= DS1307getHour;                //Stunden aus RTC holen
      time_to_letters(hour, minute,false); //Uhrzeit in LED-Matrix umwandeln
      LEDupdateRequest:= true;
    endif;
    
    if SecondSema then                     //Sekunden haben sich geändert - Buttons abfragen (sekündlich)
      SecondSema:= false;
      if not HOURBTN then                  // neg. Logik! Taste HOUR gedrückt?
        inctolimwrap(hour,23,0);           //Inkrementiert "hour" um 1, wenn >23 dann 0
        DS1307setHour(hour);               // Stunde in RTC
        DS1307setSecond(0);                // Sekunden auf 0 setzen
        RTCsetHour(hour);                  // ATMEGA Stundenregister setzen
        RTCsetSecond(0);                   // ATMEGA Sekundenregister setzen
        time_to_letters(hour, minute, true);  //Uhrzeit in LED-Matrix umwandeln
        LEDupdateRequest:= true;
        Blinkenlights:= false;
      endif;
      if not MINUTEBTN then                 // neg. Logik!  Taste MINUTE gedrückt?
        if inctolimwrap(minute,59,0) then   //Inkrementiert "minute" um 1, wenn >59 dann 0
          inctolimwrap(hour,23,0);          //Inkrementiert "hour" um 1, wenn >23 dann 0
        endif;
        DS1307setHour(hour);                // Stunde in RTC
        DS1307setMinute(minute);            // Minute in RTC
        DS1307setSecond(0);                 // Sekunden auf 0 setzen
        RTCsetMinute(minute);               // ATMEGA Minutenregister setzen
        RTCsetSecond(0);                    // ATMEGA Sekundenregister setzen
        time_to_letters(hour, minute, true);  //Uhrzeit in LED-Matrix umwandeln
        LEDupdateRequest:= true;
        Blinkenlights:= false;
      endif;
    endif;
    
    if Blinkenlights then                  //Wildes Geblinke am Anfang
      if isSysTimerZero(UpdateTimer) and Blinkenlights then
        setSysTimer(UpdateTimer, lo(randomrange(5,15)));
        for i:= 0 to 11 do
          LED_word_array[i]:= (LED_word_array[i] + random) and $FFF;
        endfor;
        if not dectolim(BlinkTimer, 0) then
          Blinkenlights:= false;
          time_to_letters(hour, minute,false);
        endif;
      endif;
    endif;

  endloop;
end wordclock.

