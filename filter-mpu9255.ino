#include <MPU9255.h>// include MPU9255 library
#include "MPU9250.h"
#include <MadgwickAHRS.h>
#include "eeprom_utils.h"
#define grav 9.81 // 1g ~ 9.81 m/s^2
#define magnetometer_cal 0.06 //magnetometer calibration
MPU9255 mpu;
MPU9250 mpu_cali;
Madgwick filter;
unsigned long microsPerReading, microsPrevious;
const float declination = 0.04; // Magnetic declination for Singapore in degrees (West)
float accelScale, gyroScale;
int aix, aiy, aiz;
int gix, giy, giz;
float ax, ay, az;
float gx, gy, gz;
float mx, my, mz;
float roll, pitch, heading;
float yaw;
float val1,val2,valdiff;
unsigned long microsNow;

double process_acceleration(int input, scales sensor_scale )
{
  /*
  To get acceleration in 'g', each reading has to be divided by :
   -> 16384 for +- 2g scale (default scale)
   -> 8192  for +- 4g scale
   -> 4096  for +- 8g scale
   -> 2048  for +- 16g scale
  */
  double output = 1;

  //for +- 2g

  if(sensor_scale == scale_2g)
  {
    output = input;
    //output = output/16384;
    //output = output*grav;*/
    output = (output * 2) / 32768.0;
  }

  //for +- 4g
  if(sensor_scale == scale_4g)
  {
    output = input;
    //output = output/8192;
    //output = output*grav;
    output = (output * 2) / 16384.0;
  }

  //for +- 8g
  if(sensor_scale == scale_8g)
  {
    output = input;
    output = output/4096;
    output = output*grav;
  }

  //for +-16g
  if(sensor_scale == scale_16g)
  {
    output = input;
    output = output/2048;
    output = output*grav;
  }

  return output;
}

double process_angular_velocity(int16_t input, scales sensor_scale )
{
  /*
  To get rotation velocity in dps (degrees per second), each reading has to be divided by :
   -> 131   for +- 250  dps scale (default value)
   -> 65.5  for +- 500  dps scale
   -> 32.8  for +- 1000 dps scale
   -> 16.4  for +- 2000 dps scale
  */

  //for +- 250 dps
  if(sensor_scale == scale_250dps)
  {
    return input/131;
    //input = (input * 250.0) / 32768.0;
    return input;
  }

  //for +- 500 dps
  if(sensor_scale == scale_500dps)
  {
    input = (input * 500.0) / 16384.0;
    return input;
  }

  //for +- 1000 dps
  if(sensor_scale == scale_1000dps)
  {
    input = input / 90;
    return input;
  }

  //for +- 2000 dps
  if(sensor_scale == scale_2000dps)
  {
    return input/16.4;
  }

  return 0;
}

double process_magnetic_flux(int16_t input, double sensitivity)
{
  /*
  To get magnetic flux density in μT, each reading has to be multiplied by sensitivity
  (Constant value different for each axis, stored in ROM), then multiplied by some number (calibration)
  and then divided by 0.6 .
  (Faced North each axis should output around 31 µT without any metal / walls around
  Note : This manetometer has really low initial calibration tolerance : +- 500 LSB !!!
  Scale of the magnetometer is fixed -> +- 4800 μT.
  */
  return (input*magnetometer_cal*sensitivity)/0.6;
}

void setup() {
  Serial.begin(19200); // initialize Serial port
  Wire.begin(); //for i2c purposes
  delay(2000);

  MPU9250Setting setting;
  setting.accel_fs_sel = ACCEL_FS_SEL::A4G; //set accel to 2g scale
  setting.gyro_fs_sel = GYRO_FS_SEL::G2000DPS; //set gyro scale to 250deg/sec sens
  setting.mag_output_bits = MAG_OUTPUT_BITS::M16BITS;
  setting.fifo_sample_rate = FIFO_SAMPLE_RATE::SMPL_125HZ; //1khz sample rate
  setting.gyro_fchoice = 0x03;
  setting.gyro_dlpf_cfg = GYRO_DLPF_CFG::DLPF_41HZ;
  setting.accel_fchoice = 0x01;
  setting.accel_dlpf_cfg = ACCEL_DLPF_CFG::DLPF_45HZ;

  if (!mpu_cali.setup(0x68)) {  // change to your own address
      while (1) {
          Serial.println("Wrong IMU Bro");
          delay(3000);
      }
  }

  filter.begin(10);

  /*Serial.println("Accel/Gyro calibration starts in 5 seconds!");
  Serial.println("Please leave the device still on the flat plane.");
  mpu_cali.verbose(true);
  delay(5000);
  mpu_cali.calibrateAccelGyro();

  Serial.println("Magneto calibration will start in 5 seconds!");
  Serial.println("Please wave the IMU in a figure eight until done.");
  delay(5000);
  mpu_cali.calibrateMag();

  mpu_cali.verbose(false);*/

  /* if calibration is required, uncomment
  Serial.println("Accel Gyro calibration will start in 5sec.");
  Serial.println("Please leave the device still on the flat plane.");
  mpu.verbose(true);
  delay(5000);
  mpu.calibrateAccelGyro();

  Serial.println("Mag calibration will start in 5sec.");
  Serial.println("Please Wave device in a figure eight until done.");
  delay(5000);
  mpu.calibrateMag();

  print_calibration();
  mpu.verbose(false);

  // save to eeprom
  saveCalibration();
  */
  loadCalibration();
  delay(500);
}

void loop() {
  mpu.read_acc();
  mpu.read_gyro();
  mpu.read_mag();

  // convert from raw data to gravity and degrees/second units
  ax = process_acceleration(mpu.ax,scale_4g);
  ay = process_acceleration(mpu.ay,scale_4g);
  az = process_acceleration(mpu.az,scale_4g);
  gx = process_angular_velocity(mpu.gx,scale_250dps);
  gy = process_angular_velocity(mpu.gy,scale_250dps);
  gz = process_angular_velocity(mpu.gz,scale_250dps);
  mx = process_magnetic_flux(mpu.mx,mpu.mx_sensitivity);
  my = process_magnetic_flux(mpu.my,mpu.my_sensitivity);
  mz = process_magnetic_flux(mpu.mz,mpu.mz_sensitivity);

  // update the filter, which computes orientation
  filter.update(gx, gy, gz, ax, ay, az, mx, my, mz);
  filter.updateIMU(gx, gy, gz, ax, ay, az);

  heading = filter.getYaw();
  heading += declination;
  if (heading < 0) {
    heading += 360;
  } else if (heading >= 360) {
    heading -= 360;
  }

  //Serial.print("Orientation:");
 // Serial.print(heading);
  //Serial.print(",degs");
  //Serial.println();
  Serial.print("aX:"); Serial.print(ax);
  Serial.print(",aY:"); Serial.print(ay);
  Serial.print(",aZ:"); Serial.print(az);
  Serial.print(",gX:"); Serial.print(roll);
  Serial.print(",gY:"); Serial.print(pitch);
  Serial.print(",gZ:"); Serial.println(heading);
  delay(2);
}