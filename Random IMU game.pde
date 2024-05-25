import processing.serial.*;
import java.util.ArrayList;
import peasy.*;
import queasycam.*;

QueasyCam cam;
Serial myPort;

float ax, ay, az;
float blockSize = 60; // Size of the snake block
float blockX, blockY; // Initial position of the snake head
float velocityX, velocityY;
ArrayList<PVector> dots;
ArrayList<PVector> bullets;
float velocityBX, velocityBY;
float damping = 0.91; // Damping factor to simulate friction
float threshold = 0.09; // Threshold for detecting actual movement
float dt = 1.001; // Time step for integration
PImage[] sprite;
PImage charImage;
int spriteIndex = 0;
PVector spritePos;
float spriteSpeed = 5;
int numFramesL = 3; // Number of frames in the sprite animation
int numFramesR = 6; // Number of frames in the sprite animation
int numFrames = 6; // Number of frames in the sprite animation
boolean isMovingLeft = false;
boolean isMovingRight = false;
boolean isMoving = false;
boolean stopping = false;
boolean isShot = false;
boolean drawing = false;

ArrayList<PVector> snake; // List to store snake body parts
PVector food; // Position of the food

int animationDelay = 14; // Controls the speed of the animation for moving
int animationDelayS = 13; // Controls the speed of the animation for stopping
int animationCounter = 0;

int mapX = 1920;
int mapY = 1080;

float cameraX = height/2; 
float cameraY = width/2;
float cameraZ = (height/2.0) / tan(PI*30.0 / 180.0);

void setup() {
  size(1920, 1080, P3D);
  //hint(ENABLE_KEY_REPEAT);
  /*cam = new PeasyCam(this, 100);
  cam.setMinimumDistance(50);
  cam.setMaximumDistance(500);*/
  //println(Serial.list());
  cam = new QueasyCam(this);
  cam.sensitivity = 1;
  cam.speed = 5;
  perspective(PI/3, (float)width/height, 0.01, 100000);
  
  myPort = new Serial(this, "COM11", 19200); // Adjust index for your port
  myPort.bufferUntil('\n');
  
  blockX = width / 2;
  blockY = height / 2;
  
  snake = new ArrayList<PVector>();
  snake.add(new PVector(blockX, blockY)); // Initial position of the snake
  dots = new ArrayList<PVector>();
  for(int i = 0; i<5; i++){
    addNewDot();
  }
  bullets = new ArrayList<PVector>();
  
  //Add sprite
  sprite = new PImage[numFrames + 3];
  
  charImage = loadImage("charImg.png");

  sprite[0] = loadImage("sprite0.png"); // Stationary image
  sprite[0].resize(58, 72);
  sprite[8] = loadImage("spriteL4.png"); // Stopping image left
  sprite[8].resize(53, 67);
  sprite[7] = loadImage("spriteR4.png"); // Stopping image right
  sprite[7].resize(53, 68);
  for (int i = 1; i <= numFrames; i++) {
    if (i <= 3)
      sprite[i] = loadImage("spriteL" + i + ".png");
    else
      sprite[i] = loadImage("spriteR" + (i-3) + ".png");
    sprite[i].resize(41, 65);
  }
  
   spritePos = new PVector(width / 2, height / 2);
}

/*void keyTyped() {
  if (keyPressed) {
    if (key == 'w' || key == 'W') {
      cameraY+=0.01;
    }
    else if (key == 'a' || key == 'A'){
      cameraX-=0.01;
    }
    else if (key == 's' || key == 'S'){
      cameraY-=0.01;
    }
    else if (key == 'd' || key == 'D'){
      cameraX+=0.01;
    }
    else if (key == 'e' || key == 'E'){
      cameraZ+=0.01;
    }
    else if (key == 'q' || key == 'Q'){
      cameraZ-=0.01;
    }
    else if (key == 'g' || key == 'G'){
      sprite[0] = loadImage("sprite1.png");
      sprite[0].resize(58, 73);
    }
    else if (key == 'f' || key == 'F'){
      sprite[0] = loadImage("sprite0.png");
      sprite[0].resize(58, 72);
    }
  }
}*/

void draw() {
  background(0, 63, 127);
  fill(150,75,0);
  rect(120, 80, 1000, 50);
  rect(1120, 80, 50, 900);
  //rect(mouseX, mouseY, 50, 50); 
  //camera(cameraX, cameraY, cameraZ, cameraX, cameraY, cameraZ, 0.0, 1.0, 0.0);
  /*beginCamera();
  camera();
  rotateX(cameraX);
  rotateY(cameraY);
  rotateZ(1+cameraZ);
  endCamera();*/
  handleInput(); // Update snake movement
  image(charImage, spritePos.x + 17, spritePos.y - 60);
  
  // Draw food
  fill(150, 200, 29);
  for (PVector dot : dots) {
    ellipse(dot.x, dot.y, 35, 35);
  }
  
  fill(200,0,125);
  for (PVector bullet : bullets){
    rect(bullet.x, bullet.y, 3, 6);
  }
  
  fill(150,75,0);
  //rect(120, 80, 1000, 50);
  //rect(1120, 80, 50, 900);
  
  //background(0);
  noStroke();
  lights();
  //translate(80, 200, 0);
  //sphere(120);
  translate(320, 0, 0);
  sphere(120);
  // Draw snake
  /*for (PVector part : snake) {
    fill(0);
    rect(part.x, part.y, blockSize, blockSize);
  }*/
  
  // Check for collisions
  checkCollisions();
  
  //Display accel values
  fill(255, 0, 0);
  textSize(35);
  text("VelX: " + velocityX, 10, height - 120);
  text("VelY: " + velocityY, 10, height - 85);
  text("aX: " + ax, 10, height - 50);
  text("aY: " + ay, 10, height - 15);
  text("aZ: " + az, 10, height + 20);
}

void handleInput() {
  // Apply threshold to accelerometer values and update velocity
  if (abs(ay) > threshold) {
    velocityX += ay * dt;
    velocityX = constrain(velocityX, -15, 20); // Limit velocity for smoother control
    spritePos.x += velocityX;
    if(ay > 0){
      isMovingLeft = false;
      isMovingRight = true;
    }
    else{
      isMovingLeft = true;
      isMovingRight = false;
    }
    isMoving = true;
  }
  if (abs(ax) > threshold) {
    velocityY += ax * dt;
    velocityY = constrain(velocityY, -15, 20); // Limit velocity for smoother control
    spritePos.y += velocityY;
    isMoving = true;
    if (abs(ay) <= threshold){
      if(ay > 0){
        isMovingLeft = false;
        isMovingRight = true;
      }
      else{
        isMovingLeft = true;
        isMovingRight = false;
      }
    }
  }
  if (abs(az) > 0.41){
    isShot = true;
    PVector newBullet = new PVector(spritePos.x, spritePos.y + 26);
    bullets.add(newBullet);
    velocityBX = spritePos.x;
    velocityBY = spritePos.y + 26;
    delay(60);
  }
  
  if (abs(ax) <= threshold && abs(ay) <= threshold){
    isMoving = false;
    if(velocityX < 0.001 || velocityY < 0.001){
      velocityX = 0;
      velocityY = 0;
    }
  }
  
  // Constrain sprite to window boundaries
  spritePos.x = constrain(spritePos.x, 0, width - sprite[0].width);
  spritePos.y = constrain(spritePos.y, 0, height - sprite[0].height);
  
  // Display sprite
  if (isMoving) {
    if (animationCounter >= animationDelay && isMovingRight == true) {
      spriteIndex = (spriteIndex + 4) % numFramesR + 3; // Cycle through frames 1 to 4
      if(spriteIndex > 6 || spriteIndex < 4)
        spriteIndex = 4;
      animationCounter = 0;
    }
    else if (animationCounter >= animationDelay && isMovingLeft == true) {
      spriteIndex = (spriteIndex + 1) % numFramesL + 1; // Cycle through frames 1 to 4
      if(spriteIndex > 4)
        spriteIndex = 1;
      animationCounter = 0;
    }
    animationCounter++;
  }
  else {
    if (animationCounter >= animationDelayS) {
      if(spriteIndex > 0 && stopping == false){
        if (isMovingRight == true)
          spriteIndex = 8;
        else if (isMovingLeft == true)
          spriteIndex = 7;
        stopping = true;
      }
      else if ((spriteIndex == 7 || spriteIndex == 8) && stopping == true){
        spriteIndex = 0;
        stopping = false;
        isMovingRight = false;
        isMovingLeft = false;
      }
      
      if(!(spriteIndex == 7 || spriteIndex == 8) && stopping == true){
        stopping = false;
      }
      animationCounter = 0;
    }
    animationCounter++;
  }
  println("Current frame index: " + spriteIndex);
  println("Stopping frame: " + stopping);
  image(sprite[spriteIndex], spritePos.x, spritePos.y);

  // Update block position based on velocity
  blockX += velocityX * dt;
  blockY += velocityY * dt;

  // Apply damping to slow down the movement over time
  velocityX *= damping;
  velocityY *= damping;

  // Keep the block within the screen boundaries
  blockX = constrain(blockX, 0, width - blockSize);
  blockY = constrain(blockY, 0, height - blockSize);
  
  if(isShot){
    PVector newBullet = new PVector(velocityBX, velocityBY);
    bullets.add(newBullet);
    velocityBX += 2;
    bullets.remove(0);
  }

  // Update snake position
  /*PVector newHead = new PVector(blockX, blockY);
  snake.add(newHead);
  if (snake.size() > 1) {
    snake.remove(0); // Remove tail if snake moved
  }*/
}

void checkCollisions() {
  // Check for collision with dots
  for (int i = dots.size() - 1; i >= 0; i--) {
    PVector dot = dots.get(i);
    if (dist(spritePos.x + blockSize / 2, spritePos.y + blockSize / 2, dot.x, dot.y) <= blockSize / 2) {
      dots.remove(i);
      addNewDot();
      //PVector tail = snake.get(0).copy();
      //snake.add(0, tail); // Add tail segment
    }
  }
}

void addNewDot() {
  float x = random(20, width - 20);
  float y = random(20, height - 20);
  dots.add(new PVector(x, y));
}

void shootBullet() {
  float x = spritePos.x;
  float y = spritePos.y + 27;
  //PVector newBullet = new PVector(velocityX, velocityY);
  bullets.add(new PVector(x, y));
}

void serialEvent(Serial myPort) {
  String inString = myPort.readStringUntil('\n');
  if (inString != null) {
    inString = trim(inString);
    String[] values = split(inString, ',');

    if (values.length == 6) {
      try {
        ax = float(split(values[0], ':')[1]);
        ay = float(split(values[1], ':')[1]);
        az = float(split(values[2], ':')[1]);
        // Ignoring gx, gy, gz for this example
      } catch (Exception e) {
        println("Error parsing values: " + e.getMessage());
      }
    }
  }
}
