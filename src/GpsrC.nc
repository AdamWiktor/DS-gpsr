#include <AM.h>
#include "Timer.h"
#include "Const.h"

module GpsrC {
  uses {
    interface Timer<TMilli>;
    interface Boot;
    interface ReadRecipient;
    interface Read<uint16_t> as ReadReading;
    interface Transmitter;
  }
}
implementation {
  txt_readings_t data;
  bool saved_recipient = FALSE;
  bool saved_value = FALSE;

  event void Boot.booted() {
    call Timer.startPeriodic(READINGS_TIME);
    dbg("gpsr", "Gpsr booted\n");
  }

  event void Timer.fired() {
    dbg("gpsr", "Collecting data...\n");
    saved_value = FALSE;
    saved_recipient = FALSE;
    call ReadRecipient.read();
    call ReadReading.read();
  }

  void send() {
    data.mote_id = TOS_NODE_ID;
    data.resender = TOS_NODE_ID;
    data.is_peri = FALSE;
    dbg("gpsr", "Sending data %d to x=%d y=%d\n", data.value, data.dest_x, data.dest_y);
    call Transmitter.sendReading(data);
    saved_value = FALSE;
    saved_recipient = FALSE;
  }

  event void ReadRecipient.readDone(error_t result, uint16_t moteId, uint32_t longitude, uint32_t latitude) {
      data.dest_x = longitude;
      data.dest_y = latitude;
      dbg("gpsr", "Recipient collected\n");
      saved_recipient = TRUE;
      if (saved_value)
        send();
  }

  event void ReadReading.readDone(error_t result, uint16_t value) {
    data.value = value;
    dbg("gpsr", "Value collected\n");
    saved_value = TRUE;
    if (saved_recipient)
      send();
  }
}
