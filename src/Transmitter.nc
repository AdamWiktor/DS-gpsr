#include <AM.h>
#include "Const.h"

interface Transmitter {
  
  command error_t sendReading(txt_readings_t data);
}
