#include "Const.h"

interface MsgQueue {

  command void add_message(txt_readings_t data);

  command bool has_readings_to_send();

  command txt_readings_t get_message();

  command void remove_message();

  command void move_message_to_end();
}
