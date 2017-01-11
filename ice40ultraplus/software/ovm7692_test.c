

#include "printf.h"
#include "sccb.h"
#include "ovm7692.h"
#include "time.h"
#include "vbx.h"
#include "base64.h"



#define RGB565      0
#define UART        1
#define OPEN_CV     1
#define PRINT_PIC   0
#define IMAGE_DENOISE_H 0
#define IMAGE_DENOISE_V 0




typedef unsigned char uchar;
typedef unsigned int  uint;

#define SCCB_PIO_BASE   ((uint *)0x00050000)




static int rgb_pad_l;
static int rgb_pad_r;
static int rgb_pad_t;
static int rgb_pad_b;
static int rgb_h;
static int rgb_v;
static int rgb_pad_h;
static int rgb_pad_v;



void ovm_write_reg(int reg_addr,int reg_val)
{
	sccb_write(SCCB_PIO_BASE, OVM7692_ADDRESS, reg_addr, reg_val);
}

int ovm_read_reg(int reg_addr)
{
	return sccb_read(SCCB_PIO_BASE, OVM7692_ADDRESS, reg_addr);
}

typedef struct{
	uint8_t addr,val;
} regval_t;

#define PIO_BIT_START 2
#define PIO_BIT_DONE  3
#define PIO_BIT_LED   4


void ovm_set_bit( int bitpos )
{
	volatile uint *p = &( SCCB_PIO_BASE[PIO_DATA_REGISTER] );
	*p |= (1<<bitpos);
}

void ovm_clear_bit( int bitpos )
{
	volatile uint *p = &( SCCB_PIO_BASE[PIO_DATA_REGISTER] );
	*p &= (~(1<<bitpos));
}

int ovm_get_bit( int bitpos )
{
	volatile uint *p = &( SCCB_PIO_BASE[PIO_DATA_REGISTER] );
	return (*p & (1<<bitpos)) ? 1 : 0 ;
}


int ovm_isdone()
{
	return !ovm_get_bit( PIO_BIT_DONE );
}


#include "ovm7692_reg.c"


int ovm_configure()
{
	printf("STARTING OVM configuration\r\n");
	delayms(500);
	printf("Done Delay\r\n");
	sccb_init(SCCB_PIO_BASE);

	uint8_t pidh = ovm_read_reg(OVM7692_SUBADDRESS_PIDH);
	uint8_t pidl = ovm_read_reg(OVM7692_SUBADDRESS_PIDL);
	debugx(pidh);
	debugx(pidl);
	if((pidh != OVM7692_DEFAULT_PIDH) || (pidl != OVM7692_DEFAULT_PIDL)){
		printf("Error: BAD ,model ID\r\n");
		return 1;
	}
	ovm_write_reg(0x12, 0x06);
	if(ovm_read_reg(0x12) != 0x6){
		printf("Error: WRITE FAILED \r\n");
		return 1;
	}
	int i;
	printf("Writing Configuration Registers...");
	for(i=0;i<(sizeof(regval_list)/sizeof(regval_list[0]));i++){
		ovm_write_reg(regval_list[i].addr,regval_list[i].val);
		delayms(2);
	}

#if 1 /* dump configuration registers*/
	printf("\r\n");
	for(i=0;i<256;i++){
		printf("%02x  %02x\r\n",i,ovm_read_reg(i));
		if((i&0xF)==0xF){
			printf("\r\n");
		}
	}
#endif

	printf("Done\r\n");
	return 0;
}

#if PRINT_PIC
// print ASCII art version of image using grayscale
static char gray2txt[]="   ...'`,^:\";~-_+<>i!lI? /\\|()1{}[]rcvunxzjftLCJUYXZO0Qoahkbdpqwm*WMB8&%$#@";
//static char gray2txt[]=" .:;+oi?j{}[]CUO0QWMB8@";
void print_pic( uchar* pix,int cols,int rows,int stride)
{
	int num_gray=sizeof(gray2txt);
	int i,j;
	// printf("\033 [2J"); // clear terminal screen
	for(i=0;i<rows;i++) {
		for(j=0;j<cols;j++) {
			int r = pix[i*stride*3 + j*3+0];
			int g = pix[i*stride*3 + j*3+1];
			int b = pix[i*stride*3 + j*3+2];
			int gray = (213*r + 715*g + 72*b)*num_gray/(255*1000);
			char txt = gray2txt[gray];
			mputc(0,txt);mputc(0,txt);
		}
		mputc(0,'\r');		mputc(0,'\n');
	}

}
#else
// avoid compiler warning
void print_pic( uchar* pix,int cols,int rows,int stride);
#endif

void clear_frame( uchar *pixmap, int num_bytes )
{
	int i;
	for( i=0; i<num_bytes; i++ ) {
		pixmap[i] =0;
	}
}

void print_reg( int reg, char *description )
{
	int val = ovm_read_reg( reg );
	printf("reg(0x%02x) = 0x%02x %s", reg, val, description );
}

void printf_rgb( uchar red, uchar grn, uchar blu )
{
	int i,b;
	printf("r");
	for( i=0x80; i; i>>=1 ) { b = red & i; mputc(0, b?'1':'0' ); }
	printf("_g");
	for( i=0x80; i; i>>=1 ) { b = grn & i; mputc(0, b?'1':'0' ); }
	printf("_b");
	for( i=0x80; i; i>>=1 ) { b = blu & i; mputc(0, b?'1':'0' ); }
	printf(" | ");
}

void printf_bin(uint rgb565)
{
	int i,b;
	for( i=0x8000; i; i>>=1 ) {
		if(i==0x8000) printf("r");
		if(i==0x0400) printf("_g");
		if(i==0x0010) printf("_b");
		if(i==0x0080) printf(":");
		b = rgb565 & i;
		mputc(0, b?'1':'0' );
	}
	mputc(0,' ');
}
void print_buf( uchar *buf )
{
	/* verify the red_buf, etc */
	int i=0,r,c,max=buf[0];
	for(r=0;r<rgb_pad_v;r++){
		printf("%02d ", r );
		for(c=0;c<rgb_pad_h;c++){
			if(buf[i]>max) max=buf[i];
			printf("%02x ", buf[ i++ ] );
		}
		printf("\r\n");
	}
	printf("max: %d\r\n", max);
}

void ovm_get_first_frame()
{
	//Add frame reading logic here

	printf("FIRST FRAME\r\n");
	printf("wait for done\r\n");
	ovm_clear_bit( PIO_BIT_START );
	//wait for done bit
	while(!ovm_isdone()){
		debugx(((volatile int*)SCCB_PIO_BASE)[PIO_DATA_REGISTER]);
	}
	//set start bit
	printf("set start\r\n");
	ovm_set_bit( PIO_BIT_START );
	printf("wait for not DONE\r\n");
	while(ovm_isdone()){
		//debugx(((volatile int*)SCCB_PIO_BASE)[PIO_DATA_REGISTER]);
	}
	ovm_clear_bit( PIO_BIT_START );
	printf("wait for done\r\n");
	//wait for done bit
	while(!ovm_isdone());
	printf("DONE!\r\n");
}


void ovm_get_frame()
{
		// tell camera to capture a frame
		ovm_set_bit( PIO_BIT_START );

		// wait until FSM actually starts
		while( ovm_isdone() );

		// clear the start bit
		ovm_clear_bit( PIO_BIT_START );

		// wait until DMA is DONE
		while( ovm_isdone()==0 );
}



// image speckle removing, based on median filter
// compare 3 horizontal pixels, replace center with median value
void h_denoise( uchar* buf )
{
	uchar out, t;
	int off, r, c;
	for(r=0;r<rgb_v;r++){
		c=0;
		off = (rgb_pad_t+r)*rgb_pad_h + rgb_pad_l + (c-0);
		out = buf[off];
		for(c=1;c<rgb_h-1;c++){
			off = (rgb_pad_t+r)*rgb_pad_h + rgb_pad_l + (c-0);
			uchar pl = buf[off-1];
			uchar pc = buf[off-0];
			uchar pr = buf[off+1];
			if( pl > pc ) { t=pl; pl=pc; pc=t; }
			if( pc > pr ) { t=pc; pc=pr; pr=t; }
			if( pl > pc ) { t=pl; pl=pc; pc=t; }
			buf[off-1] = out;
			out = pc;
		}
		buf[off]=out;
	}
}

// image speckle removing, based on median filter
// compare 3 vertical pixels, replace center with median value
void v_denoise( uchar* buf )
{
	uchar out, t;
	int off, r, c;
	for(c=0;c<rgb_h;c++){
		r=0;
		off = (rgb_pad_t+r)*rgb_pad_h + rgb_pad_l + (c-0);
		out = buf[off];
		for(r=1;r<rgb_v-1;r++){
			off = (rgb_pad_t+r)*rgb_pad_h + rgb_pad_l + (c-0);
			uchar pl = buf[off-rgb_pad_h];
			uchar pc = buf[off-0];
			uchar pr = buf[off+rgb_pad_h];
			if( pl > pc ) { t=pl; pl=pc; pc=t; }
			if( pc > pr ) { t=pc; pc=pr; pr=t; }
			if( pl > pc ) { t=pl; pl=pc; pc=t; }
			buf[off-rgb_pad_h] = out;
			out = pc;
		}
		buf[off]=out;
	}
}


int main()
{

	int dma_num_pixels;
	int rgb_num_pixels;
	uchar* red_buf;
	uchar* grn_buf;
	uchar* blu_buf;
	volatile uchar* cam_dma_buf;

	dma_num_pixels=64*32;
	rgb_pad_l = 4;
	rgb_pad_r = 4;
	rgb_pad_t = 2;
	rgb_pad_b = 0;
	rgb_h = 32;
	rgb_v = 32;
	rgb_pad_h = (rgb_pad_l + rgb_h + rgb_pad_r);
	rgb_pad_v = (rgb_pad_t + rgb_v + rgb_pad_b);
	rgb_num_pixels = (rgb_pad_h*rgb_pad_v);
	cam_dma_buf=SCRATCHPAD_BASE;
	red_buf = (uchar*)SCRATCHPAD_BASE + dma_num_pixels*4;
	grn_buf = red_buf     + rgb_num_pixels*1;
	blu_buf = red_buf     + rgb_num_pixels*2;

	printf("\r\nTESTING OVM\r\n");

    //debug pin select:
	/* cam_aux_out(0) <= v_load_pixel; */
	/* cam_aux_out(1) <= h_load_pixel; */
	/* cam_aux_out(2) <= ovm_pclk */
	/* cam_aux_out(3) <= ovm_pixel_valid; */
	/* cam_aux_out(4) <= v_load_row; */
	/* cam_aux_out(5) <= extra_href; */
	/* cam_aux_out(6) <= ff0; */
	/* cam_aux_out(7) <= v_rgb_out_valid; */


	int select=0;
	(((volatile int*)SCCB_PIO_BASE)[PIO_DATA_REGISTER]) &=0x1F;
	(((volatile int*)SCCB_PIO_BASE)[PIO_DATA_REGISTER]) |=(select << 5);


	if(ovm_configure()){
		printf("FAILED configuration\r\n");
		while(1);
	}


	ovm_get_first_frame();

	printf("SECOND FRAME\r\n");
	//get second frame
	int frame_counter=0;
	int start_time,end_time;

	/* turn on LED */
	ovm_set_bit( PIO_BIT_LED );

	while(1){

		clear_frame( (uchar*)cam_dma_buf, dma_num_pixels*4 );
		clear_frame( red_buf, rgb_num_pixels );
		clear_frame( grn_buf, rgb_num_pixels );
		clear_frame( blu_buf, rgb_num_pixels );

		start_time=get_time();
		ovm_get_frame();
		end_time=get_time();

#if (0 && UART)
// for some reason this turns off the pio (PIO_BIT_LED)
		print_reg( 0x04, "average Y " );
		print_reg( 0x05, "average B " );
		print_reg( 0x06, "average R " );
		print_reg( 0x07, "average G\r\n" );
#endif

		//remove alpha channel, swap Red/Blue for OpenCV display
		int r,c;
		for(r=0;r<30;r++){
			for(c=0;c<40;c++){


// when printing array values to screen, limit to just CLIM columns and RLIM rows
#define CLIM 10
#define RLIM 30

#if RGB565  /* treat GREEN channel fairly, as if only 5 bits */
				const volatile uchar *p = &(cam_dma_buf[(r*64+c)*4]);
				const unsigned short rgb565 = *((unsigned short*)p);
				uchar red = (((rgb565 >> 11) & 0x1f) << 3);
				uchar grn = (((rgb565 >>  6) & 0x1f) << 3);
				uchar blu = (((rgb565 >>  0) & 0x1f) << 3);
				/* extend LSBs for better colour definition */
				const uchar EXTRA_LSB = 0x04;
				red = red | ((red&0x8)? EXTRA_LSB : 0x0) ;
				grn = grn | ((grn&0x8)? EXTRA_LSB : 0x0) ;
				blu = blu | ((blu&0x8)? EXTRA_LSB : 0x0) ;
				if( c<CLIM && r<RLIM ) { printf_bin(rgb565); }
				if( c==39  && r<RLIM ) { printf("...\r\n"); }
#else /* RGB888 */
				const int idx = (r*64+c)*4;
				uchar red = cam_dma_buf[idx+2];
				uchar grn = cam_dma_buf[idx+1];
				uchar blu = cam_dma_buf[idx+0];
				//if( c<CLIM && r<RLIM ) { printf_rgb(red,grn,blu); }
				//if( c==39  && r<RLIM ) { printf("...\r\n"); }
#endif /* RGB565 or RGB888 */

				if( c>=4 && c<36 ) {
					const int off = (rgb_pad_t+r)*rgb_pad_h + rgb_pad_l + (c-4);
					red_buf[ off ] = red;
					grn_buf[ off ] = grn;
					blu_buf[ off ] = blu;
				}
			}
		}
		const int deinterleave_time = get_time() - end_time;

		const int start_denoise = get_time();
#if IMAGE_DENOISE_H
		h_denoise( red_buf ); v_denoise( red_buf );
		h_denoise( grn_buf ); v_denoise( grn_buf );
		h_denoise( blu_buf ); v_denoise( blu_buf );
#endif // IMAGE_DENOISE_H
#if IMAGE_DENOISE_V
		v_denoise( red_buf ); v_denoise( red_buf );
		v_denoise( grn_buf ); v_denoise( grn_buf );
		v_denoise( blu_buf ); v_denoise( blu_buf );
#endif // IMAGE_DENOISE_V
		const int end_denoise = get_time();

#if 0
		printf("red   \r\n"); print_buf( red_buf );
		printf("green \r\n"); print_buf( grn_buf );
		printf("blue  \r\n"); print_buf( blu_buf );
#endif

#if (OPEN_CV | PRINT_PIC)
		// used by OPEN_CV and PRINT_PIC
		for(r=0;r<rgb_v;r++){
			for(c=0;c<rgb_h;c++){
				const int off = (rgb_pad_t+r)*rgb_pad_h + rgb_pad_l + (c-0);
				cam_dma_buf[(r*40+c+rgb_pad_l)*3+2]/*CV_FRAME0: B*/ = blu_buf[off];
				cam_dma_buf[(r*40+c+rgb_pad_l)*3+1]/*CV_FRAME1: G*/ = grn_buf[off];
				cam_dma_buf[(r*40+c+rgb_pad_l)*3+0]/*CV_FRAME2: R*/ = red_buf[off];
			}
		}
#endif

#if PRINT_PIC
		print_pic((uchar*)cam_dma_buf,40,30,40);
#endif

#if OPEN_CV
		printf("base64:");
		print_base64((char*)cam_dma_buf,3*40*30);
#endif

		if( UART ) printf("\r\n frame %d %d cycles DMA, %d cycles de-interleave %d cycles de-noise\r\n",
			frame_counter++, end_time-start_time, deinterleave_time, end_denoise-start_denoise );

		//delayms(2000);
	}

	return 0;
}
