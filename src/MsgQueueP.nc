#include "Const.h"

enum {
  QUEUE_SIZE = 50,
  MAX_RETRANSMISSIONS = 8
};

module MsgQueueP {

  provides interface MsgQueue;

  uses interface Boot;
}
implementation {

  uint16_t begin;
  uint16_t end;
  msg_t queue[QUEUE_SIZE];
  msg_t empty_msg;

  void print_queue() {
    uint16_t i;
    for (i = 0; i < QUEUE_SIZE; i++) {
      dbg("queue", "*** queue[%d]=%d %d %d %d\n", i, queue[i].data.mote_id, queue[i].data.dest_x, queue[i].data.dest_y, queue[i].data.value);
    }
  }

  event void Boot.booted() {
    uint16_t i;
    txt_readings_t empty_readings = {};
    begin = 0;
    end = 0;
    empty_msg.data = empty_readings;
    empty_msg.retransmissions = 0;
    for (i = 0; i < QUEUE_SIZE; i++)
      queue[i] = empty_msg;
  }

  command void MsgQueue.add_message(txt_readings_t data) {
    if (begin != (end + 1) % QUEUE_SIZE) {
      queue[end].data = data;
      queue[end].retransmissions = 0;
      end = (end + 1) % QUEUE_SIZE;
      dbg("queue", "Added message, begin=%d end=%d\n", begin, end);
    } else {
      dbg("queue", "Queue full, cannot add message with value=%d\n", data.value);
    }
  }

  command bool MsgQueue.has_readings_to_send() {
    dbg("queue", "Check if has readings to send\n");
    return begin != end;
  }

  command txt_readings_t MsgQueue.get_message() {
    dbg("queue", "Getting message from queue %d\n", begin);
    return queue[begin].data;
  }

  command void MsgQueue.remove_message() {
    dbg("queue", "Removed message with value=%d begin=%d end=%d\n", queue[begin].data.value, begin, end);
    queue[begin] = empty_msg;
    begin = (begin + 1) % QUEUE_SIZE;
  }

  command void MsgQueue.move_message_to_end() {
    if (queue[begin].retransmissions > MAX_RETRANSMISSIONS) {
      dbg("queue", "Retransmissions failed, deleting message with value=%d\n", queue[begin].data.value);
      queue[begin] = empty_msg;
      begin = (begin + 1) % QUEUE_SIZE;
      return;
    }
    dbg("queue", "Moving message to end, begin=%d end=%d\n", begin, end);
    queue[end].data = queue[begin].data;
    queue[end].retransmissions = queue[begin].retransmissions + 1;
    queue[begin] = empty_msg;
    begin = (begin + 1) % QUEUE_SIZE;
    end = (end + 1) % QUEUE_SIZE;
  }
}
