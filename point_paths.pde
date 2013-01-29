float center_re = -0.7;
float center_im = 0;
float zoom_width = 3.0; // constant "zoom"; n.b.: not related to sub-window (below)

PImage img, zimg; // state image for the fractal; zoom subset, scaled

int last_x = 0, last_y = 0; // state for avoiding re-drawing

// constants for zoom sub-window:
int zoom_size = 30; // size of sub_image
int zoom_scale = 4; // how much to scale it
int zoom_x, zoom_y; // where to place it (set in setup()
boolean want_sub_image = true;

// draw a grid-line at a particular position (using current color)
void draw_grid(float r, float i, boolean is_main_gridline)
{
  int[] pos = get_position(r, i);

  fill(255);
  text("r = " + r, pos[0] + 5, (is_main_gridline ? 20 : 40));
  text("i = " + i, (is_main_gridline ? 10 : 70), pos[1] - 5);
  line(pos[0], 0, pos[0], height);
  line(0, pos[1], width, pos[1]);
}

// normal version 
void draw_grid(float re, float im)
{
  draw_grid(re, im, true);
}

// draw general gridlines for overall plot:
void draw_grids()
{
  // grids for reals -2, -1; imaginaries 1, -1:
  stroke(0, 128, 128, 128);
  draw_grid(-2, 1);
  draw_grid(-1, -1);
  // center axis:
  stroke(128, 128, 128, 128);
  draw_grid(0, 0);
}

void setup()
{
  size(900, 700);
  
  zoom_x = 80;
  zoom_y = height - 70 - zoom_size * zoom_scale;
  
  background(0);
  //frameRate(5);
  draw_grids();
  img = createImage(width, height, RGB);
  img.loadPixels();
  zimg = createImage(int(zoom_size * zoom_scale), int(zoom_size * zoom_scale), RGB);
}

float[] point_at(int x, int y)
{
  float[] point = new float[2];

  point[0] = center_re + (float(x - width/2) / width) * zoom_width;
  point[1] = center_im + (float(height/2 - y) / height) *
    (zoom_width / (float(width)/height));

  return point;
}

// get the integer-based x,y position from a float-based r,i position
int[] get_position(float[] point)
{
  int[] position = new int[2];

  position[0] = int(((point[0] - center_re) / zoom_width) * width + 0.5) + width/2;
  position[1] = height / 2 - int(((point[1] - center_im) / (zoom_width / (float(width)/height))) * height + 0.5);

  return position;
}

int[] get_position(float r, float i)
{
  float[] position = new float[2];

  position[0] = r;
  position[1] = i;
  return get_position(position);
}

// compute the next point on the path for a given z, c
// i.e. the main iteration function, z' = z^2 + c
float[] next_point(float[] z, float[] c)
{
  float[] new_z = new float[2];

  new_z[1] = 2.0*z[0]*z[1] + c[1]; // 2*r*i + c's i
  new_z[0] = z[0]*z[0] - z[1]*z[1] + c[0]; // r*r - i*i + c's r

  return new_z;
}

// function to plot next positions:
void plot_next(float[] point)
{
  int[] position1 = get_position(point);
  int[] start_position = position1;
  float[] new_point = next_point(point, point);
  int[] position2 = get_position(new_point);
  //println("position1 = " + position1[0] + ", " + position1[1]);
  //println("point2 = " + new_point[0] + ", " + new_point[1]);
  //println("position2 = " + position2[0] + ", " + position2[1]);

  int iterations = 0;
  color c;

  // main calculation loop (skipped recursion for iteration counting.  Could be re-worked.)
  do {
    iterations++;
    stroke(0,iterations,255-iterations);
    line(position1[0], position1[1], position2[0], position2[1]);
    position1 = position2;
    new_point = next_point(new_point, point);
    position2 = get_position(new_point);
  } 
  while(iterations < 255 && (abs(new_point[0]) < 4 && abs(new_point[1]) < 4));

  // heuristics for choosing a color:
  if(iterations <= 10)
  {
    // some flavor of red:
    c = color(5 + 25 * iterations, 0, 0);
  }
  else if(iterations <= 15)
  {
    // some flavor of magenta:
    int v = 100 + 10 * iterations;
    c = color(v, 0, v);
  }
  else if(iterations < 255)
  {
    if(iterations < 100)
      c = color(0, 30 + 2 * iterations, 0); // greens
    else
      c = color(0, 0, iterations); // blues
  }
  else
  {
    c = color(255); // white
  }

  img.loadPixels();
  //println("setting " + start_position[1] + ", " + start_position[0] + " to " + red(c) + ", " + green(c) + ", " + blue(c));

  img.pixels[start_position[1] * width + start_position[0]] = c;
  img.updatePixels();

  // println("iterations = " + iterations);
}

void draw_sub_image()
{
  if(!want_sub_image) return;
  
  stroke(255);
  rect(zoom_x - 1, zoom_y - 1, zoom_size * zoom_scale + 1, zoom_size * zoom_scale + 1);
  zimg.copy(img, mouseX - zoom_size/2, mouseY - zoom_size / 2, zoom_size, zoom_size,
            0, 0, zoom_size * zoom_scale, zoom_size * zoom_scale);
  image(zimg, zoom_x, zoom_y);
}

void draw()
{
  if(last_x == mouseX && last_y == mouseY)
    return; // don't waste CPU for non-movement

  // update where we last were:
  last_x = mouseX;
  last_y = mouseY;

  float[] point = point_at(mouseX, mouseY);

  /*
  println("x, y = " + mouseX + ", " + mouseY +
   " (" + point[0] + ", " + point[1] + ")");
   */

  image(img, 0, 0); // lay down the accumulated dots
  draw_sub_image();

  // cross-hairs for current point:
  stroke(64, 0, 64, 255);
  draw_grid(point[0], point[1], false);
  fill(0, 0, 0, 0);
  rect(mouseX - zoom_size/2, mouseY - zoom_size/2, zoom_size, zoom_size); // box around zoom area in main image

  // general grids:
  draw_grids();

  // the path at this point:
  plot_next(point);
}

void fill_area()
{
  int i, j, x, y;
  float[] pos;

  for(i = 0; i < zoom_size; ++i)
  {
    for(j = 0; j < zoom_size; ++j)
    {
      x = mouseX + i - zoom_size/2;
      y = mouseY + j - zoom_size/2;
      
      if(x < 0 || x >= width || y < 0 || y >= height)
        continue;

      plot_next(point_at(x, y));
    }
  }
  
  draw_sub_image();
}

void keyPressed()
{
  switch(key)
  {
  case 'q': 
    exit();
  case 'f': case ' ':
    fill_area();
    break;
  case 'L':
    noLoop();
    break;
  case 'l':
    loop();
    break;
  case 'z':
    want_sub_image = !want_sub_image;
    redraw();
    break;
  }
}

