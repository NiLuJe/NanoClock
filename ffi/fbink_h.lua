local ffi = require("ffi")

ffi.cdef[[
static const int FBFD_AUTO = -1;
static const int LAST_MARKER = 0;
typedef enum {
  IBM = 0,
  UNSCII = 1,
  UNSCII_ALT = 2,
  UNSCII_THIN = 3,
  UNSCII_FANTASY = 4,
  UNSCII_MCR = 5,
  UNSCII_TALL = 6,
  BLOCK = 7,
  LEGGIE = 8,
  VEGGIE = 9,
  KATES = 10,
  FKP = 11,
  CTRLD = 12,
  ORP = 13,
  ORPB = 14,
  ORPI = 15,
  SCIENTIFICA = 16,
  SCIENTIFICAB = 17,
  SCIENTIFICAI = 18,
  TERMINUS = 19,
  TERMINUSB = 20,
  FATTY = 21,
  SPLEEN = 22,
  TEWI = 23,
  TEWIB = 24,
  TOPAZ = 25,
  MICROKNIGHT = 26,
  VGA = 27,
  UNIFONT = 28,
  UNIFONTDW = 29,
  COZETTE = 30,
  FONT_MAX = 255,
} __attribute__((packed)) FONT_INDEX_E;
typedef uint8_t FONT_INDEX_T;
typedef enum {
  FNT_REGULAR = 0,
  FNT_ITALIC = 1,
  FNT_BOLD = 2,
  FNT_BOLD_ITALIC = 3,
} FONT_STYLE_E;
typedef int FONT_STYLE_T;
typedef enum {
  NONE = 0,
  CENTER = 1,
  EDGE = 2,
  ALIGN_MAX = 255,
} __attribute__((packed)) ALIGN_INDEX_E;
typedef uint8_t ALIGN_INDEX_T;
typedef enum {
  NO_PADDING = 0,
  HORI_PADDING = 1,
  VERT_PADDING = 2,
  FULL_PADDING = 3,
  MAX_PADDING = 255,
} __attribute__((packed)) PADDING_INDEX_E;
typedef uint8_t PADDING_INDEX_T;
typedef enum {
  FG_BLACK = 0,
  FG_GRAY1 = 1,
  FG_GRAY2 = 2,
  FG_GRAY3 = 3,
  FG_GRAY4 = 4,
  FG_GRAY5 = 5,
  FG_GRAY6 = 6,
  FG_GRAY7 = 7,
  FG_GRAY8 = 8,
  FG_GRAY9 = 9,
  FG_GRAYA = 10,
  FG_GRAYB = 11,
  FG_GRAYC = 12,
  FG_GRAYD = 13,
  FG_GRAYE = 14,
  FG_WHITE = 15,
  FG_MAX = 255,
} __attribute__((packed)) FG_COLOR_INDEX_E;
typedef uint8_t FG_COLOR_INDEX_T;
typedef enum {
  BG_WHITE = 0,
  BG_GRAYE = 1,
  BG_GRAYD = 2,
  BG_GRAYC = 3,
  BG_GRAYB = 4,
  BG_GRAYA = 5,
  BG_GRAY9 = 6,
  BG_GRAY8 = 7,
  BG_GRAY7 = 8,
  BG_GRAY6 = 9,
  BG_GRAY5 = 10,
  BG_GRAY4 = 11,
  BG_GRAY3 = 12,
  BG_GRAY2 = 13,
  BG_GRAY1 = 14,
  BG_BLACK = 15,
  BG_MAX = 255,
} __attribute__((packed)) BG_COLOR_INDEX_E;
typedef uint8_t BG_COLOR_INDEX_T;
typedef enum {
  DEVICE_CERVANTES_TOUCH = 22,
  DEVICE_CERVANTES_TOUCHLIGHT = 23,
  DEVICE_CERVANTES_2013 = 33,
  DEVICE_CERVANTES_3 = 51,
  DEVICE_CERVANTES_4 = 68,
  DEVICE_CERVANTES_MAX = 65535,
} __attribute__((packed)) CERVANTES_DEVICE_ID_E;
typedef enum {
  DEVICE_KOBO_TOUCH_AB = 310,
  DEVICE_KOBO_TOUCH_C = 320,
  DEVICE_KOBO_MINI = 340,
  DEVICE_KOBO_GLO = 330,
  DEVICE_KOBO_GLO_HD = 371,
  DEVICE_KOBO_TOUCH_2 = 372,
  DEVICE_KOBO_AURA = 360,
  DEVICE_KOBO_AURA_HD = 350,
  DEVICE_KOBO_AURA_H2O = 370,
  DEVICE_KOBO_AURA_H2O_2 = 374,
  DEVICE_KOBO_AURA_H2O_2_R2 = 378,
  DEVICE_KOBO_AURA_ONE = 373,
  DEVICE_KOBO_AURA_ONE_LE = 381,
  DEVICE_KOBO_AURA_SE = 375,
  DEVICE_KOBO_AURA_SE_R2 = 379,
  DEVICE_KOBO_CLARA_HD = 376,
  DEVICE_KOBO_FORMA = 377,
  DEVICE_KOBO_FORMA_32GB = 380,
  DEVICE_KOBO_LIBRA_H2O = 384,
  DEVICE_KOBO_NIA = 382,
  DEVICE_KOBO_ELIPSA = 387,
  DEVICE_KOBO_LIBRA_2 = 388,
  DEVICE_KOBO_SAGE = 383,
  DEVICE_KOBO_MAX = 65535,
} __attribute__((packed)) KOBO_DEVICE_ID_E;
typedef enum {
  DEVICE_REMARKABLE_1 = 1,
  DEVICE_REMARKABLE_2 = 2,
  DEVICE_REMARKABLE_MAX = 65535,
} __attribute__((packed)) REMARKABLE_DEVICE_ID_E;
typedef enum {
  DEVICE_POCKETBOOK_MINI = 515,
  DEVICE_POCKETBOOK_606 = 606,
  DEVICE_POCKETBOOK_611 = 611,
  DEVICE_POCKETBOOK_613 = 613,
  DEVICE_POCKETBOOK_614 = 614,
  DEVICE_POCKETBOOK_615 = 615,
  DEVICE_POCKETBOOK_616 = 616,
  DEVICE_POCKETBOOK_TOUCH = 622,
  DEVICE_POCKETBOOK_LUX = 623,
  DEVICE_POCKETBOOK_BASIC_TOUCH = 624,
  DEVICE_POCKETBOOK_BASIC_TOUCH_2 = 625,
  DEVICE_POCKETBOOK_LUX_3 = 626,
  DEVICE_POCKETBOOK_LUX_4 = 627,
  DEVICE_POCKETBOOK_LUX_5 = 628,
  DEVICE_POCKETBOOK_SENSE = 630,
  DEVICE_POCKETBOOK_TOUCH_HD = 631,
  DEVICE_POCKETBOOK_TOUCH_HD_PLUS = 632,
  DEVICE_POCKETBOOK_COLOR = 633,
  DEVICE_POCKETBOOK_AQUA = 640,
  DEVICE_POCKETBOOK_AQUA2 = 641,
  DEVICE_POCKETBOOK_ULTRA = 650,
  DEVICE_POCKETBOOK_INKPAD_3 = 740,
  DEVICE_POCKETBOOK_INKPAD_3_PRO = 742,
  DEVICE_POCKETBOOK_INKPAD_COLOR = 741,
  DEVICE_POCKETBOOK_INKPAD = 840,
  DEVICE_POCKETBOOK_INKPAD_X = 1040,
  DEVICE_POCKETBOOK_COLOR_LUX = 32637,
  DEVICE_POCKETBOOK_INKPAD_LITE = 970,
  DEVICE_POCKETBOOK_MAX = 65535,
} __attribute__((packed)) POCKETBOOK_DEVICE_ID_E;
typedef uint16_t DEVICE_ID_T;
typedef enum {
  WFM_AUTO = 0,
  WFM_DU = 1,
  WFM_GC16 = 2,
  WFM_GC4 = 3,
  WFM_A2 = 4,
  WFM_GL16 = 5,
  WFM_REAGL = 6,
  WFM_REAGLD = 7,
  WFM_GC16_FAST = 8,
  WFM_GL16_FAST = 9,
  WFM_DU4 = 10,
  WFM_GL4 = 11,
  WFM_GL16_INV = 12,
  WFM_GCK16 = 13,
  WFM_GLKW16 = 14,
  WFM_INIT = 15,
  WFM_UNKNOWN = 16,
  WFM_INIT2 = 17,
  WFM_A2IN = 18,
  WFM_A2OUT = 19,
  WFM_GC16HQ = 20,
  WFM_GS16 = 21,
  WFM_GU16 = 22,
  WFM_GLK16 = 23,
  WFM_CLEAR = 24,
  WFM_GC4L = 25,
  WFM_GCC16 = 26,
  WFM_MAX = 255,
} __attribute__((packed)) WFM_MODE_INDEX_E;
typedef uint8_t WFM_MODE_INDEX_T;
typedef enum {
  HWD_PASSTHROUGH = 0,
  HWD_FLOYD_STEINBERG = 1,
  HWD_ATKINSON = 2,
  HWD_ORDERED = 3,
  HWD_QUANT_ONLY = 4,
  HWD_LEGACY = 255,
} __attribute__((packed)) HW_DITHER_INDEX_E;
typedef uint8_t HW_DITHER_INDEX_T;
typedef enum {
  NTX_ROTA_STRAIGHT = 0,
  NTX_ROTA_ALL_INVERTED = 1,
  NTX_ROTA_ODD_INVERTED = 2,
  NTX_ROTA_SANE = 3,
  NTX_ROTA_SUNXI = 4,
  NTX_ROTA_CW_TOUCH = 5,
  NTX_ROTA_MAX = 255,
} __attribute__((packed)) NTX_ROTA_INDEX_E;
typedef uint8_t NTX_ROTA_INDEX_T;
typedef enum {
  FORCE_ROTA_NOTSUP = -128,
  FORCE_ROTA_CURRENT_ROTA = -5,
  FORCE_ROTA_CURRENT_LAYOUT = -4,
  FORCE_ROTA_PORTRAIT = -3,
  FORCE_ROTA_LANDSCAPE = -2,
  FORCE_ROTA_GYRO = -1,
  FORCE_ROTA_UR = 0,
  FORCE_ROTA_CW = 1,
  FORCE_ROTA_UD = 2,
  FORCE_ROTA_CCW = 3,
  FORCE_ROTA_WORKBUF = 4,
  FORCE_ROTA_MAX = 127,
} __attribute__((packed)) SUNXI_FORCE_ROTA_INDEX_E;
typedef int8_t SUNXI_FORCE_ROTA_INDEX_T;
typedef struct {
  long int user_hz;
  const char *restrict font_name;
  uint32_t view_width;
  uint32_t view_height;
  uint32_t screen_width;
  uint32_t screen_height;
  uint32_t scanline_stride;
  uint32_t bpp;
  char device_name[16];
  char device_codename[16];
  char device_platform[16];
  DEVICE_ID_T device_id;
  uint8_t pen_fg_color;
  uint8_t pen_bg_color;
  short unsigned int screen_dpi;
  short unsigned int font_w;
  short unsigned int font_h;
  short unsigned int max_cols;
  short unsigned int max_rows;
  uint8_t view_hori_origin;
  uint8_t view_vert_origin;
  uint8_t view_vert_offset;
  uint8_t fontsize_mult;
  uint8_t glyph_width;
  uint8_t glyph_height;
  bool is_perfect_fit;
  bool is_sunxi;
  bool sunxi_has_fbdamage;
  SUNXI_FORCE_ROTA_INDEX_T sunxi_force_rota;
  bool is_kindle_legacy;
  bool is_kobo_non_mt;
  uint8_t ntx_boot_rota;
  NTX_ROTA_INDEX_T ntx_rota_quirk;
  bool is_ntx_quirky_landscape;
  uint8_t current_rota;
  bool can_rotate;
  bool can_hw_invert;
  bool has_eclipse_wfm;
} FBInkState;
typedef struct {
  short int row;
  short int col;
  uint8_t fontmult;
  FONT_INDEX_T fontname;
  bool is_inverted;
  bool is_flashing;
  bool is_cleared;
  bool is_centered;
  short int hoffset;
  short int voffset;
  bool is_halfway;
  bool is_padded;
  bool is_rpadded;
  FG_COLOR_INDEX_T fg_color;
  BG_COLOR_INDEX_T bg_color;
  bool is_overlay;
  bool is_bgless;
  bool is_fgless;
  bool no_viewport;
  bool is_verbose;
  bool is_quiet;
  bool ignore_alpha;
  ALIGN_INDEX_T halign;
  ALIGN_INDEX_T valign;
  short int scaled_width;
  short int scaled_height;
  WFM_MODE_INDEX_T wfm_mode;
  HW_DITHER_INDEX_T dithering_mode;
  bool sw_dithering;
  bool is_nightmode;
  bool no_refresh;
  bool no_merge;
  bool to_syslog;
} FBInkConfig;
typedef struct {
  void *font;
  struct {
    short int top;
    short int bottom;
    short int left;
    short int right;
  } margins;
  FONT_STYLE_T style;
  float size_pt;
  short unsigned int size_px;
  bool is_centered;
  PADDING_INDEX_T padding;
  bool is_formatted;
  bool compute_only;
  bool no_truncation;
} FBInkOTConfig;
typedef struct {
  short unsigned int computed_lines;
  short unsigned int rendered_lines;
  bool truncated;
} FBInkOTFit;
typedef struct {
  short unsigned int left;
  short unsigned int top;
  short unsigned int width;
  short unsigned int height;
} FBInkRect;
typedef struct {
  unsigned char *restrict data;
  size_t stride;
  size_t size;
  FBInkRect area;
  FBInkRect clip;
  uint8_t rota;
  uint8_t bpp;
  bool is_full;
} FBInkDump;
const char *fbink_version(void) __attribute__((const));
int fbink_open(void);
int fbink_close(int);
int fbink_init(int, const FBInkConfig *restrict);
void fbink_state_dump(const FBInkConfig *restrict);
void fbink_get_state(const FBInkConfig *restrict, FBInkState *restrict);
int fbink_print(int, const char *restrict, const FBInkConfig *restrict);
int fbink_add_ot_font(const char *, FONT_STYLE_T);
int fbink_add_ot_font_v2(const char *, FONT_STYLE_T, FBInkOTConfig *restrict);
int fbink_free_ot_fonts(void);
int fbink_free_ot_fonts_v2(FBInkOTConfig *restrict);
int fbink_print_ot(int, const char *restrict, const FBInkOTConfig *restrict, const FBInkConfig *restrict, FBInkOTFit *restrict);
int fbink_printf(int, const FBInkOTConfig *restrict, const FBInkConfig *restrict, const char *, ...);
int fbink_refresh(int, uint32_t, uint32_t, uint32_t, uint32_t, const FBInkConfig *restrict);
int fbink_wait_for_submission(int, uint32_t);
int fbink_wait_for_complete(int, uint32_t);
uint32_t fbink_get_last_marker(void);
static const int OK_BPP_CHANGE = 512;
static const int OK_ROTA_CHANGE = 1024;
static const int OK_LAYOUT_CHANGE = 2048;
int fbink_reinit(int, const FBInkConfig *restrict);
void fbink_update_verbosity(const FBInkConfig *restrict);
int fbink_update_pen_colors(const FBInkConfig *restrict);
static const int OK_ALREADY_SAME = 512;
int fbink_set_fg_pen_gray(uint8_t, bool, bool);
int fbink_set_bg_pen_gray(uint8_t, bool, bool);
int fbink_set_fg_pen_rgba(uint8_t, uint8_t, uint8_t, uint8_t, bool, bool);
int fbink_set_bg_pen_rgba(uint8_t, uint8_t, uint8_t, uint8_t, bool, bool);
int fbink_print_progress_bar(int, uint8_t, const FBInkConfig *restrict);
int fbink_print_activity_bar(int, uint8_t, const FBInkConfig *restrict);
int fbink_print_image(int, const char *, short int, short int, const FBInkConfig *restrict);
int fbink_print_raw_data(int, unsigned char *restrict, const int, const int, const size_t, short int, short int, const FBInkConfig *restrict);
int fbink_cls(int, const FBInkConfig *restrict, const FBInkRect *restrict, bool);
int fbink_grid_clear(int, short unsigned int, short unsigned int, const FBInkConfig *restrict);
int fbink_grid_refresh(int, short unsigned int, short unsigned int, const FBInkConfig *restrict);
int fbink_dump(int, FBInkDump *restrict);
int fbink_region_dump(int, short int, short int, short unsigned int, short unsigned int, const FBInkConfig *restrict, FBInkDump *restrict);
int fbink_rect_dump(int, const FBInkRect *restrict, FBInkDump *restrict);
int fbink_restore(int, const FBInkConfig *restrict, const FBInkDump *restrict);
int fbink_free_dump_data(FBInkDump *restrict);
FBInkRect fbink_get_last_rect(bool);
int fbink_button_scan(int, bool, bool);
int fbink_wait_for_usbms_processing(int, bool);
uint8_t fbink_rota_native_to_canonical(uint32_t);
uint32_t fbink_rota_canonical_to_native(uint8_t);
int fbink_invert_screen(int, const FBInkConfig *restrict);
unsigned char *fbink_get_fb_pointer(int, size_t *);
void fbink_get_fb_info(struct fb_var_screeninfo *, struct fb_fix_screeninfo *);
static const int KEEP_CURRENT_ROTATE = 128;
static const int KEEP_CURRENT_BITDEPTH = 128;
static const int KEEP_CURRENT_GRAYSCALE = 128;
static const int TOGGLE_GRAYSCALE = 64;
int fbink_set_fb_info(int, uint32_t, uint8_t, uint8_t, const FBInkConfig *restrict);
int fbink_toggle_sunxi_ntx_pen_mode(int, bool);
int fbink_sunxi_ntx_enforce_rota(int, SUNXI_FORCE_ROTA_INDEX_T, const FBInkConfig *restrict);
]]
