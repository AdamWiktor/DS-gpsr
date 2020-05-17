/**
 * Read interface to query for a recipent of a reading.
 */
interface ReadRecipient {
  /**
   * Initiates a read of the recipent.
   *
   * @return SUCCESS if a readDone() event will eventually come back.
   */
  command error_t read();

  /**
   * Signals the completion of the read().
   *
   * @param result SUCCESS if the read() was successful.
   * @param moteId The mote ID of the recipent.
   * @param longitude The longitude of the recipent location.
   * @param latitude The latitude of the recipent location.
   */
  event void readDone(error_t result, uint16_t moteId, uint32_t longitude, uint32_t latitude);
}
