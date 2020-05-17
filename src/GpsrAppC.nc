configuration GpsrAppC {
}
implementation {
  components GpsrC, MainC, TransmitterP, MsgQueueP, NeighborsP, SophisticatedSensorC;
  components new TimerMilliC() as Timer1;

  GpsrC -> MainC.Boot;

  GpsrC.Timer -> Timer1;
  GpsrC.ReadRecipient -> SophisticatedSensorC;
  GpsrC.ReadReading -> SophisticatedSensorC;
  GpsrC.Transmitter -> TransmitterP;

  components ActiveMessageC, SimpleReadingsStoreP;
  components new AMSenderC(AM_TXT_SENSOR_READINGS) as SendReadingsC;
  components new AMReceiverC(AM_TXT_SENSOR_READINGS) as ReceiveReadingsC;
  components new TimerMilliC() as Timer2;
  TransmitterP.SendReadings -> SendReadingsC;
  TransmitterP.ReceiveReadings -> ReceiveReadingsC;
  TransmitterP.Acks -> ActiveMessageC;
  TransmitterP.SaveReading -> SimpleReadingsStoreP;
  TransmitterP.Timer -> Timer2;
  TransmitterP.Boot -> MainC;
  TransmitterP.MsgQueue -> MsgQueueP;
  TransmitterP.Neighbors -> NeighborsP;

  MsgQueueP.Boot -> MainC;

  components LocationC;
  components new TimerMilliC() as Timer3;
  NeighborsP.Boot -> MainC;
  NeighborsP.ReadLocation -> LocationC;
  NeighborsP.Timer -> Timer3;

  components RadioStartC;
}
