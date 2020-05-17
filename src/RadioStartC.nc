configuration RadioStartC {}
implementation {
  components MainC, RadioStartP;

  RadioStartP.Boot -> MainC;

  components ActiveMessageC;
  RadioStartP.RadioControl -> ActiveMessageC;
}
