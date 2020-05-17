#ifndef __AW_CONST_H__
#define __AW_CONST_H__

#include <AM.h>

typedef nx_struct txt_readings {
    nx_uint16_t mote_id;
    nx_uint16_t resender;
    nx_uint32_t dest_x;
    nx_uint32_t dest_y;
    nx_uint32_t peri_x;
    nx_uint32_t peri_y;
    nx_uint8_t is_peri;
    nx_uint16_t value;
} txt_readings_t;

typedef nx_struct loc_broadcast {
  nx_uint16_t mote_id;
  nx_uint32_t longitude;
  nx_uint32_t latitude;
} loc_broadcast_t;

typedef struct message {
  txt_readings_t data;
  uint16_t retransmissions;
} msg_t;

typedef struct neighbor {
  uint32_t x; // longitude
  uint32_t y; // latitude
  uint32_t last_alive;
  uint16_t unresponds;
} neighbor_t;

enum
{
    AM_TXT_SENSOR_READINGS = 57,
    MAX_NEIGHBORS = 1000,
    CANNOT_ROUTE = 1001,
    READINGS_TIME = 5000,
    BROADCAST_TIME = 10000
};


#endif
