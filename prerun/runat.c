#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

void alrm_hndl(int);
void chld_hndl(int);
int pid;

int main(int argc, char **argv) {
  int timer;
  char **newargv;

  timer = atoi(argv[1]);

  signal(SIGALRM, alrm_hndl);
  signal(SIGCHLD, chld_hndl);

  alarm(timer);

  pid = fork();
  if (!pid) {
    newargv = &argv[2];
    fprintf(stderr, "RUNATCMD: ");
    {
      int count=2;
      while(argv[count] != NULL) {
	fprintf(stderr, "%s ", argv[count]);
	count++;
      }
      fprintf(stderr, "\n");
    }
    exit(execvp(*newargv, newargv));
  } else {
    sleep(timer*2);
  }
  exit(1);
}

void chld_hndl(int signo) {
  int status;
  int i;
  for (i=0; i<10; i++) {
    waitpid(-1, &status, WNOHANG);
    usleep(50000);
  }
  //    wait(&status);
  //  printf("DJADAS %d \n", WEXITSTATUS(status));
  exit(WEXITSTATUS(status));
}

void alrm_hndl(int signo) {
  printf("ALRM!\n");
  kill(pid, SIGTERM);
  kill(pid, SIGKILL);
  exit(1);
}
