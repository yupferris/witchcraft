extern crate image;

use image::{GenericImage, Pixel};

use std::env;
use std::fs::File;
use std::io::Write;

fn main() {
    let background_input_file_name = env::args().skip(1).nth(0).unwrap();
    let background_output_file_name = env::args().skip(1).nth(1).unwrap();

    let font_input_file_name = env::args().skip(1).nth(2).unwrap();
    let font_output_file_name = env::args().skip(1).nth(3).unwrap();

    let sprites_input_file_name_prefix = env::args().skip(1).nth(4).unwrap();
    let sprites_output_file_name = env::args().skip(1).nth(5).unwrap();

    const WIDTH: usize = 160;
    const HEIGHT: usize = 200;

    const CHAR_WIDTH: usize = 4; // 4 due to multicolor
    const CHAR_HEIGHT: usize = 8;

    const WIDTH_CHARS: usize = WIDTH / CHAR_WIDTH;
    const HEIGHT_CHARS: usize = HEIGHT / CHAR_HEIGHT;

    const SPRITE_WIDTH: usize = 12; // 12 due to multicolor
    const SPRITE_HEIGHT: usize = 20;

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

    let input_color_indices = [
        0, 11, 15, 1
    ];

    // Convert background image
    {
        let input = image::open(background_input_file_name).unwrap();

        let mut output = Vec::new();

        for char_y in 0..HEIGHT_CHARS {
            for char_x in 0..WIDTH_CHARS {
                for y in 0..CHAR_HEIGHT {
                    let mut acc = 0;

                    for x in 0..CHAR_WIDTH {
                        let pixel_x = char_x * CHAR_WIDTH + x;
                        let pixel_y = char_y * CHAR_HEIGHT + y;

                        let pixel = input.get_pixel(pixel_x as _, pixel_y as _).to_rgb();
                        let rgb = ((pixel.data[0] as u32) << 16) | ((pixel.data[1] as u32) << 8) | (pixel.data[2] as u32);
                        let palette_index = palette.iter().position(|x| *x == rgb).unwrap();
                        let color_index = input_color_indices.iter().position(|x| *x == palette_index).unwrap();

                        acc <<= 2;
                        acc |= color_index as u8;
                    }

                    output.push(acc);
                }
            }
        }

        let mut file = File::create(background_output_file_name).unwrap();
        file.write(&output).unwrap();
    }

    // Convert font
    {
        let input = image::open(font_input_file_name).unwrap();

        let mut output = Vec::new();

        for char_y in 0..(input.height() as usize) / CHAR_HEIGHT {
            for char_x in 0..(input.width() as usize) / (CHAR_WIDTH * 2) {
                for y in 0..CHAR_HEIGHT {
                    let mut acc = 0;

                    for x in 0..(CHAR_WIDTH * 2) {
                        let pixel_x = char_x * (CHAR_WIDTH * 2) + x;
                        let pixel_y = char_y * CHAR_HEIGHT + y;

                        let pixel = input.get_pixel(pixel_x as _, pixel_y as _).to_rgb();

                        acc <<= 1;
                        acc |= pixel.data[0] & 0x01;
                    }

                    output.push(acc);
                }
            }
        }

        let mut file = File::create(font_output_file_name).unwrap();
        file.write(&output).unwrap();
    }

    // Convert sprite sheets
    {
        let mut output = Vec::new();

        for sheet in 0..8 {
            let input_file_name = format!("{}{}.png", sprites_input_file_name_prefix, sheet + 1);

            let input = image::open(input_file_name).unwrap();

            for frame in 0..8 {
                for sprite_y in 0..SPRITE_HEIGHT {
                    let mut acc = 0;

                    for sprite_x in 0..SPRITE_WIDTH {
                        let pixel_x = frame * SPRITE_WIDTH + sprite_x;
                        let pixel_y = sprite_y;

                        let pixel = input.get_pixel(pixel_x as _, pixel_y as _).to_rgb();
                        let rgb = ((pixel.data[0] as u32) << 16) | ((pixel.data[1] as u32) << 8) | (pixel.data[2] as u32);
                        let palette_index = palette.iter().position(|x| *x == rgb).unwrap();
                        let color_index = input_color_indices.iter().position(|x| *x == palette_index).unwrap();

                        acc <<= 2;
                        acc |= color_index as u32;
                    }

                    output.push((acc >> 16) as u8);
                    output.push((acc >> 8) as u8);
                    output.push(acc as u8);
                }

                // Output last dummy row (sprites are actually 21 pixels high)
                output.push(0x00);
                output.push(0x00);
                output.push(0x00);

                // Final padding byte so each sprite is 64 bytes exactly
                output.push(0x00);
            }
        }

        let mut file = File::create(sprites_output_file_name).unwrap();
        file.write(&output).unwrap();
    }
}
