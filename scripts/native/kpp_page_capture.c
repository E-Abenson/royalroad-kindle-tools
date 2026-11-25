/*
// Royal Road KPP Page Capture — isolated WebKitGTK proof of concept.
//
// Does not attach to or modify KPPMainApp. It opens the KPP history URL in a
// separate GtkOffscreenWindow, runs a read-only DOM text query, and writes
// UTF-8 text to the supplied output path.
//
// Important limitation: this separate WebKit instance does not automatically
// share KPP's cookies, authenticated session, or in-memory page state.
*/

typedef void *gpointer;
typedef char gchar;
typedef int gboolean;
typedef unsigned long gulong;
typedef struct _GtkWidget GtkWidget;
typedef struct _WebKitWebFrame WebKitWebFrame;
typedef void (*GCallback)(void);
typedef gboolean (*GSourceFunc)(gpointer);

typedef struct {
    const char *output_path;
    GtkWidget *window;
    GtkWidget *view;
    int finished;
    int failed;
    int capture_scheduled;
    int attempts;
} CaptureState;

extern void gtk_init(int *argc, char ***argv);
extern GtkWidget *gtk_offscreen_window_new(void);
extern void gtk_container_add(gpointer container, gpointer widget);
extern void gtk_widget_set_size_request(GtkWidget *widget, int width, int height);
extern void gtk_widget_show_all(GtkWidget *widget);
extern void gtk_widget_destroy(GtkWidget *widget);
extern void gtk_main(void);
extern void gtk_main_quit(void);

extern GtkWidget *webkit_web_view_new(void);
extern void webkit_web_view_load_uri(GtkWidget *view, const char *uri);
extern WebKitWebFrame *webkit_web_view_get_main_frame(GtkWidget *view);
extern char *webkit_web_view_execute_script_return_str(GtkWidget *view, const char *script);
extern void g_signal_connect_data(gpointer instance, const char *detailed_signal,
                                  GCallback c_handler, gpointer data,
                                  GCallback destroy_data, int connect_flags);
extern unsigned int g_timeout_add(unsigned int interval, GSourceFunc function, gpointer data);
extern void g_free(gpointer mem);

extern void *fopen(const char *path, const char *mode);
extern int fputs(const char *s, void *stream);
extern int fclose(void *stream);
extern int puts(const char *s);
extern unsigned long strlen(const char *s);
extern char *strstr(const char *haystack, const char *needle);

#define FALSE 0
#define TRUE 1
#define NULL ((void *)0)

static CaptureState state;

static const char *capture_js =
    "(function(){"
    "var root=document.querySelector('div.chapter-inner.chapter-content')||"
    "document.querySelector('.chapter-inner.chapter-content')||"
    "document.querySelector('.chapter-content')||"
    "document.querySelector('#chapter-content')||"
    "document.querySelector('.chapter-body')||document.body;"
    "var title=document.title||'';"
    "var url=location.href||'';"
    "var body=root?(root.innerText||root.textContent||''):'';"
    "body=String(body).replace(/\\r\\n?/g,'\\n').trim();"
    "var scope=(root===document.body)?'FULL PAGE':'CHAPTER';"
    "return 'RRKPP_CAPTURE_V1\\n'+title+'\\n'+url+'\\nSCOPE: '+scope+'\\n\\n'+body;"
    "})()";

static void fail_and_quit(const char *message) {
    state.failed = 1;
    puts(message);
    gtk_main_quit();
}

static gboolean finish_capture(gpointer data) {
    CaptureState *s = (CaptureState *)data;
    char *result;
    void *fp;

    if (s->finished || s->failed) return FALSE;

    s->attempts++;
    result = webkit_web_view_execute_script_return_str(s->view, capture_js);
    if (!result || !strstr(result, "RRKPP_CAPTURE_V1\n") || strlen(result) < 120) {
        if (result) g_free(result);
        if (s->attempts < 10) {
            puts("CAPTURE_WAITING: Waiting for Royal Road chapter content...");
            g_timeout_add(2500, finish_capture, s);
            return FALSE;
        }
        fail_and_quit("CAPTURE_FAILED: No readable chapter text appeared after repeated checks.");
        return FALSE;
    }

    fp = fopen(s->output_path, "wb");
    if (!fp) {
        g_free(result);
        fail_and_quit("CAPTURE_FAILED: Could not create the output file.");
        return FALSE;
    }

    if (fputs(result, fp) < 0 || fputs("\n", fp) < 0) {
        fclose(fp);
        g_free(result);
        fail_and_quit("CAPTURE_FAILED: Writing the output file failed.");
        return FALSE;
    }

    fclose(fp);
    g_free(result);
    s->finished = 1;
    puts("CAPTURE_OK");
    gtk_main_quit();
    return FALSE;
}

static void on_load_finished(GtkWidget *view, WebKitWebFrame *frame, gpointer data) {
    CaptureState *s = (CaptureState *)data;
    if (frame != webkit_web_view_get_main_frame(view)) return;
    if (s->finished || s->failed || s->capture_scheduled) return;

    s->capture_scheduled = 1;
    /* Let client-side page rendering settle before querying the DOM. */
    g_timeout_add(4500, finish_capture, s);
}

static gboolean watchdog(gpointer data) {
    CaptureState *s = (CaptureState *)data;
    if (!s->finished && !s->failed) {
        fail_and_quit("CAPTURE_FAILED: Timed out waiting for the page to load.");
    }
    return FALSE;
}

int main(int argc, char **argv) {
    int gtk_argc = 1;
    char *gtk_argv_storage[2];
    char **gtk_argv = gtk_argv_storage;

    if (argc < 3 || !argv[1] || !argv[2]) {
        puts("Usage: kpp-page-capture URL OUTPUT.txt");
        return 2;
    }

    state.output_path = argv[2];
    state.window = NULL;
    state.view = NULL;
    state.finished = 0;
    state.failed = 0;
    state.capture_scheduled = 0;
    state.attempts = 0;

    gtk_argv_storage[0] = argv[0];
    gtk_argv_storage[1] = NULL;
    gtk_init(&gtk_argc, &gtk_argv);

    state.window = gtk_offscreen_window_new();
    if (!state.window) {
        puts("CAPTURE_FAILED: Could not create an offscreen GTK window.");
        return 3;
    }

    state.view = webkit_web_view_new();
    if (!state.view) {
        puts("CAPTURE_FAILED: Could not create a WebKit view.");
        gtk_widget_destroy(state.window);
        return 4;
    }

    gtk_widget_set_size_request(state.view, 600, 800);
    gtk_container_add(state.window, state.view);
    g_signal_connect_data(state.view, "load-finished",
                          (GCallback)on_load_finished, &state, NULL, 0);

    /* This maps only to a GtkOffscreenWindow, not a visible top-level window. */
    gtk_widget_show_all(state.window);
    g_timeout_add(90000, watchdog, &state);
    webkit_web_view_load_uri(state.view, argv[1]);
    gtk_main();

    gtk_widget_destroy(state.window);
    if (state.finished) return 0;
    return 5;
}
