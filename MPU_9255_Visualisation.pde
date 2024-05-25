import processing.serial.*;
float angle;
Serial myPort;

void setup() {
  size(1920, 1080, P3D);
  noStroke();
  fill(255);
  rectMode(CENTER);
  myPort = new Serial(this, "COM6", 19200); //change com port and baudrate to suit your deviceeeeeee
  myPort.bufferUntil('\n');
}

void draw() {
  background(61);

  pushMatrix();
  translate(width/2, height/2);
  rotate(-radians(angle));
  fill(0, 100, 153);
  rect(0, 0, 180, 180); 
  popMatrix();
  
  pushMatrix();
  translate(width/2, height/2);
  rotate(-radians(angle));
  line(0, 0, 0, 200);
  stroke(200);
  popMatrix();
  
  translate(232, -height/2, -150); 
  fill(255, 0, 0);
  textSize(35);
  text("Heading: " + angle + " degs", 10, height - 140);
  translate(232, height - 220, -150);
  
  pushMatrix();
  float x = cos(radians(angle)) * 200;
  float y = sin(radians(angle)) * 200;
  translate(width/2, height/2);
  line(10, 0, -x, y);
  circle(10, 0, 400);
  popMatrix();
}


void serialEvent(Serial myPort) {
  String inString = myPort.readStringUntil('\n');
  if (inString != null) {
    inString = trim(inString);
    String[] values = split(inString, ',');

    if (values.length == 6) {
      try {
        angle = float(split(values[5], ':')[1]);
        println(angle);
        // Ignoring gx, gy, gz for this example
      } catch (Exception e) {
        println("Error parsing values: " + e.getMessage());
      }
    }
  }
}
