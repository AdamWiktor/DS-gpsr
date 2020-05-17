#include "Const.h"

interface Neighbors {

  command uint16_t route(txt_readings_t *data);

  command void update_mote(uint16_t mote_id);

  command void update_mote_from_broadcast(loc_broadcast_t loc);

  command void mote_not_responded(uint16_t mote_id);

  command loc_broadcast_t* give_broadcast_msg();

  command bool am_i_recipient(uint32_t longitude, uint32_t latitude);
}
