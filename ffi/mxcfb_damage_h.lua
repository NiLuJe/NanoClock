local ffi = require("ffi")

ffi.cdef[[
typedef enum {
  DAMAGE_UPDATE_DATA_UNKNOWN = 0,
  DAMAGE_UPDATE_DATA_V1_NTX = 1,
  DAMAGE_UPDATE_DATA_V1 = 2,
  DAMAGE_UPDATE_DATA_V2 = 3,
  DAMAGE_UPDATE_DATA_SUNXI_KOBO_DISP2 = 4,
  DAMAGE_UPDATE_DATA_ERROR = 255,
} mxcfb_damage_data_format;
typedef struct {
  uint32_t top;
  uint32_t left;
  uint32_t width;
  uint32_t height;
} mxcfb_damage_rect;
typedef struct {
  void *virt_addr;
  uint32_t phys_addr;
  uint32_t width;
  uint32_t height;
  mxcfb_damage_rect alt_update_region;
} mxcfb_damage_alt_data;
typedef struct {
  mxcfb_damage_rect update_region;
  uint32_t waveform_mode;
  uint32_t update_mode;
  uint32_t update_marker;
  int temp;
  unsigned int flags;
  int dither_mode;
  int quant_bit;
  mxcfb_damage_alt_data alt_buffer_data;
  uint32_t rotate;
  bool pen_mode;
} mxcfb_damage_data;
typedef struct {
  int overflow_notify;
  int queue_size;
  mxcfb_damage_data_format format;
  uint64_t timestamp;
  mxcfb_damage_data data;
} mxcfb_damage_update;
]]
