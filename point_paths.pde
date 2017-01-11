// point_paths - an exploration of the paths plotted in iterations
//               of the Mandelbrot Set.
// Copyright 2011-2013 by David Lindes.

/*
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// center of the screen should be at this point:
float mandel_center_re = -0.7; // real component
float mandel_center_im = 0; // imaginary component

boolean julia_mode = false;
float julia_center_re = 0.0;
float julia_center_im = 0.0;
float[] julia_point = {0, 0};

float center_re, center_im;

// "zoom" factor.  Note: not currently change-able:
float mandel_zoom_width = 3.0; // n.b.: not related to sub-window (below)
float julia_zoom_width = 6.0;
float zoom_width = mandel_zoom_width;

// image storage for the computed fractal, julia set,
// pointer to current, and sub-window (respectively):
PImage mandel_img, julia_img, img, zimg;

// state for avoiding re-drawing:
int last_x = 0, last_y = 0;
boolean redraw_required = false;

// constants for zoom sub-window:
int zoom_size = 30; // size of sub_image
int zoom_scale = 4; // how much to scale it
int zoom_x, zoom_y; // where to place it (set in setup())
boolean want_sub_image = true; // should we draw it?

// counters for idle loop, when enabled:
int mandel_idle_x = 0, mandel_idle_y = 0;
int julia_idle_x = 0, julia_idle_y = 0;
int idle_x = mandel_idle_x, idle_y = mandel_idle_y;

boolean fill_on_idle = false;

// main initialization:
void setup()
{
  // sadly, setup can no longer run the likes of switch statements, so
  // have to do sizes more manually:
  //size(1200,800);
  size(900, 700);
  /*
  switch(2) // choice of a few screen resolutions.
  {
    // n.b.: if/when adding new resolutions, note that significant aspect-ratio
    // changes can do strange things. to what gets shown.
  case 0:
    size(600, 440);
    break;
  case 1:
    size(800, 600);
    break;
  default:
    size(900, 700);
    break;
  }
  */

  // where to place the zoom window.  TODO: make this more sane for various resolutions
  zoom_x = 80;
  zoom_y = height - 70 - zoom_size * zoom_scale;

  center_re = mandel_center_re;
  center_im = mandel_center_im;

  background(0); // black
  //frameRate(5);
  draw_grids();
  init_images();
}

// create (and/or re-set) the backing-store images
void init_images()
{
  // general background image (so we can draw over it without having to
  // re-draw the underlying fractal):
  mandel_img = createImage(width, height, RGB);
  img = mandel_img;
  img.loadPixels();
  // sub-image for the zoom region:
  zimg = createImage(int(zoom_size * zoom_scale), int(zoom_size * zoom_scale), RGB);
}

// draw a grid-line at a particular position (using current color)
void draw_grid(float r, float i, boolean is_main_gridline)
{
  int[] pos = get_position(r, i);

  fill(255); // for the text

  text("r = " + r, pos[0] + 5, (is_main_gridline ? 20 : 40));
  text("i = " + i, (is_main_gridline ? 10 : width - 100), pos[1] - 5);

  if (julia_mode && !is_main_gridline) {
    text("J = " + julia_point[0] + "+" + julia_point[1] + "i", 30, 60);
  }
  line(pos[0], 0, pos[0], height);
  line(0, pos[1], width, pos[1]);
}

// two-argument version, used for all but crosshairs:
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

// get the complex-point for a particular set of pixel coordinates
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

// two-argument version of the above:
int[] get_position(float re, float im)
{
  float[] position = new float[2];

  position[0] = re;
  position[1] = im;
  return get_position(position);
}

// compute the next point on the path for a given z, c
// i.e. the main iteration function, z' = z^2 + c
float[] next_point(float[] z, float[] c)
{
  float[] new_z = new float[2];
  if (julia_mode)
    c = julia_point;

  // (a+bi)^2 == a^2 + 2abi + (bi)^2 == a^2 + 2abi - b^2
  new_z[1] = 2.0*z[0]*z[1] + c[1]; // z'[i] = 2*z[r]*z[i] (i.e. 2ab) + c[i]
  new_z[0] = z[0]*z[0] - z[1]*z[1] + c[0]; // z[r]*z[r] - z[i]*z[i] (i.e. a^2 - b^2) + c[r]

  return new_z;
}

// main workhorse, a function to plot next positions for a given point:
void plot_next(float[] point)
{
  int[] position1 = get_position(point); // starting point
  int[] start_position = position1; // save that
  float[] new_point = next_point(point, point); // one iteration, basically
  int[] position2 = get_position(new_point); // x,y for the new point
  int x = start_position[0], y = start_position[1]; // easier access
  int offset = y * width + x;

  img.loadPixels();

  int iterations = 0;
  color c;

  // main calculation loop (skipped recursion for iteration counting.  Could be re-worked.)
  do {
    iterations++; // we already did one
    stroke(0, iterations, 255-iterations); // color for stroke... blue, going green as we go deeper
    line(position1[0], position1[1], position2[0], position2[1]); // this segment
    position1 = position2; // set up for next segment
    new_point = next_point(new_point, point); // compute the new point
    position2 = get_position(new_point); // x,y for new point
  }
  // as long as we haven't exceeded 255, or escaped circle of radius 2 (cheating and not squaring)
  while (iterations < 255 && (abs(new_point[0]) < 4 && abs(new_point[1]) < 4));

  // heuristics for choosing a color for the point to be drawn, once we have iteration count:
  if (iterations <= 10)
    // increasingly (as iterations go up) bright flavor of red:
    c = color(5 + 25 * iterations, 0, 0);
  else if (iterations <= 15)
  {
    // or flavor of magenta:
    int v = 100 + 10 * iterations;
    c = color(v, 0, v);
  } else if (iterations < 100)
    c = color(0, 30 + 2 * iterations, 0); // greens
  else if (iterations < 255)
    c = color(0, 0, iterations); // blues
  else
    c = color(255); // white

  // put this point on the map:
  img.pixels[offset] = c;
  img.updatePixels();

  int alt_x = start_position[0];
  int alt_y = height - start_position[1] - 1;

  if (julia_mode)
  {
    alt_x = width - alt_x;
  }

  img.pixels[alt_y * width + alt_x - 1] = c;
  img.updatePixels();
  redraw_required = true;
}

// draw the zoom window:
void draw_sub_image()
{
  if (!want_sub_image) return;

  int left = zoom_x - 1, top = zoom_y - 1, wdth = zoom_size * zoom_scale;

  // outer box:
  stroke(255);
  rect(left, top, wdth + 1, wdth + 1);

  // actual zoom content:
  zimg.copy(img, mouseX - zoom_size/2, mouseY - zoom_size / 2, zoom_size, zoom_size, 0, 0, wdth, wdth);
  image(zimg, zoom_x, zoom_y);

  // cross-hairs within zoom window:
  stroke(128, 128, 128, 128);
  line(left+zoom_scale, top+wdth/2, left+wdth+zoom_scale, top+wdth/2);
  line(left+wdth/2, top+zoom_scale, left+wdth/2, top+wdth+zoom_scale);
}

// main draw loop, as called by the Processing framework:
void draw()
{
  // do idle processing, only if we haven't moved
  if (last_x == mouseX && last_y == mouseY)
  {
    if (fill_on_idle && idle_y < height / 2)
    {
      // loop stop number (how many points to draw per idle loop)
      // is somewhat arbitrary, and found by experimentation - we want to
      // draw a big enough chunk that this draws quickly when we're truly idle,
      // while also choosing a small enough chunk that the program will still
      // be responsive to mouse movement even if drawing a dense area of the set.
      int iters_per_draw_loop = 440;
      for (int i = 0; i < iters_per_draw_loop; ++i)
      {
        plot_next(point_at(idle_x, idle_y));
        ++idle_x;
        if (idle_x > width)
        {
          idle_x = 0;
          idle_y++;
          // don't bother starting the next line, just let the next loop get it
          // (this avoids having to check bounds for idle_y):
          break;
        }
      }
    }
    // well, unless redraw is required (e.g. for reset, zoom toggle),
    // then re-draw anyway:
    else if (!redraw_required)
      return; // don't waste CPU for non-movement
  }

  // update where we last were:
  last_x = mouseX;
  last_y = mouseY;

  // find the complex-plane point we're at:
  float[] point = point_at(mouseX, mouseY);

  image(img, 0, 0); // lay down the accumulated dots

  // cross-hairs for current point:
  stroke(64, 0, 64, 255);
  draw_grid(point[0], point[1], false);
  fill(0, 0, 0, 0);
  // box around zoom area in main image:
  rect(mouseX - zoom_size/2, mouseY - zoom_size/2, zoom_size, zoom_size);

  // general grids:
  draw_grids();

  // the path at this point:
  plot_next(point);

  // draw the zoom window (after plotting the point):
  draw_sub_image();

  redraw_required = false;
}

// fill a region around the mouse:
void fill_area()
{
  int i, j, x, y;
  float[] pos;

  for (i = 0; i < zoom_size; ++i)
  {
    for (j = 0; j < zoom_size; ++j)
    {
      x = mouseX + i - zoom_size/2;
      y = mouseY + j - zoom_size/2;

      if (x < 0 || x >= width || y < 0 || y >= height)
        continue;

      plot_next(point_at(x, y));
    }
  }

  draw_sub_image();
}

// keyboard controls:
void keyPressed()
{
  switch(key)
  {
  case 'f': // fill a region
  case ' ': // space-bar also, for easy access
    fill_area();
    break;
  case 'i': // idle-mode drawing
    fill_on_idle = !fill_on_idle;
    break;
  case 'j': // julia set mode
    julia_mode = !julia_mode;
    boolean reset = true;

    if (julia_mode) {
      // fresh image each time:
      float[] current_point = point_at(mouseX, mouseY);
      center_re = julia_center_re;
      center_im = julia_center_im;

      // if the cursor hasn't moved, don't reset the image or idle positions:
      if (current_point[0] == julia_point[0] && current_point[1] == julia_point[1]) {
        reset = false;
      }
      julia_point = current_point;
      if (reset) {
        julia_img = createImage(width, height, RGB);
        julia_idle_x = 0;
        julia_idle_y = 0;
      }
      img = julia_img;

      mandel_idle_x = idle_x;
      mandel_idle_y = idle_y;
      idle_x = julia_idle_x;
      idle_y = julia_idle_y;
    } else {
      img = mandel_img;
      center_re = mandel_center_re;
      center_im = mandel_center_im;
      julia_idle_x = idle_x;
      julia_idle_y = idle_y;
      idle_x = mandel_idle_x;
      idle_y = mandel_idle_y;
    }
    img.updatePixels();
    break;
  case 'L': // Lock looping
    noLoop();
    break;
  case 'l': // loop again
    loop();
    break;
  case 'r': // reset
    init_images();
    fill_on_idle = false;
    redraw_required = true;
    break;
  case 'q': // quit
    exit();
  case 'z': // toggle zoom window
    want_sub_image = !want_sub_image;
    redraw_required = true;
    break;
  }
}
