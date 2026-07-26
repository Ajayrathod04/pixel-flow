clc;
clear;
close all;

% ================= INPUT IMAGE =================
input_pixels = [10 20 30 40 ...
                50 60 70 80 ...
                90 100 110 120 ...
                130 140 150 160];

% ================= FPGA OUTPUT (FROM SIMULATION) =================
% (Include pipeline values exactly as seen)
output_pixels = [0 0 0 0 ...
                 20 100 270 530 ...
                 850 1290 1560 1920 ...
                 2280 2640 3000 3360];

% ================= IMAGE SIZE =================
M = 4;  % rows
N = 4;  % columns

% ================= ORIGINAL IMAGE =================
img_in = reshape(input_pixels, [N M])';

% ================= REMOVE PIPELINE DELAY =================
valid_out = output_pixels(5:end);   % remove first 4 zeros

% Fill remaining values to make 16 elements
valid_out = [valid_out repmat(valid_out(end), 1, 4)];

% ================= RESHAPE FILTERED IMAGE =================
img_out = reshape(valid_out, [N M])';

% ================= NORMALIZATION (VERY IMPORTANT) =================
% Option 1: Scale to 0–255
img_out_norm = uint8(255 * mat2gray(img_out));

% Option 2 (alternative): divide by coefficient sum (6)
% img_out_norm = uint8(img_out / 6);

% ================= DISPLAY =================
figure;

subplot(1,2,1);
imshow(uint8(img_in));
title('Original Image');

subplot(1,2,2);
imshow(img_out_norm);
title('Filtered Image (Normalized)');
