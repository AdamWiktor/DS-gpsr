/**
 * Read interface to query for this mote location.
 */
interface ReadLocation {
  /**
   * Initiates a read of the location.
   *
   * @return SUCCESS if a readDone() event will eventually come back.
   */
  command error_t read();

  /**
   * Signals the completion of the read().
   *
   * @param result SUCCESS if the read() was successful.
   * @param longitude The longitude of this mote location.
   * @param latitude The latitude of this mote location.
   */
  event void readDone(error_t result, uint32_t longitude, uint32_t latitude);
}
