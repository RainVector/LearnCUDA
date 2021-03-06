#include "kernal.cuh"
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STBI_MSC_SECURE_CRT
#include <stb_image_write.h>
#include <iostream>
__global__ void HW1(unsigned char* grayImage, uchar3* rgbImage)
{
	int threadId = blockIdx.x * blockDim.x + threadIdx.x;
	//printf("trheadIdx is: %d \n", threadId);
	float color = .299f * rgbImage[threadId].x + .587f * rgbImage[threadId].y + .114f *  rgbImage[threadId].z;
	grayImage[threadId] = color;
}

void color2gray(imageInfo* ii, unsigned char* h_grayImage)
{
	uchar3 *d_rgbImage;
	unsigned char *d_grayImage;

	int numPixels = ii->resolution;
	// allocate memory on GPU for picture
	checkCudaErrors(cudaMalloc((void**)&d_rgbImage, numPixels * sizeof(uchar3)));
	checkCudaErrors(cudaMalloc((void**)&d_grayImage, numPixels * sizeof(unsigned char)));
	//make sure no memory is left laying around
	checkCudaErrors(cudaMemset(d_grayImage, 0, numPixels * sizeof(unsigned char)));
	// cpy CPU data to GPU data
	checkCudaErrors(cudaMemcpy(d_rgbImage, ii->image, numPixels * sizeof(uchar3), cudaMemcpyHostToDevice));

	// launch the kernel
	HW1<<<ii->height, ii->width >>> (d_grayImage, d_rgbImage);
	cudaError_t cudaStatus;
	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "Kernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
	}
	cudaStatus =  cudaMemcpy(h_grayImage, d_grayImage, numPixels * sizeof(unsigned char), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
	}
	//checkCudaErrors(cudaMemcpy(h_out, d_out, resolution, cudaMemcpyDeviceToHost));
	checkCudaErrors(cudaFree(d_rgbImage));
	checkCudaErrors(cudaFree(d_grayImage));
}

bool readImage(const char * filename, imageInfo* ii)
{
	int width, height, channels_in_file;
	ii->image = stbi_load(filename, &width, &height, &channels_in_file, 0);
	if (ii->image == NULL)
	{
		std::cerr << "Failed to load Image at: " << filename << std::endl;
		return false;
	}
	ii->height = height;
	ii->width = width;
	ii->resolution = height * width;
	return true;
}

void writeImage(const char* filename, imageInfo* ii, const unsigned char *h_grayImage)
{
	int res = stbi_write_jpg(filename, ii->width, ii->height, 1, h_grayImage, 0);
	if (res == 0)
	{
		std::cout << "Failed to write image file" << std::endl;
		return;
	}
	std::cout << "Write Image Successfully to: " << filename << std::endl;
}

void exec(const char * inputFile, const char * outputFile)
{
	// 读取图片
	imageInfo* ii = new imageInfo();
	bool res = readImage(inputFile, ii);
	if (!res) return;
	// 将图片灰度化
	unsigned char *h_out = (unsigned char*)malloc(sizeof(unsigned char) * ii->height * ii->width);
	if (h_out == NULL)
	{
		std::cout << "Failed to malloc h_out space" << std::endl;
		return;
	}
	color2gray(ii,h_out);
	// 保存灰度图片
	writeImage(outputFile, ii, h_out);
	// 释放空间
	free(ii);
	free(h_out);
	h_out = NULL;
	//stbi_image_free(ii->image); 在free ii的时候已经将image对应空间释放，这里不需要重复释放，不然会引发bug
}