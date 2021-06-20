local ffi = require("ffi")

ffi.cdef[[
static const int ENOENT = 2;
static const int EINTR = 4;
static const int ETIME = 62;
static const int EAGAIN = 11;
static const int EINVAL = 22;
static const int EPIPE = 32;
static const int ENOSYS = 38;
static const int ENOTSUP = 95;
static const int ETIMEDOUT = 110;
static const int ECANCELED = 125;
char *strerror(int) __attribute__((nothrow, leaf));
static const int O_APPEND = 1024;
static const int O_CREAT = 64;
static const int O_TRUNC = 512;
static const int O_RDWR = 2;
static const int O_RDONLY = 0;
static const int O_WRONLY = 1;
static const int O_NONBLOCK = 2048;
static const int O_CLOEXEC = 524288;
static const int S_IRUSR = 256;
static const int S_IWUSR = 128;
static const int S_IXUSR = 64;
static const int S_IRWXU = 448;
static const int S_IRGRP = 32;
static const int S_IWGRP = 16;
static const int S_IXGRP = 8;
static const int S_IRWXG = 56;
static const int S_IROTH = 4;
static const int S_IWOTH = 2;
static const int S_IXOTH = 1;
static const int S_IRWXO = 7;
int open(const char *, int, ...);
int close(int);
int fcntl(int, int, ...);
ssize_t write(int, const void *, size_t);
ssize_t read(int, void *, size_t);
int kill(int, int) __attribute__((nothrow, leaf));
int getpid(void) __attribute__((nothrow, leaf));
typedef long unsigned int nfds_t;
struct pollfd {
  int fd;
  short int events;
  short int revents;
};
static const int POLLIN = 1;
static const int POLLOUT = 4;
static const int POLLERR = 8;
static const int POLLHUP = 16;
int poll(struct pollfd *, nfds_t, int);
static const int PROT_READ = 1;
static const int PROT_WRITE = 2;
static const int MAP_SHARED = 1;
static const int MAP_FAILED = -1;
static const int PATH_MAX = 4096;
int memcmp(const void *, const void *, size_t) __attribute__((pure, leaf, nothrow));
typedef long int off_t;
void *mmap(void *, size_t, int, int, int, off_t) __attribute__((nothrow, leaf));
int munmap(void *, size_t) __attribute__((nothrow, leaf));
static const int FIONREAD = 21531;
int ioctl(int, long unsigned int, ...) __attribute__((nothrow, leaf));
unsigned int sleep(unsigned int);
int usleep(unsigned int);
char *realpath(const char *restrict, char *restrict) __attribute__((nothrow, leaf));
char *basename(char *) __attribute__((nothrow, leaf));
char *dirname(char *) __attribute__((nothrow, leaf));
void *malloc(size_t) __attribute__((malloc, leaf, nothrow));
void *calloc(size_t, size_t) __attribute__((malloc, leaf, nothrow));
void free(void *) __attribute__((leaf, nothrow));
void *memset(void *, int, size_t) __attribute__((leaf, nothrow));
char *strdup(const char *) __attribute__((malloc, leaf, nothrow));
char *strndup(const char *, size_t) __attribute__((malloc, leaf, nothrow));
static const int F_OK = 0;
int access(const char *, int) __attribute__((nothrow, leaf));
typedef struct _IO_FILE FILE;
int fileno(FILE *) __attribute__((nothrow, leaf));
FILE *fopen(const char *restrict, const char *restrict);
size_t fread(void *restrict, size_t, size_t, FILE *restrict);
size_t fwrite(const void *restrict, size_t, size_t, FILE *restrict);
int fclose(FILE *);
int feof(FILE *) __attribute__((nothrow, leaf));
int ferror(FILE *) __attribute__((nothrow, leaf));
int fprintf(FILE *restrict, const char *restrict, ...);
int fflush(FILE *);
int setenv(const char *, const char *, int) __attribute__((nothrow, leaf));
int unsetenv(const char *) __attribute__((nothrow, leaf));
static const int LOG_CONS = 2;
static const int LOG_NDELAY = 8;
static const int LOG_NOWAIT = 16;
static const int LOG_ODELAY = 4;
static const int LOG_PERROR = 32;
static const int LOG_PID = 1;
static const int LOG_DAEMON = 24;
static const int LOG_USER = 8;
static const int LOG_EMERG = 0;
static const int LOG_ALERT = 1;
static const int LOG_CRIT = 2;
static const int LOG_ERR = 3;
static const int LOG_WARNING = 4;
static const int LOG_NOTICE = 5;
static const int LOG_INFO = 6;
static const int LOG_DEBUG = 7;
void openlog(const char *, int, int);
void syslog(int, const char *, ...);
void closelog(void);
static const int CLOCK_REALTIME = 0;
static const int CLOCK_REALTIME_COARSE = 5;
static const int CLOCK_MONOTONIC = 1;
static const int CLOCK_MONOTONIC_COARSE = 6;
static const int CLOCK_MONOTONIC_RAW = 4;
static const int CLOCK_BOOTTIME = 7;
static const int CLOCK_TAI = 11;
typedef long int time_t;
struct timespec {
  time_t tv_sec;
  long int tv_nsec;
};
typedef int clockid_t;
int clock_getres(clockid_t, struct timespec *) __attribute__((nothrow, leaf));
int clock_gettime(clockid_t, struct timespec *) __attribute__((nothrow, leaf));
int clock_settime(clockid_t, const struct timespec *) __attribute__((nothrow, leaf));
static const int TIMER_ABSTIME = 1;
int clock_nanosleep(clockid_t, int, const struct timespec *, struct timespec *);
static const int TFD_NONBLOCK = 2048;
static const int TFD_CLOEXEC = 524288;
static const int TFD_TIMER_ABSTIME = 1;
static const int TFD_TIMER_CANCEL_ON_SET = 2;
struct itimerspec {
  struct timespec it_interval;
  struct timespec it_value;
};
int timerfd_create(int, int) __attribute__((nothrow, leaf));
int timerfd_settime(int, int, const struct itimerspec *, struct itimerspec *) __attribute__((nothrow, leaf));
int timerfd_gettime(int, struct itimerspec *) __attribute__((nothrow, leaf));
struct inotify_event {
  int wd;
  uint32_t mask;
  uint32_t cookie;
  uint32_t len;
  char name[];
};
static const int IN_ACCESS = 1;
static const int IN_ATTRIB = 4;
static const int IN_CLOSE_WRITE = 8;
static const int IN_CLOSE_NOWRITE = 16;
static const int IN_CLOSE = 24;
static const int IN_CREATE = 256;
static const int IN_DELETE = 512;
static const int IN_DELETE_SELF = 1024;
static const int IN_MODIFY = 2;
static const int IN_MOVE_SELF = 2048;
static const int IN_MOVED_FROM = 64;
static const int IN_MOVED_TO = 128;
static const int IN_MOVE = 192;
static const int IN_OPEN = 32;
static const int IN_ALL_EVENTS = 4095;
static const int IN_DONT_FOLLOW = 33554432;
static const int IN_EXCL_UNLINK = 67108864;
static const int IN_MASK_ADD = 536870912;
static const int IN_ONESHOT = 2147483648;
static const int IN_ONLYDIR = 16777216;
static const int IN_MASK_CREATE = 268435456;
static const int IN_IGNORED = 32768;
static const int IN_ISDIR = 1073741824;
static const int IN_Q_OVERFLOW = 16384;
static const int IN_UNMOUNT = 8192;
static const int IN_NONBLOCK = 2048;
static const int IN_CLOEXEC = 524288;
int inotify_init1(int) __attribute__((nothrow, leaf));
int inotify_add_watch(int, const char *, uint32_t) __attribute__((nothrow, leaf));
int inotify_rm_watch(int, int) __attribute__((nothrow, leaf));
]]

-- clock_gettime & friends require librt on old glibc (< 2.17) versions...
-- Load it in the global namespace to make it easier on callers...
-- NOTE: There's no librt.so symlink, so, specify the SOVER, but not the full path,
--       in order to let the dynamic loader figure it out on its own (e.g.,  multilib).
pcall(ffi.load, "rt.so.1", true)
