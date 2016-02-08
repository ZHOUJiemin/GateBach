//gatebach driver software (dummy)
//gatebach.c

#define PRIME_LIST_SIZE 2300000000

void main()
{
  for(int i = 2; i < PRIME_LIST_SIZE; i += 2){
    if(isPrime(i)){

      GATEBACH_START();

    }
  }
}

GATEBACH_START(){
  
}
