#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>

#ifdef _WIN32
#include <windows.h>

static DWORD old_in_mode;
static DWORD old_out_mode;
static int modes_saved = 0;

#ifndef ENABLE_VIRTUAL_TERMINAL_INPUT
#define ENABLE_VIRTUAL_TERMINAL_INPUT 0x0200
#endif
#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

CAMLprim value jeditor_enable_vt(value unit) {
    CAMLparam1(unit);
    HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    
    if (hIn == INVALID_HANDLE_VALUE || hOut == INVALID_HANDLE_VALUE) {
        CAMLreturn(Val_int(0)); /* false */
    }

    if (!modes_saved) {
        GetConsoleMode(hIn, &old_in_mode);
        GetConsoleMode(hOut, &old_out_mode);
        modes_saved = 1;
    }

    DWORD in_mode = old_in_mode;
    in_mode &= ~(ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT);
    in_mode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
    SetConsoleMode(hIn, in_mode);

    DWORD out_mode = old_out_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    SetConsoleMode(hOut, out_mode);

    CAMLreturn(Val_int(1)); /* true */
}

CAMLprim value jeditor_disable_vt(value unit) {
    CAMLparam1(unit);
    if (modes_saved) {
        HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        SetConsoleMode(hIn, old_in_mode);
        SetConsoleMode(hOut, old_out_mode);
    }
    CAMLreturn(Val_unit);
}

CAMLprim value jeditor_get_term_size(value unit) {
    CAMLparam1(unit);
    CAMLlocal1(res);
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    int cols = 80, rows = 24;
    
    if (GetConsoleScreenBufferInfo(hOut, &csbi)) {
        cols = csbi.srWindow.Right - csbi.srWindow.Left + 1;
        rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
    }
    
    res = caml_alloc(2, 0);
    Store_field(res, 0, Val_int(cols));
    Store_field(res, 1, Val_int(rows));
    
    CAMLreturn(res);
}

CAMLprim value jeditor_read_char(value unit) {
    CAMLparam1(unit);
    HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
    INPUT_RECORD ir[1];
    DWORD read;
    while (1) {
        if (!ReadConsoleInputA(hIn, ir, 1, &read) || read == 0) {
            CAMLreturn(Val_int(-1));
        }
        if (ir[0].EventType == KEY_EVENT && ir[0].Event.KeyEvent.bKeyDown) {
            char c = ir[0].Event.KeyEvent.uChar.AsciiChar;
            if (c != 0) {
                CAMLreturn(Val_int((unsigned char)c));
            } else {
                /* For arrows/functions, if AsciiChar is 0, we can read the virtual key code or we can just rely on ENABLE_VIRTUAL_TERMINAL_INPUT to produce ANSI escape sequences.
                   Wait, if we use ENABLE_VIRTUAL_TERMINAL_INPUT, ReadFile on stdin produces escape sequences!
                   So we shouldn't use ReadConsoleInput!
                */
            }
        }
    }
    CAMLreturn(Val_int(-1));
}

CAMLprim value jeditor_read_key_event(value unit) {
    CAMLparam1(unit);
    CAMLlocal2(tuple, some);
    HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
    INPUT_RECORD ir[1];
    DWORD read;

    while (1) {
        if (!ReadConsoleInputW(hIn, ir, 1, &read) || read == 0) {
            CAMLreturn(Val_int(0)); /* None */
        }

        if (ir[0].EventType == KEY_EVENT && ir[0].Event.KeyEvent.bKeyDown) {
            KEY_EVENT_RECORD key = ir[0].Event.KeyEvent;
            tuple = caml_alloc(3, 0);
            Store_field(tuple, 0, Val_int((int)key.uChar.UnicodeChar));
            Store_field(tuple, 1, Val_int((int)key.wVirtualKeyCode));
            Store_field(tuple, 2, Val_int((int)key.dwControlKeyState));

            some = caml_alloc(1, 0);
            Store_field(some, 0, tuple);
            CAMLreturn(some);
        }

        /* Mouse wheel: synthesise a scroll event as a fake VK code.
           0x7FFE = scroll up (positive delta), 0x7FFF = scroll down. */
        if (ir[0].EventType == MOUSE_EVENT) {
            MOUSE_EVENT_RECORD mouse = ir[0].Event.MouseEvent;
            if (mouse.dwEventFlags & MOUSE_WHEELED) {
                int delta = (int)(SHORT)HIWORD(mouse.dwButtonState);
                int synthetic_vk = (delta > 0) ? 0x7FFE : 0x7FFF;
                tuple = caml_alloc(3, 0);
                Store_field(tuple, 0, Val_int(0));
                Store_field(tuple, 1, Val_int(synthetic_vk));
                Store_field(tuple, 2, Val_int(0));
                some = caml_alloc(1, 0);
                Store_field(some, 0, tuple);
                CAMLreturn(some);
            }
        }
    }
}

#else

#include <sys/ioctl.h>
#include <unistd.h>

CAMLprim value jeditor_enable_vt(value unit) {
    CAMLparam1(unit);
    CAMLreturn(Val_int(1));
}

CAMLprim value jeditor_disable_vt(value unit) {
    CAMLparam1(unit);
    CAMLreturn(Val_unit);
}

CAMLprim value jeditor_get_term_size(value unit) {
    CAMLparam1(unit);
    CAMLlocal1(res);
    struct winsize ws;
    int cols = 80, rows = 24;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0) {
        cols = ws.ws_col;
        rows = ws.ws_row;
    }
    res = caml_alloc(2, 0);
    Store_field(res, 0, Val_int(cols));
    Store_field(res, 1, Val_int(rows));
    CAMLreturn(res);
}

#endif
