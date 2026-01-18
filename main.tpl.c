#include <windows.h>

int main(int argc, char ** argv)
{
  int bytecode_size = SET_SIZE;
  unsigned char bytecode[SET_SIZE] = {SET_BYTECODE};
  DWORD dummy;

  VirtualProtect(bytecode, bytecode_size, PAGE_EXECUTE_READWRITE, &dummy);

  void (*function)(void) = (void (*)(void))bytecode;
  
  function();
}
