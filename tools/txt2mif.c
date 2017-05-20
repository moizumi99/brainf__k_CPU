#include <stdio.h>
#define BYTES_PER_LINE 4

void main(int argc, char *argv[]) {
  FILE *f1, *f2;
  int  c;
  int i;
  int data;
  int adr=0;

  if (argc<3) {
	printf("txt2mif text_file_name mif_file_name\n");
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
	  fputs("-- ", f2);
	}
	i++;
	fputc(c, f2);
	if (c=='\n') {
	  i=0;
	}
	if (i==80) {
	  fputs("\n\n", f2);
	}
  }
  
  fseek(f1, 0, SEEK_SET);
  
  fprintf(f2, "DEPTH = 1024;\n");
  fprintf(f2, "WIDTH = 32;\n");
  fprintf(f2, "ADDRESS_RADIX = HEX;\n");
  fprintf(f2, "DATA_RADIX = HEX;\n");
  fprintf(f2, "CONTENT\n");
  fprintf(f2, "BEGIN\n\n");

  i = 0;
  adr = 0;
  data = 0;
  while((c=fgetc(f1)) != EOF) {
	data = data | (c << (8*i));
	if (i==3) {
	  fprintf(f2, "%02X : %08X;\n", adr, data);
	  adr++;
	  i=0;
	  data = 0;
	} else {
	  i++;
	}
  }
  if (i!=0) {
	fprintf(f2, "%02X : %08X;\n", adr, data);
  }
  fprintf(f2, "\nEND;\n");
  fclose(f1);
  fclose(f2);
  
  return;
}
