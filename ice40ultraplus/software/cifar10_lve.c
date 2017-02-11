#include "neural.h"
#include "flash_dma.h"
#include "time.h"
#include "ovm7692.h"
#include "base64.h"
#include "sccb.h"

void vbx_flash_dma(vbx_word_t *v_dst, int flash_byte_offset, const int bytes) {
	flash_dma_trans(flash_byte_offset, (void*)v_dst, bytes);
	while(!flash_dma_done());
}


void vbx_flash_dma_async(vbx_word_t *v_dst, int flash_byte_offset, const int bytes) {
	flash_dma_trans(flash_byte_offset, (void*)v_dst, bytes);
}


void vbx_pool(vbx_word_t *v_out, vbx_word_t *v_pool, const int width, const int height) {
    int i;
    the_lve.stride = 2;
    vbx_set_vl(width*height/2);
    vbx(VVW, VSLT, v_pool, v_out, v_out+1);
    vbx(VVW, VCMV_NZ, v_out, v_out+1, v_pool);
    for (i = 0; i < width*height/2; i++) {
	v_out[i] = v_out[i*2];
    }

    the_lve.stride = 1;
    vbx_set_vl(width/2);
    for (i = 0; i < height/2; i++) {
	vbx(VVW, VSLT, v_pool, v_out + (i*2) * width/2, v_out + (i*2+1) * width/2);
	vbx(VVW, VCMV_NZ, v_out + (i*2) * width/2, v_out + (i*2+1) * width/2, v_pool);
	vbx(SVW, VOR, v_out + i * width/2, 0, v_out + (i*2) * width/2);
    }
}


void vbx_relu(vbx_word_t* v_out, vbx_word_t* v_flag) {
    vbx(SVW, VSLT, v_flag, 0, v_out);
    vbx(VVW, VMUL, v_out, v_flag, v_out);
}


void vbx_unpack_weights(vbx_word_t *v_unpacked, vbx_word_t *v_packed, const int size)
{
  int b;
  vbx_set_vl(size/32);
  for (b = 0; b < 32; b++) {
    vbx(SVWU, VAND, v_unpacked + b*(size/32), 1<<(b), v_packed);
    vbx(SVW, VCMV_NZ, v_unpacked + b*(size/32), 1, v_unpacked + b*(size/32));
    vbx(SVW, VCMV_Z, v_unpacked + b*(size/32), -1, v_unpacked + b*(size/32));
  }
}


//scales are prescaled by 1 << 32 aka need to be less than 0.5/-0.5 else prescale by less and scale v_out
void dense_lve(vbx_word_t *v_out, vbx_word_t *v_in, dense_layer_t *layer)
{
    int x;
    vbx_word_t *v_biases  = v_out + layer->outputs*1;
    vbx_word_t *v_scales  = v_out + layer->outputs*2;
    vbx_word_t *v_weights = v_out + layer->outputs*3;
    vbx_word_t *v_buf0 = v_weights + layer->inputs*1;
    vbx_word_t *v_buf1 = v_weights + layer->inputs*2;

    vbx_word_t *v_dma[] = {v_buf0, v_buf1};

    vbx_word_t *v_relu = v_in;

    // packed into 32x
    int buf = 0;
    vbx_flash_dma(v_dma[buf], layer->weights, layer->inputs/32*sizeof(vbx_word_t));

    for (x = 0; x < layer->outputs; x++) {
	vbx_flash_dma_async(v_dma[!buf], layer->weights + (x+1)*layer->inputs/32, layer->inputs/32*sizeof(vbx_word_t));

	vbx_unpack_weights(v_weights, v_dma[buf], layer->inputs);

	vbx_set_vl(layer->inputs);
	vbx_acc(VVW, VMUL, v_out + x, v_in, v_weights);

	while(!flash_dma_done());
	buf = !buf;
    }

    vbx_set_vl(layer->outputs);

    vbx_flash_dma(v_biases, layer->biases, layer->outputs*sizeof(vbx_word_t));
    vbx(VVW, VADD, v_out, v_out, v_biases);

    if (layer->scale) {
	vbx_flash_dma(v_scales, layer->scales, layer->outputs*sizeof(vbx_word_t));
	vbx(VVW, VMULH, v_out, v_out, v_scales);
    }

    if (layer->activation_type == RELU) {
	vbx_relu(v_out, v_relu);
    }
}


void vbx_convolve_ci(vbx_word_t *v_out, vbx_ubyte_t *v_in, vbx_word_t *v_map, const int m, const int n, const short weights)
{
    int y, x;

    vbx_set_vl(1);
    vbx(SVW, VCUSTOM1, 0, weights, 0);

    vbx_set_vl(m+2);
    the_lve.stride = m+2+2;

    for(x=0; x<n; x++){
	vbx(VVWB, VCUSTOM2, v_map + x, (vbx_byte_t*)v_in + x, (vbx_byte_t*)v_in + x + 4);
    }

    vbx_set_vl(n);
    the_lve.stride = 1;
    for(y=0; y<m; y++){
      vbx(VVW, VADD, v_out+ y*n, v_out + y*n, v_map + y*(n+2+2));
    }
}


void vbx_zeropad_ci(vbx_ubyte_t *v_out, vbx_word_t *v_pad, vbx_word_t *v_in, const int m, const int n)
{
    int y;

    // zero top and bottom
    vbx_set_vl(n+2+2);
    vbx(SVW, VAND, v_pad, 0, v_pad);
    vbx(VVBW, VCUSTOM0, (vbx_byte_t*)v_out + (0)*(n+2+2), v_pad, 0);
    vbx(VVBW, VCUSTOM0, (vbx_byte_t*)v_out + (m+1)*(n+2+2), v_pad, 0);

    // move in rows
    for (y = 0; y < m; y++) {
	vbx_set_vl(n);
	vbx(SVW, VOR, v_pad + 1, 0, v_in + y*n);
	vbx_set_vl(n+2+2);
	vbx(VVBW, VCUSTOM0, (vbx_byte_t*)v_out + (y+1)*(n+2+2), v_pad, 0);
    }
}


void vbx_zeropad_input(vbx_ubyte_t *v_out, vbx_ubyte_t *v_in, const int m, const int n)
{
    // zero map
    int j, i;
    for(j = 0; j < m+2; j++) {
      for(i = 0; i < n+2+2; i++) {
	v_out[j*(n+2+2)+i] = 0;
      }
    }
    // move in rows
    for (j = 0; j < m; j++) {
      for(i = 0; i < n; i++) {
	v_out[(j+1)*(n+2+2) + i+1] = v_in[j*n+i];
      }
    }
}


// takes in padded inputs
void convolution_ci_lve(vbx_ubyte_t *v_outb, vbx_ubyte_t *v_inb, convolution_layer_t *layer, const int debug)
{
    int c, k, m = layer->m, n = layer->n, m0 = m, n0 = n;
    if (layer->maxpool) {
	m0 = m/2; n0 = n/2;
    }

    // assumes 128K scratch
    vbx_word_t *v_map = (vbx_word_t*)(SCRATCHPAD_BASE + 110*1024);
    vbx_word_t *v_tmp = (vbx_word_t*)(SCRATCHPAD_BASE + 116*1024);
    vbx_word_t *v_dma0 = (vbx_word_t*)(SCRATCHPAD_BASE + 124*1024);
    vbx_word_t *v_dma1 = (vbx_word_t*)(SCRATCHPAD_BASE + 126*1024);
    vbx_word_t *v_dma[] = {v_dma0, v_dma1};
    vbx_uhalf_t *v_weights;

    int buf = 0;
    int dma_size = 2*4 + layer->channels*2;
    int dma_pad = dma_size % 4;

    vbx_flash_dma(v_dma[buf], layer->weights, dma_size+dma_pad);

    for (k = 0; k < layer->kernels; k++) {
	v_weights = (vbx_uhalf_t*)(v_dma[buf] + 2);
	if (k < layer->kernels-1) {
	  vbx_flash_dma_async(v_dma[!buf], layer->weights + (k+1)*dma_size, dma_size+dma_pad);
	}

	// set kernel bias
	vbx_set_vl(n*m);
	vbx(SVW, VAND, v_map, 0, v_map);
	vbx(SVW, VOR, v_map, v_dma[buf][0], v_map);

	for (c = 0; c < layer->channels; c++) {
	    vbx_convolve_ci(v_map, v_inb + c*(m+2)*(n+4), v_tmp, m, n, v_weights[c]);
	}

	if (layer->maxpool) {
	    vbx_pool(v_map, v_tmp, m, n);
	}

	vbx_set_vl(m0*n0);
	if (layer->scale) {
	    vbx(SVW, VMULH, v_map, v_dma[buf][1], v_map);
	}

	if (layer->activation_type == RELU) {
	    vbx_relu(v_map, v_tmp);
	}
	if (layer->zeropad_output) {
	  vbx_zeropad_ci(v_outb+(k*(n0+4)*(m0+2)), v_tmp, v_map, m0, n0);
	} else {
	  vbx_set_vl(m0*n0);
	  vbx(SVW, VOR, (vbx_word_t*)v_outb+(k*n0*m0), 0, v_map);
	}

	if (k < layer->kernels-1) {
	  while(!flash_dma_done());
	}
	buf = !buf;
    }
}

//expects 3 padded 32x32 byte images at SCRATCHPAD_BASE+80*1024, output @ SCRATCHPAD_BASE
void run_network(const int verbose)
{
  int i, j, m, n;
  int errors, count;

  vbx_ubyte_t* v_outb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);
  vbx_ubyte_t* v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024);

  m = 32, n = 32;

  convolution_layer_t conv;
  conv.layer_type = CONV;
  conv.activation_type = RELU;
  conv.m = m;
  conv.n = n;
  conv.channels = 3;
  conv.kernels = 64;
  conv.scale = 1;
  conv.scale_multiply = 0;
  conv.weights = 3072;
  conv.zeropad_output = 1;
  conv.maxpool = 0;

  if (verbose) printf("c0\r\n");
  convolution_ci_lve(v_outb, v_padb, &(conv), 0);
  m = 32, n = 32;

#if 0
  errors = 0;
  count = 0;
  for (j = 0; j < conv.kernels; j++) {
    vbx_flash_dma((vbx_word_t*)(v_padb), 3968+(j*m*n), (m*n)*sizeof(vbx_ubyte_t));
    vbx_zeropad_input(v_padb+m*n, v_padb, m, n);
#if 1
    vbx_set_vl((m+2)*(n+4)/4);
    vbx(SVW, VOR, v_outb+(n+4)*((m+2)*j), 0, v_padb+m*n);
#else
    for (i = 0; i < (n+4)*(m+2); i++) {
      count++;
      int diff = v_outb[j*(n+4)*(m+2)+i] - v_padb[(m*n)+i];
      if (diff < -1 || diff > 1) {
	if (errors < 40) {
	  printf("(%d,%d,%d)\t%d != %d\r\n", j, i/(n+4), i%(n+4), v_outb[j*(n+4)*(m+2)+i], v_padb[(m*n)+i]);
	}
	errors++;
      }
    }
#endif
  }
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);
  v_outb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024);

  conv.m = m;
  conv.n = n;
  conv.channels = 64;
  conv.kernels = 64;
  conv.weights = 69504;
  conv.maxpool = 1;

  if (verbose) printf("c1\r\n");
  convolution_ci_lve(v_outb, v_padb, &(conv), 0);
  m = 16, n = 16;

#if 0
  errors = 0;
  count = 0;
  for (j = 0; j < conv.kernels; j++) {
    vbx_flash_dma((vbx_word_t*)(v_padb), 78208+(j*m*n), (m*n)*sizeof(vbx_ubyte_t));
    vbx_zeropad_input(v_padb+m*n, v_padb, m, n);
#if 1
    vbx_set_vl((m+2)*(n+4)/4);
    vbx(SVW, VOR, v_outb+(n+4)*((m+2)*j), 0, v_padb+m*n);
#else
    for (i = 0; i < (n+4)*(m+2); i++) {
      count++;
      int diff = v_outb[j*(n+4)*(m+2)+i] - v_padb[(m*n)+i];
      if (diff < -4 || diff > 4) {
	if (errors < 10) {
	  printf("(%d,%d,%d)\t%d != %d\r\n", j, i/(n+4), i%(n+4), v_outb[j*(n+4)*(m+2)+i], v_padb[(m*n)+i]);
	}
	errors++;
      }
    }
#endif
  }
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_outb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);
  v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024);

  conv.m = m;
  conv.n = n;
  conv.channels = 64;
  conv.kernels = 128;
  conv.weights = 94592;
  conv.maxpool = 0;

  if (verbose) printf("c2\r\n");
  convolution_ci_lve(v_outb, v_padb, &(conv), 0);
  m = 16, n = 16;

#if 0
  errors = 0;
  count = 0;
  for (j = 0; j < conv.kernels; j++) {
    vbx_flash_dma((vbx_word_t*)(v_padb), 112000+(j*m*n), (m*n)*sizeof(vbx_ubyte_t));
    vbx_zeropad_input(v_padb+m*n, v_padb, m, n);
#if 0
    vbx_set_vl((m+2)*(n+4)/4);
    vbx(SVW, VOR, v_outb+(n+4)*((m+2)*j), 0, v_padb+m*n);
#else
    for (i = 0; i < (n+4)*(m+2); i++) {
      count++;
      int diff = v_outb[j*(n+4)*(m+2)+i] - v_padb[(m*n)+i];
      if (diff < -4 || diff > 4) {
	if (errors < 10) {
	  printf("(%d,%d,%d)\t%d != %d\r\n", j, i/(n+4), i%(n+4), v_outb[j*(n+4)*(m+2)+i], v_padb[(m*n)+i]);
	}
	errors++;
      }
    }
#endif
  }
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);
  v_outb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024);

  conv.m = m;
  conv.n = n;
  conv.channels = 128;
  conv.kernels = 128;
  conv.weights = 144768;
  conv.maxpool = 1;

  if (verbose) printf("c3\r\n");
  convolution_ci_lve(v_outb, v_padb, &(conv), 0);
  m = 8, n = 8;

#if 0
  errors = 0;
  count = 0;
  for (j = 0; j < conv.kernels; j++) {
    vbx_flash_dma((vbx_word_t*)(v_padb), 178560+(j*m*n), (m*n)*sizeof(vbx_ubyte_t));
    vbx_zeropad_input(v_padb+m*n, v_padb, m, n);
#if 0
    vbx_set_vl((m+2)*(n+4)/4);
    vbx(SVW, VOR, v_outb+(n+4)*((m+2)*j), 0, v_padb+m*n);
#else
    for (i = 0; i < (n+4)*(m+2); i++) {
      count++;
      int diff = v_outb[j*(n+4)*(m+2)+i] - v_padb[(m*n)+i];
      if (diff < -4 || diff > 4) {
	if (errors < 10) {
	  printf("(%d,%d,%d)\t%d != %d\r\n", j, i/(n+4), i%(n+4), v_outb[j*(n+4)*(m+2)+i], v_padb[(m*n)+i]);
	}
	errors++;
      }
    }
#endif
  }
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_outb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);
  v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024);

  conv.m = m;
  conv.n = n;
  conv.channels = 128;
  conv.kernels = 256;
  conv.weights = 186752;
  conv.maxpool = 0;

  if (verbose) printf("c4\r\n");
  convolution_ci_lve(v_outb, v_padb, &(conv), 0);
  m = 8, n = 8;

#if 0
  errors = 0;
  count = 0;
  for (j = 0; j < conv.kernels; j++) {
    vbx_flash_dma((vbx_word_t*)(v_padb), 254336+(j*m*n), (m*n)*sizeof(vbx_ubyte_t));
    vbx_zeropad_input(v_padb+m*n, v_padb, m, n);
#if 0
    vbx_set_vl((m+2)*(n+4)/4);
    vbx(SVW, VOR, v_outb+(n+4)*((m+2)*j), 0, v_padb+m*n);
#else
    for (i = 0; i < (n+4)*(m+2); i++) {
      count++;
      int diff = v_outb[j*(n+4)*(m+2)+i] - v_padb[(m*n)+i];
      if (diff < -4 || diff > 4) {
	if (errors < 100) {
	  printf("(%d,%d,%d)\t%d != %d\r\n", j, i/(n+4), i%(n+4), v_outb[j*(n+4)*(m+2)+i], v_padb[(m*n)+i]);
	}
	errors++;
      }
    }
#endif
  }
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);
  v_outb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024);

  conv.m = m;
  conv.n = n;
  conv.channels = 256;
  conv.kernels = 256;
  conv.weights = 270720;
  conv.maxpool = 1;
  conv.zeropad_output = 0;

  if (verbose) printf("c5\r\n");
  convolution_ci_lve(v_outb, v_padb, &(conv), 0);
  m = 4, n = 4;

  vbx_word_t* v_in = (vbx_word_t*)(SCRATCHPAD_BASE+80*1024);
  vbx_word_t* v_out = (vbx_word_t*)(SCRATCHPAD_BASE+0*1024);

#if 0
  errors = 0;
  count = 0;
  for (j = 0; j < conv.kernels; j++) {
    vbx_flash_dma(v_out, 403840+(j*m*n)*4, (m*n)*sizeof(vbx_word_t));
#if 0
    vbx_set_vl(m*n);
    vbx(SVW, VOR, v_in+n*m*j, 0, v_out);
#else
    for (i = 0; i < n*m; i++) {
      count++;
      int diff = v_in[j*n*m+i] - v_out[i];
      if (diff < -4 || diff > 4) {
	if (errors < 10) {
	  printf("(%d,%d,%d)\t%d != %d\r\n", j, i/(n), i%(n), v_in[j*n*m+i], v_out[i]);
	}
	errors++;
      }
    }
#endif
  }
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  dense_layer_t dense;
  dense.layer_type = DENSE;
  dense.activation_type = RELU;
  dense.scale = 1;
  dense.inputs = 256*4*4;
  dense.outputs = 256;
  dense.biases = 551296;
  dense.scales = 552320;
  dense.weights = 420224;

  if (verbose) printf("d0\r\n");
  dense_lve(v_out, v_in, &(dense));

#if 0
  errors = 0;
  count = 0;
  vbx_flash_dma(v_in, 553344, dense.outputs*sizeof(vbx_word_t));
#if 0
  vbx_set_vl(dense.outputs);
  vbx(SVW, VOR, v_out, 0, v_in);
#else
  for (i = 0; i < dense.outputs; i++) {
    count++;
    int diff = v_in[i] - v_out[i];
    if (diff < -4 || diff > 4) {
      if (errors < 10) {
	printf("%d\t%d != %d\r\n", i, v_out[i], v_in[i]);
      }
      errors++;
    }
  }
#endif
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_out = (vbx_word_t*)(SCRATCHPAD_BASE+80*1024);
  v_in = (vbx_word_t*)(SCRATCHPAD_BASE+0*1024);

  dense.activation_type = RELU;
  dense.inputs = 256;
  dense.outputs = 256;
  dense.biases = 562560;
  dense.scales = 563584;
  dense.weights = 554368;

  if (verbose) printf("d1\r\n");
  dense_lve(v_out, v_in, &(dense));

#if 0
  errors = 0;
  count = 0;
  vbx_flash_dma(v_in, 564608, dense.outputs*sizeof(vbx_word_t));
#if 0
  vbx_set_vl(dense.outputs);
  vbx(SVW, VOR, v_out, 0, v_in);
#else
  for (i = 0; i < dense.outputs; i++) {
    count++;
    int diff = v_in[i] - v_out[i];
    if (diff < -4 || diff > 4) {
      if (errors < 10) {
	printf("%d\t%d != %d\r\n", i, v_out[i], v_in[i]);
      }
      errors++;
    }
  }
#endif
  if (count) {
    printf("%d errors\r\n", errors);
    printf("%d count\r\n", count);
  } else {
    printf("loaded outputs\r\n");
  }
#endif

  v_in = (vbx_word_t*)(SCRATCHPAD_BASE+80*1024);
  v_out = (vbx_word_t*)(SCRATCHPAD_BASE+0*1024);

  dense.activation_type = LINEAR;
  dense.inputs = 256;
  dense.outputs = 10;
  dense.biases = 565952;
  dense.scales = 565992;
  dense.weights = 565632;

  if (verbose) printf("d2\r\n");
  dense_lve(v_out, v_in, &(dense));
}
#define USE_CAM_IMG 1
#if USE_CAM_IMG
void cam_extract_and_pad(vbx_ubyte_t* channel,vbx_word_t* rgba_in,int byte_sel,int rows,int cols,int pitch)
{
  int c,r;
  for(r=0;r<rows+2;r++){
	 for(c=0;c<cols+4;c++){
		int pixel;
		if (c==0 || r==0 ||
			 c>=cols+1 || r>=rows+1){
		  pixel=0;
		}else {
		  pixel=rgba_in[(r-1)*pitch+(c-1)];
		}
		pixel=(pixel>>(byte_sel*8))&0xFF;
		channel[r*(cols+4) + c]=pixel;
	 }
  }
}
#endif

void cifar_lve() {

  printf("CES demo\r\n");
  printf("Lattice\r\n");
  printf("Testing convolution ci\r\n");

  init_lve();
  //enable output on LED
  SCCB_PIO_BASE[PIO_ENABLE_REGISTER] |= (1<<PIO_LED_BIT);
#if USE_CAM_IMG
  ovm_initialize();
#endif

  do{
	  int c, m = 32, n = 32, verbose = 1;
	  vbx_ubyte_t* v_padb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+80*1024); // IMPORTANT: padded input placed here
	  vbx_word_t* v_out = (vbx_word_t*)(SCRATCHPAD_BASE+0*1024); // IMPORTANT: 10 outputs produced here
	  vbx_ubyte_t* v_inb = (vbx_ubyte_t*)(SCRATCHPAD_BASE+0*1024);


#if USE_CAM_IMG
	  //zero the img buffer first (uncomment for better presentation
	  //vbx_set_vl(32*64);
	  //vbx(SVW,VAND,v_inb,0,v_inb);


	  ovm_get_frame();
	 //print base64 encoding of rgb image
	 char* rgb_plane = (char*)v_padb;
	 int off;

	 for(off=0;off<32*64;off++){
		rgb_plane[3*off+0]/*CV_FRAME2: R*/ = v_inb[4*off+0];
		rgb_plane[3*off+1]/*CV_FRAME1: G*/ = v_inb[4*off+1];
		rgb_plane[3*off+2]/*CV_FRAME0: B*/ = v_inb[4*off+2];
	 }
	 printf("base64:");
	 print_base64((char*)rgb_plane,3*32*64);
	 printf("\r\n");
	 for (c = 0; c < 3; c++) {

		 cam_extract_and_pad(v_padb + c*(m+2)*(n+4), (vbx_word_t*)v_inb,c, m, n, 64);
	 }

#else

	  // dma in test image (or get from camera!!)
	  vbx_flash_dma(v_inb, 0, (3*m*n)*sizeof(vbx_ubyte_t));

	  // zero pad imaged w/ bytes
	  for (c = 0; c < 3; c++) {
		  vbx_zeropad_input(v_padb + c*(m+2)*(n+4), v_inb + c*m*n, m, n);
	  }
#endif

#if 0
	  /* Print out maps*/
	  for (c = 0; c < 3; c++) {
		  int i,j;
		  for(i=0;i<n+2;i++){
			  for(j=0;j<m+4;j++){
				  printf("%3d ",(v_padb + c*(m+2)*(n+4))[i*(n+4) +j]);
			  }
			  printf("\r\n");
		  }
		  printf("\r\n");
	  }
#endif

	  run_network(verbose);

	  int max_cat=0;
		  // print results (or toggle LED if person is max, and > 0)
	  char *categories[] = {"air", "auto", "bird", "cat", "person", "dog", "frog", "horse", "ship", "truck"};
	  for (c = 0; c < 10; c++) {
		  if(v_out[c] > v_out[max_cat] ){
			  max_cat =c;
		  }
		  if (verbose) {
			  printf("%s\t%d\r\n", categories[c], v_out[c]);
		  }
	  }

	  if(max_cat == 4 /*person*/){
		  //turn on led
		  SCCB_PIO_BASE[PIO_DATA_REGISTER] |= (1<<PIO_LED_BIT);
		  if(verbose){
			  printf("PERSON DETECTED %d\r\n ",(int)v_out[max_cat]);
		  }
	  }else {
		  //turn off led
		  SCCB_PIO_BASE[PIO_DATA_REGISTER] &= ~(1<<PIO_LED_BIT);
	  }

  }while(1);

}
