#include "rps.h"

// windows
#ifdef _WIN32
#include <process.h>
#include <windows.h>
// linux and macos
#else
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <cstdlib>
#endif

int main()
{
    return 0;
}

// windows
#ifdef _WIN32

intptr_t handle;

BOOL WINAPI CtrlHandler(DWORD fdwCtrlType)
{
    switch (fdwCtrlType)
    {
    case CTRL_C_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_LOGOFF_EVENT:
    case CTRL_SHUTDOWN_EVENT:
        return TRUE;
    default:
        return FALSE;
    }
}

int runCommand(const char *command)
{

    SetConsoleCtrlHandler(CtrlHandler, TRUE);

    handle = _spawnlp(_P_NOWAIT, "cmd", "/c", command, (char *)NULL);

    int statusCode = 0;
    _cwait(&statusCode, handle, NULL);
    return statusCode;
}
// linux and macos
#else
int pid;

void ctrlCHandler(int signum)
{
    // send SIGKILL signal to the child process
    kill(pid, SIGKILL);
}

int runCommand(const char *command)
{

    pid = fork();

    if (pid == -1)
    {
        return 1;
    }
    else if (pid == 0)
    {
        execlp("bash", "bash", "-c", command, (char *)NULL);
        // Nothing below this line should be executed by child process. If so,
        // it means that the execlp function wasn't successfull.
        exit(1);
    }
    else
    {

        // Register ctrlc handler to kill child process before closing parent process.
        struct sigaction sigIntHandler;
        sigIntHandler.sa_handler = ctrlCHandler;
        sigemptyset(&sigIntHandler.sa_mask);
        sigIntHandler.sa_flags = 0;
        sigaction(SIGINT, &sigIntHandler, NULL);

        int exitCode = 0;
        int returnedPid = waitpid(pid, &exitCode, 0);
        // -1 on error.
        if (returnedPid == -1)
        {
            return 1;
        }
        else
        {
            return exitCode;
        }
    }
}
#endif

int execute(char *command)
{
    if (command == NULL)
    {
        return 1;
    }

    return runCommand(command);
}
