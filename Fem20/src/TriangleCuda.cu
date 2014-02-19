﻿#include <algorithm>    // std::max
#include "cuda.h"
#include "cuda_runtime.h"
#include "../Headers/Common.h"
#include "../Headers/hemi.h"
#include "../Headers/array.h"
#include "math.h"

#define DEBUG

__device__ void d_quadrAngleType(ComputeParameters& p, Triangle& firstT,
								 Triangle& secondT, double* x, double* y) 
{
	double alpha[2], betta[2], gamma[2], theta[2]; //   -  Vertexes of square. Anticlockwise order from left bottom vertex.
	double u, v;                           //   -  Items of velocity components.
	double alNew[2], beNew[2], gaNew[2], thNew[2]; //   -  New positions of vertexes. Vertexes of quadrangle.
	double vectAlGa[2], vectBeTh[2]; //   -  Vectors: 1) from "alNew" to "gaNew" 2) from "beNew" to "thNew".
	double a_1LC, b_1LC, c_1LC; //   -  a_1LC * x  +  b_1LC * y  = c_1LC. Line equation through "alNew" and "gaNew".
	double a_2LC, b_2LC, c_2LC; //   -  a_2LC * x  +  b_2LC * y  = c_2LC. Line equation through "beNew" and "thNew".
	double AcrP[2];                            //   -  Across point of two lines
	double vectAlBe[2]; //   -  Vectors for computing vertexes sequence order by vector production.
	double vectAlTh[2]; //   -  Vectors for computing vertexes sequence order by vector production.
	double vectBeGa[2]; //   -  Vectors for computing vertexes sequence order by vector production.
	double vectBeAl[2]; //   -  Vectors for computing vertexes sequence order by vector production.
	double vectProdOz;                      //   -  Z-axis of vector production.
	double scalProd;                   //   -  Scalar production of two vectors.

	//   1. First of all let's compute coordinates of square vertexes.
	alpha[0] = (x[p.i - 1] + x[p.i]) / 2.;
	betta[0] = (x[p.i + 1] + x[p.i]) / 2.;
	gamma[0] = (x[p.i + 1] + x[p.i]) / 2.;
	theta[0] = (x[p.i - 1] + x[p.i]) / 2.;

	alpha[1] = (y[p.j] + y[p.j - 1]) / 2.;
	betta[1] = (y[p.j] + y[p.j - 1]) / 2.;
	gamma[1] = (y[p.j] + y[p.j + 1]) / 2.;
	theta[1] = (y[p.j] + y[p.j + 1]) / 2.;

	//   2. Now let's compute new coordinates on the previous time level of alpha, betta, gamma, theta points.
	//  alNew.

	//u = d_u_function_quadrangle(p.b, alpha[0], alpha[1]);
	u = p.b * alpha[1] * (1. - alpha[1]) * (C_pi_device / 2. + atan(alpha[0]));

	v = atan(
		(alpha[0] - p.lb) * (alpha[0] - p.rb) * (1. + p.currentTimeLevel * p.tau) / 10. * (alpha[1] - p.ub)
		* (alpha[1] - p.bb));
	alNew[0] = alpha[0] - p.tau * u;
	alNew[1] = alpha[1] - p.tau * v;

	//  beNew.
	//u = d_u_function_quadrangle(p.b, betta[0], betta[1]);
	u = p.b * betta[1] * (1. - betta[1]) * (C_pi_device / 2. + atan(betta[0]));
	v = atan(
		(betta[0] - p.lb) * (betta[0] - p.rb) * (1. + p.currentTimeLevel * p.tau) / 10. * (betta[1] - p.ub)
		* (betta[1] - p.bb));
	beNew[0] = betta[0] - p.tau * u;
	beNew[1] = betta[1] - p.tau * v;

	//  gaNew.

	//u = d_u_function_quadrangle(p.b, gamma[0], gamma[1]);
	u = p.b * gamma[1] * (1. - gamma[1]) * (C_pi_device / 2. + atan(gamma[0]));
	v = atan(
		(gamma[0] - p.lb) * (gamma[0] - p.rb) * (1. + p.currentTimeLevel * p.tau) / 10. * (gamma[1] - p.ub)
		* (gamma[1] - p.bb));
	gaNew[0] = gamma[0] - p.tau * u;
	gaNew[1] = gamma[1] - p.tau * v;

	//  thNew.
	//u = d_u_function_quadrangle(p.b, theta[0], theta[1]);
	u = p.b * theta[1] * (1. - theta[1]) * (C_pi_device / 2. + atan(theta[0]));
	v =  atan(
		(theta[0] - p.lb) * (theta[0] - p.rb) * (1. + p.currentTimeLevel * p.tau) / 10. * (theta[1] - p.ub)
		* (theta[1] - p.bb));
	thNew[0] = theta[0] - p.tau * u;
	thNew[1] = theta[1] - p.tau * v;

	//   3.a Let's compute coefficients of first line betweeen "alNew" and "gaNew" points.
	//   a_1LC * x  +  b_1LC * y  = c_1LC.

	vectAlGa[0] = gaNew[0] - alNew[0];
	vectAlGa[1] = gaNew[1] - alNew[1];
	a_1LC = vectAlGa[1];
	b_1LC = -vectAlGa[0];
	c_1LC = vectAlGa[1] * alNew[0] - vectAlGa[0] * alNew[1];

	//   3.b Let's compute coefficients of second line betweeen "beNew" and "thNew" points.
	//   a_2LC * x  +  b_2LC * y  = c_2LC.

	vectBeTh[0] = thNew[0] - beNew[0];
	vectBeTh[1] = thNew[1] - beNew[1];
	a_2LC = vectBeTh[1];
	b_2LC = -vectBeTh[0];
	c_2LC = vectBeTh[1] * beNew[0] - vectBeTh[0] * beNew[1];

	//   4. Let's compute coordinates of across point of this two lines.
	//   Are lines parallel?

	if (fabs(b_1LC * a_2LC - b_2LC * a_1LC) < 1.e-14) 
	{
		//   Not checked.

		//   Pseudo case. Anyway I need to compute some values.

		//   First triangle.

		firstT.first[0] = alNew[0];
		firstT.first[1] = alNew[1];
		firstT.second[0] = beNew[0];
		firstT.second[1] = beNew[1];
		firstT.third[0] = gaNew[0];
		firstT.third[1] = gaNew[1];

		//   Vertices of second triagle depends on scalar production.

		vectAlGa[0] = gaNew[0] - alNew[0];
		vectAlGa[1] = gaNew[1] - alNew[1];
		vectBeTh[0] = thNew[0] - beNew[0];
		vectBeTh[1] = thNew[1] - beNew[1];

		scalProd = vectAlGa[0] * vectBeTh[0] + vectAlGa[1] * vectBeTh[1];
		secondT.first[0] = beNew[0];
		secondT.first[1] = beNew[1];
		secondT.second[0] = thNew[0];
		secondT.second[1] = thNew[1];

		if (scalProd >= 0.) 
		{
			secondT.third[0] = gaNew[0];
			secondT.third[1] = gaNew[1];
		}

		if (scalProd < 0.) 
		{
			secondT.third[0] = alNew[0];
			secondT.third[1] = alNew[1];
		}

		return;
	}

	AcrP[0] = (b_1LC * c_2LC - b_2LC * c_1LC) / (b_1LC * a_2LC - b_2LC * a_1LC);
	AcrP[1] = (a_1LC * c_2LC - a_2LC * c_1LC)
		/ (-b_1LC * a_2LC + b_2LC * a_1LC);

	if (((beNew[1] - AcrP[1]) * (thNew[1] - AcrP[1])) > 0.) 
	{

		if (((alNew[0] - AcrP[0]) * (gaNew[0] - AcrP[0])) > 0.)
		{

			firstT.first[0] = alNew[0];
			firstT.first[1] = alNew[1];
			firstT.second[0] = beNew[0];
			firstT.second[1] = beNew[1];
			firstT.third[0] = gaNew[0];
			firstT.third[1] = gaNew[1];

			//   Second triangle.

			secondT.first[0] = beNew[0];
			secondT.first[1] = beNew[1];
			secondT.second[0] = thNew[0];
			secondT.second[1] = thNew[1];

			//   Third vertex computing...

			vectAlGa[0] = gaNew[0] - alNew[0];
			vectAlGa[1] = gaNew[1] - alNew[1];

			vectBeTh[0] = thNew[0] - beNew[0];
			vectBeTh[1] = thNew[1] - beNew[1];

			scalProd = vectAlGa[0] * vectBeTh[0] + vectAlGa[1] * vectBeTh[1];

			if (scalProd >= 0.) {
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];
			}

			if (scalProd < 0.) {
				secondT.third[0] = alNew[0];
				secondT.third[1] = alNew[1];
			}

			return;

		} //   "if(  (  (alNew[0] - AcrP[0])*(gaNew[0] - AcsP[0])  )  >  0.  )".

		//   Second criterion. Second case.

		if (((alNew[0] - AcrP[0]) * (gaNew[0] - AcrP[0])) <= 0.)
		{
			vectAlBe[0] = beNew[0] - alNew[0];
			vectAlBe[1] = beNew[1] - alNew[1];
			vectAlTh[0] = thNew[0] - alNew[0];
			vectAlTh[1] = thNew[1] - alNew[1];

			vectProdOz = vectAlBe[0] * vectAlTh[1] - vectAlBe[1] * vectAlTh[0];

			if (vectProdOz < 0.) 
			{
				//   The vertex "beNew" is NOT in triangle "alNew - gaNew - thNew".
				//   Pseudo case. Anyway I need to find some solution. So

				firstT.first[0] = alNew[0];
				firstT.first[1] = alNew[1];
				firstT.second[0] = beNew[0];
				firstT.second[1] = beNew[1];
				firstT.third[0] = thNew[0];
				firstT.third[1] = thNew[1];

				//   Second triangle.

				secondT.first[0] = beNew[0];
				secondT.first[1] = beNew[1];
				secondT.second[0] = thNew[0];
				secondT.second[1] = thNew[1];
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];

				return;
			}

			if (vectProdOz >= 0.) 
			{
				//  It's all write. We have a good concave quadrangle.
				//   Now let's compute all vertices which I need.
				//   First triangle.
				firstT.first[0] = alNew[0];
				firstT.first[1] = alNew[1];
				firstT.second[0] = beNew[0];
				firstT.second[1] = beNew[1];
				firstT.third[0] = thNew[0];
				firstT.third[1] = thNew[1];

				//   Second triangle.

				secondT.first[0] = beNew[0];
				secondT.first[1] = beNew[1];
				secondT.second[0] = thNew[0];
				secondT.second[1] = thNew[1];
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];

				return;
			}

		} //   "if(  (  (alNew[0] - AcsP[0])*(gaNew[0] - AcsP[0])  )  <=  0.  )".   //   Last second case of second criterion.

	} //   end of "if (  (  (beNew[1] - AcrP[1])*(thNew[1] - AcrP[1])  )  >  0.  )"

	//  Now let's consider SECOND case 5.b "(  (beNew[1] - AcrP[1])*(thNew[1] - AcrP[1])  )  <= 0."

	if (((beNew[1] - AcrP[1]) * (thNew[1] - AcrP[1])) <= 0.) 
	{
		if (((alNew[0] - AcrP[0]) * (gaNew[0] - AcrP[0])) > 0.) 
		{
			//  It means the across point IS NOT between "alNew" and "gaNew" vertices by Ox-axis?

			//   O.K. the quadrangle IS NOT CONVEX. Is it concave or pseudo? Third criterion.

			vectBeGa[0] = gaNew[0] - beNew[0];
			vectBeGa[1] = gaNew[1] - beNew[1];
			vectBeAl[0] = alNew[0] - beNew[0];
			vectBeAl[1] = alNew[1] - beNew[1];

			vectProdOz = vectBeGa[0] * vectBeAl[1] - vectBeGa[1] * vectBeAl[0];

			if (vectProdOz >= 0.)
			{

				//   The quadrangle is concave. First triangle.

				firstT.first[0] = alNew[0];
				firstT.first[1] = alNew[1];
				firstT.second[0] = beNew[0];
				firstT.second[1] = beNew[1];
				firstT.third[0] = gaNew[0];
				firstT.third[1] = gaNew[1];

				//   Second triangle.

				secondT.first[0] = alNew[0];
				secondT.first[1] = alNew[1];
				secondT.second[0] = thNew[0];
				secondT.second[1] = thNew[1];
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];

				return;
			}

			if (vectProdOz < 0.) 
			{

				//   This concave quadrangle do has NO write anticlockwise vertices sequence order. It's pseudo.

				firstT.first[0] = alNew[0];
				firstT.first[1] = alNew[1];
				firstT.second[0] = beNew[0];
				firstT.second[1] = beNew[1];
				firstT.third[0] = gaNew[0];
				firstT.third[1] = gaNew[1];

				//   Second triangle.

				secondT.first[0] = alNew[0];
				secondT.first[1] = alNew[1];
				secondT.second[0] = thNew[0];
				secondT.second[1] = thNew[1];
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];

				return;
			}
		} //   end of "if(  (  (alNew[0] - AcrP[0])*(gaNew[0] - AcsP[0])  )  >  0.  )". First case of second criterion.

		//   Second criterion. Second case.

		if (((alNew[0] - AcrP[0]) * (gaNew[0] - AcrP[0])) <= 0.) {
			//   O.K. the quadrangle is convex. Is it has the same vertices sequence order.

			vectAlBe[0] = beNew[0] - alNew[0];

			vectAlBe[1] = beNew[1] - alNew[1];

			vectAlTh[0] = thNew[0] - alNew[0];

			vectAlTh[1] = thNew[1] - alNew[1];

			vectProdOz = vectAlBe[0] * vectAlTh[1] - vectAlBe[1] * vectAlTh[0];

			if (vectProdOz >= 0.) {

				//   Convex quadrangle DO HAS WRITE anticlockwise vertices sequence order. It's convex.

				firstT.first[0] = alNew[0];
				firstT.first[1] = alNew[1];
				firstT.second[0] = beNew[0];
				firstT.second[1] = beNew[1];
				firstT.third[0] = gaNew[0];
				firstT.third[1] = gaNew[1];

				//   Second triangle.

				secondT.first[0] = alNew[0];
				secondT.first[1] = alNew[1];
				secondT.second[0] = thNew[0];
				secondT.second[1] = thNew[1];
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];

				return;
			}

			if (vectProdOz < 0.) {

				firstT.first[0] = alNew[0];
				firstT.first[1] = alNew[1];
				firstT.second[0] = beNew[0];
				firstT.second[1] = beNew[1];
				firstT.third[0] = gaNew[0];
				firstT.third[1] = gaNew[1];
				secondT.first[0] = alNew[0];
				secondT.first[1] = alNew[1];
				secondT.second[0] = thNew[0];
				secondT.second[1] = thNew[1];
				secondT.third[0] = gaNew[0];
				secondT.third[1] = gaNew[1];
				return;
			}
		}
	}

}

__global__ void get_angle_type_kernel(ComputeParameters p, Triangle* f, Triangle* s, double *x, double *y, 
									  int length, int x_length, int offset) {
										  const int element_offset = hemiGetElementOffset();
										  const int stride = hemiGetElementStride();

										  for (int opt = element_offset; opt < length; opt += stride) {
											  p.i = (opt % x_length + 1) ;
											  p.j = (opt / x_length + 1) + (int) (offset / x_length);
											  d_quadrAngleType(p, f[opt], s[opt], x, y);
										  }
}

void get_triangle_type(TriangleResult* result, ComputeParameters p, int gridSize, int blockSize) 
{
	int d_xy_size(0), offset(0), length(0), copy_offset(0), tr_size(0);
	Triangle *first = NULL, *second = NULL;
	double *x = NULL, *y = NULL;
	d_xy_size = sizeof(double) * p.get_chunk_size();
	cudaMallocManaged(&x, d_xy_size);
	cudaMallocManaged(&y, d_xy_size);

	for (p.reset_time_counter(); p.can_iterate_over_time_level(); p.inc_time_level())
	{
		for (int i = 0; i < p.get_part_count(); ++i) 
		{
			offset = i * p.get_chunk_size();
			length = std::min(p.get_inner_chuck_size(), p.size  - offset);
			copy_offset = i * p.get_inner_chuck_size();
			tr_size = sizeof(Triangle) * length;
			
			cudaMallocManaged(&first, tr_size);
			cudaMallocManaged(&second, tr_size);
			
			memcpy(x, p.x, d_xy_size);
			memcpy(y, p.y, d_xy_size);

			get_angle_type_kernel<<<gridSize, blockSize>>>(p, first, second, x, y, length, result->x_length, p.get_inner_chuck_size() * i);
			cudaDeviceSynchronize();

			memcpy(&result->f[copy_offset], first, tr_size);
			memcpy(&result->s[copy_offset], second, tr_size);
			
			cudaFree(first);
			cudaFree(second);
		}
	}
	cudaFree(x);
	cudaFree(y);
	cudaDeviceReset();
}

