#include "rps.h"

// windows
#ifdef _WIN32
#include <process.h>
#include <windows.h>
#include <string.h>
// linux and macos
#else
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <cstdlib>
#include <string.h>
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

int runCommand(const char *command, const char *interpreter)
{

    SetConsoleCtrlHandler(CtrlHandler, TRUE);

    if (interpreter == NULL || strlen(interpreter) == 0 || strcmp(interpreter, "powershell") == 0)
    {
        handle = _spawnlp(_P_NOWAIT, "powershell", "powershell", "-Command", command, NULL);
    }
    else if (strcmp(interpreter, "cmd") == 0)
    {
        handle = _spawnlp(_P_NOWAIT, "cmd", "cmd", "/c", command, (char *)NULL);
    }
    else
    {
        return -1; // Return an error code if interpreter is not allowed
    }

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

/// @brief Executes the `command` with the provided `interpreter`, by default bash.
int runCommand(const char *command, const char *interpreter)
{
    if (interpreter == NULL || strlen(interpreter) == 0)
    {
        interpreter = "bash"; // Default to "bash" if no interpreter is provided
    }
    else if (strcmp(interpreter, "bash") != 0 && strcmp(interpreter, "zsh") != 0 && strcmp(interpreter, "sh") != 0)
    {
        return -1; // Return an error code if interpreter is not allowed
    }

    pid = fork();

    if (pid == -1)
    {
        return 1;
    }
    else if (pid == 0)
    {
        execlp(interpreter, interpreter, "-c", command, (char *)NULL);
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

int execute(char *command, char *interpreter)
{
    if (command == NULL)
    {
        return 1;
    }

    return runCommand(command, interpreter);
}
