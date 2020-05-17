#include <AM.h>
#include "Const.h"

enum radio_status_t {
  AVAILABLE,
  SENDING_READINGS,
  SENDING_LOCATION
};

module TransmitterP {

  provides interface Transmitter;

  uses {
    interface Boot;
    interface AMSend as SendReadings;
    interface PacketAcknowledgements as Acks;
    interface Receive as ReceiveReadings;
    interface SaveReading;
    interface Timer<TMilli>;
    interface MsgQueue;
    interface Neighbors;
  }
}
implementation {

  enum radio_status_t current_radio_status = AVAILABLE;
  bool send_location = FALSE;
  message_t msg;

  task void send_readings_task();

  void sending_location_failure(char *cause) {
    dbg("transmitter", "%s", cause);
    send_location = FALSE;
    current_radio_status = AVAILABLE;
    post send_readings_task();
  }

  void start_sending_location(loc_broadcast_t *my_location) {
    error_t status;
    loc_broadcast_t *loc;
    status = call Acks.noAck(&msg);
    if (status != SUCCESS) {
      sending_location_failure("Failed to disable acks\n");
      return;
    }
    loc = (loc_broadcast_t*) call SendReadings.getPayload(&msg, sizeof(loc_broadcast_t));
    if (loc == NULL) {
      sending_location_failure("Cannot send empty message\n");
      return;
    }

    *loc = *my_location;
    status = call SendReadings.send(TOS_BCAST_ADDR, &msg, sizeof(loc_broadcast_t));
    if (status != SUCCESS) {
      sending_location_failure("Failed to send location broadcast\n");
    } else {
      dbg("transmitter", "Sending location broadcast...\n");
    }
  }

  task void send_location_task() {
    loc_broadcast_t *my_location;
    if (!send_location) {
      if (call MsgQueue.has_readings_to_send())
        post send_readings_task();
      return;
    }
    atomic {
      if (current_radio_status != AVAILABLE) {
        dbg("transmitter", "Radio not available, queuing location broadcast...\n");
        return;
      }
      current_radio_status = SENDING_LOCATION;
    }
    my_location = call Neighbors.give_broadcast_msg();
    if (my_location == NULL) {
      dbg("transmitter", "Cannot get location broadcast message\n");
      send_location = FALSE;
      current_radio_status = AVAILABLE;
      if (call MsgQueue.has_readings_to_send())
        post send_readings_task();
    } else {
      start_sending_location(my_location);
    }
  }

  event void Boot.booted() {
    send_location = TRUE;
    post send_readings_task();
    call Timer.startPeriodic(BROADCAST_TIME);
    dbg("transmitter", "Transmitter booted\n");
  }

  event void Timer.fired() {
    send_location = TRUE;
    post send_location_task();
  }

  void sending_readings_failure(char *cause) {
    dbg("transmitter", "%s", cause);
    call MsgQueue.move_message_to_end();
    current_radio_status = AVAILABLE;
    post send_location_task();
  }

  void start_sending_readings() {
    error_t status;
    uint16_t node;
    txt_readings_t *txt;
    status = call Acks.requestAck(&msg);
    if (status != SUCCESS) {
      sending_readings_failure("Failed to enable acks\n");
      return;
    }
    txt = (txt_readings_t*) call SendReadings.getPayload(&msg, sizeof(txt_readings_t));
    if (txt == NULL) {
      sending_readings_failure("Cannot send empty message\n");
      return;
    }
    *txt = call MsgQueue.get_message();
    node = call Neighbors.route(txt);
    dbg("transmitter", "Route to %d\n", node);
    if (node == CANNOT_ROUTE) {
      sending_readings_failure("Cannot route message\n");
      return;
    }
    status = call SendReadings.send(node, &msg, sizeof(txt_readings_t));
    if (status != SUCCESS) {
      sending_readings_failure("Failed to send readings message\n");
    } else {
      dbg("transmitter", "Sending readings message to node %d, dest x=%d y=%d value=%d\n", node, txt->dest_x, txt->dest_y, txt->value);
    }
  }

  task void send_readings_task() {
    if (!(call MsgQueue.has_readings_to_send())) {
      if (send_location)
        post send_location_task();
      return;
    }
    atomic {
      if (current_radio_status != AVAILABLE) {
        dbg("transmitter", "Radio not available\n");
        return;
      }
      current_radio_status = SENDING_READINGS;
    }
    start_sending_readings();
  }

  command error_t Transmitter.sendReading(txt_readings_t data) {
    call MsgQueue.add_message(data);
    post send_readings_task();
    return SUCCESS;
  }

  event void SendReadings.sendDone(message_t *msg_sent, error_t status) {
    if (current_radio_status == SENDING_READINGS) {
      if (status == SUCCESS) {
        if (call Acks.wasAcked(msg_sent)) {
          call MsgQueue.remove_message();
          dbg("transmitter", "Readings message was acked\n");
        } else {
          call MsgQueue.move_message_to_end();
          dbg("transmitter", "Readings message was NOT acked!\n");
        }
      }
    } else if (current_radio_status == SENDING_LOCATION) {
      send_location = FALSE;
    }
    if (status != SUCCESS) {
      dbg("transmitter", "Failed to send message\n");
    } else {
      dbg("transmitter", "Sending done\n");
    }
    current_radio_status = AVAILABLE;
    post send_location_task();
  }

  event message_t* ReceiveReadings.receive(message_t *msg_received, void *payload, uint8_t len) {
    txt_readings_t *txt;
    loc_broadcast_t *loc;
    error_t status;
    if (len == sizeof(txt_readings_t)) {
      txt = (txt_readings_t*) payload;
      dbg("transmitter", "Received readings message from %d (mote_id=%d) value=%d\n", txt->resender, txt->mote_id, txt->value);
      if (call Neighbors.am_i_recipient(txt->dest_x, txt->dest_y)) {
        status = call SaveReading.save(txt->mote_id, txt->value);
        if (status != SUCCESS) {
          dbg("transmitter", "Failed to save message\n");
        }
      } else {
        dbg("transmitter", "Received message saved to send\n");
        call MsgQueue.add_message(*txt);
        call Neighbors.update_mote(txt->mote_id);
        post send_readings_task();
      }
      return msg_received;
    } else if (len == sizeof(loc_broadcast_t)) {
      loc = (loc_broadcast_t*) payload;
      dbg("transmitter", "Received location broadcast from %d x=%d y=%d\n", loc->mote_id, loc->longitude, loc->latitude);
      call Neighbors.update_mote_from_broadcast(*loc);
      return msg_received;
    } else {
      dbg("transmitter", "Received message of wrong format\n");
      return msg_received;
    }
  }
}
