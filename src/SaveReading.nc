/**
 * The interface to save readings from other motes.
 */
interface SaveReading {
  /**
   * Saves the reading.
   *
   * @param moteId The mote ID of the mote which measured the value.
   * @param value The measured value.
   * @param result SUCCESS if the reading was saved successfully.
   */
  command error_t save(uint16_t moteId, uint16_t value);
}
