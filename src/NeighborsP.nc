#include "Const.h"

enum {
  MAX_UNRESPONDS = 4,
  DEAD = 0
};

module NeighborsP {

  provides interface Neighbors;

  uses {
    interface Boot;
    interface Timer<TMilli>;
    interface ReadLocation;
  }
}
implementation {

  neighbor_t neighbors[MAX_NEIGHBORS];
  loc_broadcast_t own_location;
  bool has_own_location = FALSE;

  event void Boot.booted() {
    uint16_t i;
    error_t status = call ReadLocation.read();
    if (status != SUCCESS) {
      dbg("neighbors", "Failed to read own location\n");
    }
    for (i = 0; i < MAX_NEIGHBORS; i++)
      neighbors[i].last_alive = DEAD;
  }

  event void ReadLocation.readDone(error_t result, uint32_t longitude, uint32_t latitude) {
    if (result != SUCCESS) {
      dbg("neighbors", "Failed to read own location\n");
      while (call ReadLocation.read() != SUCCESS);
      return;
    }
    own_location.longitude = longitude;
    own_location.latitude = latitude;
    own_location.mote_id = TOS_NODE_ID;
    has_own_location = TRUE;
    dbg("neighbors", "Obtained own location x=%d y=%d\n", longitude, latitude);
  }

  event void Timer.fired() {
    // empty, timer is used only to get current time
  }

  void filter_nonexisting_neighbors() {
    uint16_t i;
    uint32_t now = call Timer.getNow();
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].last_alive + 3 * BROADCAST_TIME < now) {
        neighbors[i].last_alive = DEAD;
      }
    }
  }

  uint32_t distance(uint32_t a_x, uint32_t a_y, uint32_t b_x, uint32_t b_y) {
    uint32_t dist_x = abs(a_x - b_x);
    uint32_t dist_y = abs(a_y - b_y);
    return dist_x * dist_x + dist_y * dist_y;
  }

  uint16_t route_greedy(txt_readings_t *data) {
    uint16_t i, result = CANNOT_ROUTE;
    uint32_t dist, shortest_dist = distance(own_location.longitude, own_location.latitude, data->dest_x, data->dest_y);
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].last_alive != DEAD && i != data->resender) {
        dist = distance(neighbors[i].x, neighbors[i].y, data->dest_x, data->dest_y);
        if (dist < shortest_dist) {
          result = i;
          shortest_dist = dist;
        }
      }
    }
    return result;
  }

  int32_t signed_field(int32_t a_x, int32_t a_y, int32_t b_x, int32_t b_y, int32_t c_x, int32_t c_y) {
    return (a_x * b_y - b_x * a_y + b_x * c_y - c_x * b_y + c_x * a_y - a_x * c_y) / 2;
  }

  bool is_c_on_left_from_ab(int32_t a_x, int32_t a_y, int32_t b_x, int32_t b_y, int32_t c_x, int32_t c_y) {
    return signed_field(a_x, a_y, b_x, b_y, c_x, c_y) <= 0;
  }

  bool is_ab_not_crossing_cd(int32_t a_x, int32_t a_y, int32_t b_x, int32_t b_y, int32_t c_x, int32_t c_y, uint32_t d_x, uint32_t d_y) {
    int32_t abc, abd, cda, cdb;
    abc = signed_field(a_x, a_y, b_x, b_y, c_x, c_y);
    abd = signed_field(a_x, a_y, b_x, b_y, d_x, d_y);
    cda = signed_field(c_x, c_y, d_x, d_y, d_x, d_y);
    cdb = signed_field(c_x, c_y, d_x, d_y, b_x, b_y);

    if ((abc > 0 && abd <= 0) || (abc == 0 && abd != 0) || (abc < 0 && abd >= 0)) {
      if ((cda > 0 && cdb <= 0) || (cda == 0 && cdb != 0) || (cda < 0 && cdb >= 0)) {
        return FALSE;
      }
    }
    return TRUE;
  }

  uint16_t route_perimeter(txt_readings_t *data) {
    bool is_first = FALSE;
    uint16_t i, result = CANNOT_ROUTE;
    uint32_t b_x, b_y;
    if (!data->is_peri) {
      is_first = TRUE;
      data->is_peri = TRUE;
      data->peri_x = own_location.longitude;
      data->peri_y = own_location.latitude;
      b_x = data->dest_x;
      b_y = data->dest_y;
    } else {
      b_x = neighbors[data->resender].x;
      b_y = neighbors[data->resender].y;
    }

    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].last_alive != DEAD) {
        if (is_c_on_left_from_ab(own_location.longitude, own_location.latitude, b_x, b_y, neighbors[i].x, neighbors[i].y)) {
          if (is_first || is_ab_not_crossing_cd(data->peri_x, data->peri_y, data->dest_x, data->dest_y, own_location.longitude, own_location.latitude, neighbors[i].x, neighbors[i].y)) {
            if (result == CANNOT_ROUTE) {
              result = i;
            } else if (is_c_on_left_from_ab(own_location.longitude, own_location.latitude, neighbors[i].x, neighbors[i].y, neighbors[result].x, neighbors[result].y)) {
              result = i;
            }
          }
        }
      }
    }
    return result;
  }

  command uint16_t Neighbors.route(txt_readings_t *data) {
    uint16_t result = CANNOT_ROUTE;
    if (!has_own_location)
      return result;
    dbg("neighbors", "Routing message x=%d y=%d value=%d\n", data->dest_x, data->dest_y, data->value);
    filter_nonexisting_neighbors();
    result = route_greedy(data);
    if (result != CANNOT_ROUTE) {
      dbg("neighbors", "Greedy routing to %d\n", result);
      data->is_peri = FALSE;
      data->resender = TOS_NODE_ID;
      return result;
    }
    result = route_perimeter(data);
    dbg("neighbors", "Perimeter routing to %d\n", result);
    data->resender = TOS_NODE_ID;
    return result;
  }

  command void Neighbors.update_mote(uint16_t mote_id) {
    if (mote_id < MAX_NEIGHBORS && neighbors[mote_id].last_alive != DEAD) {
      neighbors[mote_id].last_alive = call Timer.getNow();
      neighbors[mote_id].unresponds = 0;
    }
  }

  command void Neighbors.update_mote_from_broadcast(loc_broadcast_t loc) {
    uint16_t i, j;
    uint32_t dist_ai, dist_aj, dist_ij, max;
    if (loc.mote_id < MAX_NEIGHBORS) {
      neighbors[loc.mote_id].x = loc.longitude;
      neighbors[loc.mote_id].y = loc.latitude;
      neighbors[loc.mote_id].last_alive = call Timer.getNow();
      neighbors[loc.mote_id].unresponds = 0;
    }
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      for (j = 0; j < MAX_NEIGHBORS; j++) {
        if (i == j || neighbors[i].last_alive == DEAD || neighbors[j].last_alive == DEAD) {
          continue;
        }
        dist_ai = distance(own_location.longitude, own_location.latitude, neighbors[i].x, neighbors[i].y);
        dist_aj = distance(own_location.longitude, own_location.latitude, neighbors[j].x, neighbors[j].y);
        dist_ij = distance(neighbors[i].x, neighbors[i].y, neighbors[j].x, neighbors[j].y);
        max = dist_aj > dist_ij? dist_aj : dist_ij;
        if (dist_ai > max) {
          neighbors[i].last_alive = DEAD;
          break;
        }
      }
    }
  }

  command void Neighbors.mote_not_responded(uint16_t mote_id) {
    if (mote_id > MAX_NEIGHBORS) {
      if (++neighbors[mote_id].unresponds > MAX_UNRESPONDS) {
        dbg("neighbors", "Neighbor %d did not respond %d times\n", mote_id, MAX_UNRESPONDS);
        neighbors[mote_id].last_alive = DEAD;
      }
    }
  }

  command loc_broadcast_t* Neighbors.give_broadcast_msg() {
    if (has_own_location) {
      return &own_location;
    } else {
      return NULL;
    }
  }

  command bool Neighbors.am_i_recipient(uint32_t longitude, uint32_t latitude) {
    return has_own_location && own_location.longitude == longitude && own_location.latitude == latitude;
  }
}
