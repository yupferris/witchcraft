extern crate image;

use image::{GenericImage, Pixel};

use std::env;
use std::fs::File;
use std::io::Write;

fn main() {
    let background_input_file_name = env::args().skip(1).nth(0).unwrap();
    let background_output_file_name = env::args().skip(1).nth(1).unwrap();

    const WIDTH: usize = 160;
    const HEIGHT: usize = 200;

    const CHAR_WIDTH: usize = 4; // 4 due to multicolor
    const CHAR_HEIGHT: usize = 8;

    const WIDTH_CHARS: usize = WIDTH / CHAR_WIDTH;
    const HEIGHT_CHARS: usize = HEIGHT / CHAR_HEIGHT;

    let palette = [
        0x000000,
        0xffffff,
        0x883932,
        0x67b6bd,
        0x8b3f96,
        0x55a049,
        0x40318d,
        0xbfce72,
        0x8b5429,
        0x574200,
        0xb86962,
        0x505050,
        0x787878,
        0x94e089,
        0x7869c4,
        0x9f9f9f,
    ];

    let background_color_indices = [
        0, 11, 15, 1
    ];

    let background_image = image::open(background_input_file_name).unwrap();

    let mut output = Vec::new();

    for char_y in 0..HEIGHT_CHARS {
        for char_x in 0..WIDTH_CHARS {
            for y in 0..CHAR_HEIGHT {
                let mut c = 0;

                for x in 0..CHAR_WIDTH {
                    let pixel_x = char_x * CHAR_WIDTH + x;
                    let pixel_y = char_y * CHAR_HEIGHT + y;

                    let pixel = background_image.get_pixel(pixel_x as _, pixel_y as _).to_rgb();
                    let rgb = ((pixel.data[0] as u32) << 16) | ((pixel.data[1] as u32) << 8) | (pixel.data[2] as u32);
                    let palette_index = palette.iter().position(|x| *x == rgb).unwrap();
                    let color_index = background_color_indices.iter().position(|x| *x == palette_index).unwrap();

                    c <<= 2;
                    c |= color_index as u8;
                }

                output.push(c);
            }
        }
    }

    let mut file = File::create(background_output_file_name).unwrap();
    file.write(&output).unwrap();
}
