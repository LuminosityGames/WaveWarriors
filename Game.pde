public class Game {

  private PImage background;
  public ArrayList<Player> players;
  private boolean paused;

  public ArrayList<PowerUp> powerUps;

  private boolean isIntroducingWave;
  private Wave wave;
  private int waveLevel;
  private int waveLevelFontTransparency;
  private int waveTextX;
  private int introFrame;
  private int gameOverTextX;
  private int scoreTextWidth;
  private int backButtonX;
  private long startTime;
  private long timeOfLosing;

  public  boolean playerSelectedMainMenu;
  private PImage backButton;

  PFont timeFont;
  PFont waveFont;

  public static final int FIRST_WAVE_LEVEL = 1;
  public static final int BASE_FONT_SIZE = 125;
  public static final int INTRO_FRAME_LENGTH = 150;

  public static final int POWER_UP_SPAWN_DELAY = 500;

  public static final int UNINITIALIZED = -1;

  private int lastPowerUpSpawn;

  private int lastPause;
  private int pausedFrames;

  public Game(boolean player1, boolean player2, boolean player3, boolean player4) {
    this.background = loadImage("gamebackground.png");

    this.players = new ArrayList<Player>();

    if (player1) {
      players.add(new Player(1, 300, 300, controller1, false));
    }

    if (player2) {
      players.add(new Player(2, 800, 300, controller1, false));
    }

    if (player3) {
      players.add(new Player(3, 300, 500, controller3, false));
    }

    if (player4) {
      players.add(new Player(4, 800, 500, controller4, false));
    }

    this.paused = false;
    this.waveLevel = FIRST_WAVE_LEVEL;
    this.wave = new Wave(waveLevel);
    this.waveFont = loadFont("Silom-100.vlw");
    this.waveLevelFontTransparency = 0;
    this.waveTextX = 0;
    this.introFrame = 0;
    this.lastPause = 0;
    this.pausedFrames = 0;
    this.gameOverTextX = -2000;
    this.scoreTextWidth = 0;
    this.backButtonX = -500;
    this.backButton = loadImage("backButton.png");
    this.playerSelectedMainMenu = false;
    
    this.isIntroducingWave = true;

    this.powerUps = new ArrayList<PowerUp>();
    this.lastPowerUpSpawn = 0;
    this.startTime = System.currentTimeMillis();
    this.timeFont = loadFont("CourierNewPS-BoldMT-30.vlw");
    this.timeOfLosing = UNINITIALIZED;
  }

  public int frameCount() {
    return frameCount - getPausedFrames();
  }

  public int getPausedFrames() {
    if (lastPause > 0) {
      return pausedFrames + (frameCount - lastPause);
    } else {
      return pausedFrames;
    }
  }

  public void update() {
    if (keys[BACKSPACE] || controller1.justPressed(controller1.start)) {
      if (paused) {
        pausedFrames += frameCount - lastPause;
        paused = false;
        lastPause = 0;
      } else if (!gameLost()) {
        lastPause = frameCount;
        paused = true;
      }
      keys[BACKSPACE] = false;
    }

    updateWaveFont();

    if (paused) {
      return;
    }

    if (!gameLost()){
      updatePlayers();
    }
    
    if (wave.isDefeated()) {
      healAllPlayers();
    }

    updateIntroductionStatus();
    checkCollisions();

    if (!isIntroducingWave && !gameLost()) {
      updateWave();
      checkPowerUpSpawn();
    } else if (gameLost()) {
      for (Player player : players) {
        if (player.controller.justPressed(player.controller.B)) {
          playerSelectedMainMenu = true;
        }
      }
    }
  }

  private void updateWave() {
    if (wave.isDefeated()) {
      isIntroducingWave = true;
      wave = new Wave(++waveLevel);
    } 
    wave.update();
  }

  private void updateWaveFont() {
    if (isIntroducingWave) {
      introFrame++;
    }
  }

  private void updateIntroductionStatus() {
    if (introFrame >= INTRO_FRAME_LENGTH) {
      isIntroducingWave = false;
      waveTextX = 0;
      introFrame = 0;
    }
  }

  private void updatePlayers() {
    for (final Player p : players) {
      p.update();
    }
  } 

  public void draw() {
    imageMode(CORNER);
    image(background, 0, 0);

    drawPowerUps();
    drawPlayers();
    wave.display();

    if (isIntroducingWave) {
      introduceWave(waveLevel);
    }

    wave.display();

    if (paused) {
      drawPauseMenu();
    }

    if (gameLost()) {
      drawGameOverScreen();
    } else {
      displayWave();
      displayTime();
    }
  }

  void mouseClicked() {
    for (Player player : players) {
      player.shoot();
    }
  }

  public void drawPauseMenu() {
    rectMode(CORNER);
    noStroke();
    fill(0, 200);
    rect(0, 0, width, height);
    textFont(waveFont);
    textSize(72);
    fill(255, 255);
    text("Game Paused", width / 2, height / 2);
  }

  public void checkCollisions() {
    checkPlayerBulletCollisions();
    checkEnemyBulletCollisions();
    checkPlayerPowerUpCollisions();
    checkPlayerLaserCollisions();
  }



  public void checkPlayerLaserCollisions() {
    for (Player player : players) {
      if (player.usingGun() || player.down || !player.isFiring()) {
        continue;
      }

      Enemy target = player.getClosestHitEnemy();

      if (target != null) {      
        float targetDistance = dist(player.x, player.y, target.x, target.y);
        if (game.frameCount() - player.lastLaser > Player.LASER_RATE / (player.hasFireRate() ? 2 : 1)) {
          player.lastLaser = game.frameCount();
          target.hitByLaser();
          if (player.hasDamage()) {
            target.hitByLaser();
          }
        }
        player.laserX = player.x + (float) (targetDistance * Math.sin(Math.toRadians(90 - player.aim)));
        player.laserY = player.y + (float) (targetDistance * Math.sin(Math.toRadians(player.aim)));
      } else {
        player.laserX = player.x + (float) (width * Math.sin(Math.toRadians(90 - player.aim)));
        player.laserY = player.y + (float) (width * Math.sin(Math.toRadians(player.aim)));
      }
    }
  }

  public void checkPlayerBulletCollisions() {
    ArrayList<Bullet> toRemove = new ArrayList<Bullet>();
    for (Player player : players) {
      for (Bullet bullet : player.bullets) {
        if (bullet.isOutOfBounds()) {
          toRemove.add(bullet);
          continue;
        }
        for (Enemy enemy : wave.enemies) {
          if (collided(bullet.x, bullet.y, Bullet.BULLET_RADIUS / 2, enemy.x, enemy.y, enemy.radius)) {
            toRemove.add(bullet);
            player.gainEnergy();
            bulletSound.trigger();
            enemy.hitByBullet();
            if (player.hasDamage()) {
              enemy.hitByBullet();
            }
          }
        }
      }
      for (Bullet bullet : toRemove) {
        player.bullets.remove(bullet);
      }
    }
  }

  public void checkEnemyBulletCollisions() {
    for (Enemy enemy : wave.enemies) {
      ArrayList<Bullet> toRemove = new ArrayList<Bullet>();
      for (Bullet bullet : enemy.getFiredBullets ()) {
        if (bullet.isOutOfBounds()) {
          toRemove.add(bullet);
          continue;
        }
        for (Player player : players) {
          if (player.hasInvincibility()) {
            continue;
          }
          if (collided(bullet.x, bullet.y, Bullet.BULLET_RADIUS / 2, player.x, player.y, player.radius)) {
            toRemove.add(bullet);
            player.hit();
          }
        }
      }
      for (Bullet bullet : toRemove) {
        enemy.getFiredBullets().remove(bullet);
      }
    }
  }

  public void checkPlayerPowerUpCollisions() {
    ArrayList<PowerUp> toRemove = new ArrayList<PowerUp>();
    for (PowerUp powerUp : powerUps) {
      for (Player player : players) {
        if (player.down) {
          continue;
        }
        if (collided(powerUp.x, powerUp.y, PowerUp.POWER_UP_RADIUS / 2, player.x, player.y, player.radius)) {
          if (powerUp.type == PowerUp.HEAL) {
            player.heal();
          } else if (powerUp.type == PowerUp.NUKE) {
            for (Enemy enemy : wave.enemies) {
              enemy.hitByNuke();
            }
          } else {
            player.powerUp = powerUp;
            player.pickUpTime = game.frameCount();
          }
          powerUpSound.trigger();
          toRemove.add(powerUp);
        }
      }
    }
    for (PowerUp powerUp : toRemove) {
      powerUps.remove(powerUp);
    }
  }

  public boolean collided(float x1, float y1, float r1, float x2, float y2, float r2) {
    return dist(x1, y1, x2, y2) < r1 + r2;
  }

  public boolean collided(float x0, float y0, float x1, float y1, float x2, float y2, float r) {
    float a = x1-x0; 
    float b = y1-y0;
    float c = x2-x0;
    float d = y2-y0;

    if ((d*a - c*b)*(d*a - c*b) <= r*r*(a*a + b*b)) {
      if (c*c + d*d <= r*r) {
        return true;
      }
      if ((a-c)*(a-c) + (b-d)*(b-d) <= r*r) {
        return true;
      }
      if (c*a + d*b >= 0 && c*a + d*b <= a*a + b*b) {
        return true;
      }
    }
    return false;
  }

  public float playerDist(Player p1, Player p2) {
    return dist(p1.x, p1.y, p2.x, p2.y);
  }

  private void healAllPlayers() {
    for (Player player : players) {
      player.respawn();
    }
  }

  private void drawPlayers() {
    for (Player player : players) {
      player.display();
    }
  }

  private void drawPowerUps() {
    for (PowerUp powerUp : powerUps) {
      powerUp.draw();
    }
  }

  private void introduceWave(final int waveLevel) {
    noStroke();
    fill(0, 255 - abs(INTRO_FRAME_LENGTH / 2 - introFrame) * 4);
    rectMode(CENTER);
    rect(width/2, height/2, width, height/2);

    textAlign(CENTER);
    textFont(waveFont, BASE_FONT_SIZE);
    fill(255);

    if ((waveTextX < width/3.5) || (waveTextX > width*2/3.5)) {
      waveTextX += 30;
    } else {
      waveTextX += 3;
    }

    text("Wave", waveTextX, height/2 - 50);
    text("#" + waveLevel, width - waveTextX, height/2 + 125);
  }

  private void checkPowerUpSpawn() {
    if (shouldSpawnPowerUp()) {
      spawnPowerUp();
    }
  }

  private boolean shouldSpawnPowerUp() {
    return game.frameCount() - lastPowerUpSpawn >= POWER_UP_SPAWN_DELAY && powerUps.size() < 3;
  }

  private PowerUp getRandomPowerUp() {
    float x = random(width - 100) + 50;
    float y = random(height - 100) + 50;
    int type = int(random(8));
    return new PowerUp(x, y, type);
  }

  private void spawnPowerUp() {
    PowerUp powerUp = getRandomPowerUp();
    powerUps.add(powerUp);
    lastPowerUpSpawn = game.frameCount();
  }

  private boolean gameLost() {
    if (timeOfLosing != UNINITIALIZED) {
      return true;
    }  
    for (Player player : players) {
      if (!player.down) {
        return false;
      }
    }
    if (timeOfLosing == UNINITIALIZED) {
      timeOfLosing = System.currentTimeMillis();
    }  
    return true;
  }

  private void drawGameOverScreen() {
    noStroke();
    rectMode(CENTER);
    float transparency = map(gameOverTextX, -500, 850, 255, 100);
    fill(30, transparency);
    rect(width/2, height/2, width, height);

    textAlign(CENTER);
    textFont(waveFont, BASE_FONT_SIZE + 25);
    fill(255, 235);

    gameOverTextX = constrain(gameOverTextX + 10, -500, 850);

    text("Over", gameOverTextX + 25, 150);
    text("Game", width - gameOverTextX - 25, 150);

    boolean shouldShowScoreBanner = gameOverTextX == 850;
    if (shouldShowScoreBanner) {
      fill(255, 150);
      scoreTextWidth = constrain(scoreTextWidth + 100, 0, width);
      rectMode(CENTER);
      rect(width/2, height/2, scoreTextWidth, height/2);
    }

    boolean shouldShowScoreAndBackButton = scoreTextWidth == width;

    if (shouldShowScoreAndBackButton) {
      backButtonX = constrain(backButtonX + 50, -500, width/4);
      noStroke();
      rectMode(CENTER);
      fill(46, 204, 113);
      rect(width - 250, height/2, 500, 200, 10);

      fill(255);
      textFont(waveFont, 50);
      text("Wave " + waveLevel, width - backButtonX + 80, height/2 - 20);

      fill(0);
      textFont(waveFont, map(sin(frameCount/10.0), -1, 1, 48, 54));
      text(getFormattedTimeElapsed(), width - backButtonX + 80, height/2 + 60);

      fill(255, 102, 102);

      noStroke();
      rectMode(CENTER);
      rect(0, height/2, 1000, 200, 10);
      textFont(waveFont, 50);
      fill(255);
      text("Main Menu", backButtonX - 100, height/2 - 20);

      fill(0);
      textFont(waveFont, 42);
      text("Press", backButtonX - 150, height/2 + 45);

      noFill();
      strokeWeight(4);
      ellipseMode(CENTER);
      textFont(timeFont, 50);

      image(backButton, backButtonX - 60, height / 2);
    }
  }

  private void displayWave() {
    fill(0);
    textAlign(CORNER);
    textFont(waveFont, 30);
    text("Wave " + waveLevel, 35, 50);
  }

  private void displayTime() {
    String time = getFormattedTimeElapsed();
    fill(0);
    textAlign(CORNER);
    textFont(timeFont, 30);
    text(time, 35, 100);
  }

  private String getFormattedTimeElapsed() {
    long currentTime = gameLost() ? timeOfLosing : System.currentTimeMillis();
    long timeElapsed = currentTime - startTime;
    int minutes = (int) ((timeElapsed / (1000*60)) % 60);
    int seconds = (int) (timeElapsed / 1000) % 60;
    int mills = (int) timeElapsed % 1000;
    return String.format("%02d:%02d:%03d", minutes, seconds, mills);
  }
}

