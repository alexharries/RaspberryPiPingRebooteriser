#include <wiringPi.h>
int main()
{
  wiringPiSetup();

  pinMode(7,OUTPUT);
  pinMode(3,OUTPUT);
  pinMode(22,OUTPUT);
  pinMode(25,OUTPUT);
  printf("relay testing!\n");
  while(1)
  { 
        digitalWrite(7,HIGH);
        delay(500);
        digitalWrite(7,LOW);
        digitalWrite(3,HIGH);
        delay(500);
        digitalWrite(3,LOW);
        digitalWrite(22,HIGH);
	delay(500); 
        digitalWrite(22,LOW);
	digitalWrite(25,HIGH);
	delay(500);
	digitalWrite(25,LOW);
	delay(500); 
  }
	
}
