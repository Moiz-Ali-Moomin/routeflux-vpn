#include <jni.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <android/log.h>
#include <string.h>
#include <errno.h>
#include <sys/wait.h>
#include <stdio.h>

#define TAG "NativeUtils"

// Helper to check errors
void log_error(const char *msg) {
    __android_log_print(ANDROID_LOG_ERROR, TAG, "%s: %s", msg, strerror(errno));
}

JNIEXPORT jint JNICALL
Java_com_routeflux_vpn_MyVpnService_startProcessNative(JNIEnv *env, jobject thiz, 
                                                                     jstring executable, 
                                                                     jstring fd_arg, 
                                                                     jstring proxy,
                                                                     jint fd,
                                                                     jstring log_path) {
    const char *exe_path = (*env)->GetStringUTFChars(env, executable, 0);
    const char *fd_str = (*env)->GetStringUTFChars(env, fd_arg, 0);
    const char *proxy_url = (*env)->GetStringUTFChars(env, proxy, 0);
    const char *log_file = (*env)->GetStringUTFChars(env, log_path, 0);

    pid_t pid = fork();

    if (pid < 0) {
        log_error("Failed to fork");
        return -1;
    }

    if (pid == 0) {
        // Child process
        
        // Critical: Unset the FD_CLOEXEC flag so the FD survives exec
        int flags = fcntl(fd, F_GETFD);
        if (flags == -1) {
            log_error("Failed to get fd flags");
            exit(1);
        }
        
        if (fcntl(fd, F_SETFD, flags & ~FD_CLOEXEC) == -1) {
             log_error("Failed to clear CLOEXEC");
             exit(1);
        }

        // Redirect stdout and stderr to the log file using freopen
        // This ensures tun2socks logs are captured
        FILE *fp_out = freopen(log_file, "w", stdout);
        FILE *fp_err = freopen(log_file, "w", stderr);

        if (!fp_out || !fp_err) {
            log_error("Failed to open log file");
            // Continue anyway, better than crash
        }

        // Prepare arguments
        char *args[8];
        args[0] = (char *)exe_path;
        args[1] = "-device";
        args[2] = (char *)fd_str;
        args[3] = "-proxy";
        args[4] = (char *)proxy_url;
        args[5] = "-loglevel";
        args[6] = "debug";
        args[7] = NULL;

        execvp(exe_path, args);
        
        log_error("Failed to exec");
        exit(1);
    }

    // Parent process
    (*env)->ReleaseStringUTFChars(env, executable, exe_path);
    (*env)->ReleaseStringUTFChars(env, fd_arg, fd_str);
    (*env)->ReleaseStringUTFChars(env, proxy, proxy_url);
    (*env)->ReleaseStringUTFChars(env, log_path, log_file);
    
    return (jint)pid;
}
