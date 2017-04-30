#include <stdio.h>

void main(int argc, char *argv[]) {
  FILE *f1, *f2;
  int  c;
  int i;
  int sum;
  int adr=0;

  if (argc<3) {
	printf("txt2hex text_file_name hex_file_name\n");
  }
  f1=fopen(argv[1], "r");
  if (f1==NULL) {
	printf("Error opening %s\n", argv[1]);
	return;
  }
  f2=fopen(argv[2], "w");
  if (f2==NULL) {
	printf("Error opening %s\n", argv[2]);
	return;
  }
  i = 0;
  while((c=fgetc(f1)) != EOF) {
	if (i==0) {
	  fprintf(f2, ":10%04x00", adr);
	  sum = 0x10 + ((adr >> 8) & 0xFF) + (adr & 0xFF);
	  printf("sum: %04x\n", sum);
	}
	fprintf(f2, "%02x", c);
	sum += c;
	printf("din: %c, %02x, sum: %04x\n",c , c, sum);
	i++;
	if (i==16) {
	  c = (0-(sum & 0xff)) & 0xFF;
	  fprintf(f2, "%02x\n", c);
	  printf("checksum: %02x\n", c);
	  i = 0;
	  adr += 16;
	}
  }
  if (i!=0) {
	for(;i<16; i++) {
	  fprintf(f2, "%02x", 0);
	}
	c = (0-(sum & 0xff)) & 0xFF;
	fprintf(f2, "%02x\n", c);
  }
  fprintf(f2, ":00000001FF");
  fclose(f1);
  fclose(f2);
  
  return;
}
